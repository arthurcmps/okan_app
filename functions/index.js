const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError, onRequest} =
  require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");

const admin = require("firebase-admin");
const {MercadoPagoConfig, Payment} = require("mercadopago");

const {
  resolvePaymentProduct,
} = require("./payment_catalog");

admin.initializeApp();

const mercadoPagoAccessToken = defineSecret(
    "MERCADO_PAGO_ACCESS_TOKEN",
);

const mercadoPagoWebhookUrl =
  "https://webhookmercadopago-pxytyhhu5q-uc.a.run.app";

/**
 * Cria o cliente configurado do Mercado Pago.
 *
 * @return {MercadoPagoConfig} Cliente configurado do Mercado Pago.
 */
function getMercadoPagoClient() {
  return new MercadoPagoConfig({
    accessToken: mercadoPagoAccessToken.value(),
  });
}

exports.obterProdutoPagamento = onCall(
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Precisa de estar autenticado.",
        );
      }

      const {productId} = request.data || {};

      try {
        const product = await resolvePaymentProduct({
          firestore: admin.firestore(),
          productId,
        });

        return {
          productId: product.productId,
          kind: product.kind,
          displayName: product.displayName,
          amount: product.amount,
          currency: product.currency,
          billingPeriod:
            product.billingPeriod || null,
          sourceId:
            product.sourceId || null,
        };
      } catch (error) {
        const code = error?.message;

        if (
          code === "INVALID_PRODUCT_ID" ||
          code === "INVALID_PRODUCT_PRICE" ||
          code === "INVALID_PRODUCT_NAME"
        ) {
          throw new HttpsError(
              "invalid-argument",
              "Produto inválido.",
          );
        }

        if (
          code === "PRODUCT_NOT_FOUND" ||
          code === "PRODUCT_NOT_FOR_SALE"
        ) {
          throw new HttpsError(
              "not-found",
              "Produto não disponível.",
          );
        }

        console.error(
            "Erro ao consultar produto:",
            error,
        );

        throw new HttpsError(
            "internal",
            "Erro ao consultar produto.",
        );
      }
    },
);

exports.enviarPushNotificationGenerica = onDocumentCreated(
    "users/{userId}/notifications/{notificationId}",
    async (event) => {
      if (!event.data) {
        return;
      }

      const novaNotificacao = event.data.data();
      const userId = event.params.userId;

      const userDoc = await admin
          .firestore()
          .collection("users")
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        return;
      }

      const tokens = userDoc.data().fcmTokens;

      if (!tokens || tokens.length === 0) {
        return;
      }

      const payload = {
        notification: {
          title: novaNotificacao.title || "Nova Notificação",
          body: novaNotificacao.body || "Nova mensagem no Okan.",
        },
        data: {
          type: String(novaNotificacao.type || "geral"),
          actionId: String(novaNotificacao.actionId || ""),
        },
        android: {
          notification: {
            channelId: "high_importance_channel",
            sound: "default",
          },
        },
        tokens,
      };

      try {
        await admin.messaging().sendEachForMulticast(payload);
      } catch (error) {
        console.error("Erro ao enviar Push:", error);
      }
    },
);

exports.criarPagamentoPix = onCall(
    {
      secrets: [mercadoPagoAccessToken],
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Precisa de estar autenticado.",
        );
      }

      const {planoNome, preco} = request.data;
      const uid = request.auth.uid;
      const email = request.auth.token.email || "email@teste.com";

      try {
        const client = getMercadoPagoClient();
        const payment = new Payment(client);

        const result = await payment.create({
          body: {
            transaction_amount: preco,
            description: planoNome,
            payment_method_id: "pix",
            payer: {
              email,
            },
            external_reference: uid,
            notification_url: mercadoPagoWebhookUrl,
          },
        });

        return {
          id: result.id,
          qr_code:
          result.point_of_interaction.transaction_data.qr_code,
          qr_code_base64:
          result.point_of_interaction.transaction_data.qr_code_base64,
        };
      } catch (error) {
        console.error("Erro ao gerar pagamento PIX:", error);

        throw new HttpsError(
            "internal",
            "Erro ao gerar pagamento PIX.",
        );
      }
    },
);

exports.criarPagamentoCartao = onCall(
    {
      secrets: [mercadoPagoAccessToken],
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Precisa de estar autenticado.",
        );
      }

      const {
        planoNome,
        preco,
        tokenCartao,
        parcelas,
        metodoPagamentoId,
        emailPagador,
        tipoDoc,
        numeroDoc,
      } = request.data;

      const uid = request.auth.uid;

      try {
        const client = getMercadoPagoClient();
        const payment = new Payment(client);

        const result = await payment.create({
          body: {
            transaction_amount: Number(preco),
            token: tokenCartao,
            description: planoNome,
            installments: Number(parcelas),
            payment_method_id: metodoPagamentoId,
            payer: {
              email: emailPagador,
              identification: {
                type: tipoDoc,
                number: numeroDoc,
              },
            },
            external_reference: uid,
            notification_url: mercadoPagoWebhookUrl,
          },
        });

        return {
          id: result.id,
          status: result.status,
          status_detail: result.status_detail,
        };
      } catch (error) {
        console.error("Erro Mercado Pago:", error);

        let mensagemReal = "Erro desconhecido no pagamento.";

        if (error.cause && error.cause.length > 0) {
          mensagemReal = error.cause[0].description;
        } else if (error.message) {
          mensagemReal = error.message;
        }

        throw new HttpsError(
            "invalid-argument",
            `Aviso do Banco: ${mensagemReal}`,
        );
      }
    },
);

exports.webhookMercadoPago = onRequest(
    {
      secrets: [mercadoPagoAccessToken],
    },
    async (req, res) => {
      const {type, data} = req.body;

      if (type !== "payment") {
        return res.status(200).send("Ignorado");
      }

      try {
        const client = getMercadoPagoClient();
        const payment = new Payment(client);

        const pagamentoInfo = await payment.get({
          id: data.id,
        });

        if (pagamentoInfo.status === "approved") {
          const uid = pagamentoInfo.external_reference;

          await admin
              .firestore()
              .collection("users")
              .doc(uid)
              .update({
                isPremium: true,
                subscriptionPlan: pagamentoInfo.description,
                subscriptionDate:
              admin.firestore.FieldValue.serverTimestamp(),
              });
        }

        return res.status(200).send("Notificação recebida");
      } catch (error) {
        console.error("Erro no Webhook:", error);
        return res.status(500).send("Erro interno");
      }
    },
);
