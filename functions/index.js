const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError, onRequest} =
  require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {
  onSchedule,
} = require(
    "firebase-functions/v2/scheduler",
);
const {
  expirePremiumSubscriptionIfNeeded,
} = require("./subscription_expiration");

const admin = require("firebase-admin");
const {MercadoPagoConfig, Payment} = require("mercadopago");

const {
  resolvePaymentProduct,
} = require("./payment_catalog");

const {
  getPaymentDocumentId,
  persistPaymentRecord,
} = require("./payment_records");

const {
  SUBSCRIPTION_STATUS,
  persistSubscriptionRecord,
  requestSubscriptionCancellation,
} = require("./subscription_records");

const {
  grantProductEntitlement,
} = require("./entitlements");

const {
  normalizeWebhookValue,
  verifyWebhookSignature,
} = require("./webhook_security");

const {
  fulfillPaidProductOnce,
} = require("./payment_fulfillment");

const {
  isWebhookEventProcessed,
  markWebhookEventProcessed,
} = require("./webhook_events");

admin.initializeApp();

const mercadoPagoAccessToken = defineSecret(
    "MERCADO_PAGO_ACCESS_TOKEN",
);

const mercadoPagoWebhookSecret = defineSecret(
    "MERCADO_PAGO_WEBHOOK_SECRET",
);

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

/**
 * Resolve um produto pago usando exclusivamente o catalogo do servidor.
 *
 * @param {string} productId ID publico do produto.
 * @return {Promise<object>} Produto validado.
 */
async function resolveCheckoutProduct(productId) {
  try {
    const product = await resolvePaymentProduct({
      firestore: admin.firestore(),
      productId,
    });

    if (product.amount <= 0) {
      throw new HttpsError(
          "failed-precondition",
          "Este produto não exige pagamento.",
      );
    }

    return product;
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

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
        "Erro ao resolver produto do checkout:",
        error,
    );

    throw new HttpsError(
        "internal",
        "Erro ao consultar produto.",
    );
  }
}

/**
 * Registra uma assinatura pendente quando o pagamento
 * pertence a um produto de assinatura.
 *
 * Isso nao concede entitlement nem ativa Premium.
 *
 * @param {object} params Dados do pagamento.
 * @return {Promise<void>}
 */
async function persistPendingSubscriptionIfNeeded({
  userId,
  product,
  paymentId,
  paymentStatus,
}) {
  if (product.kind !== "personal_subscription") {
    return;
  }

  const trackableStatuses = [
    "pending",
    "in_process",
    "approved",
  ];

  const normalizedStatus =
    String(paymentStatus || "pending");

  if (!trackableStatuses.includes(normalizedStatus)) {
    return;
  }

  await persistSubscriptionRecord({
    firestore: admin.firestore(),

    serverTimestamp: () =>
      admin.firestore.FieldValue.serverTimestamp(),

    userId,
    product,

    status: SUBSCRIPTION_STATUS.PENDING,

    latestPaymentId: paymentId,
  });
}

/**
 * Reconstrói o produto a partir do snapshot confiável
 * salvo no pagamento.
 *
 * @param {object} paymentRecord Registro interno.
 * @return {object} Produto.
 */
function buildProductFromPaymentRecord(
    paymentRecord,
) {
  if (
    !paymentRecord ||
    !paymentRecord.productId ||
    !paymentRecord.productKind ||
    !paymentRecord.displayName ||
    !paymentRecord.entitlement
  ) {
    throw new Error(
        "INVALID_PAYMENT_PRODUCT_SNAPSHOT",
    );
  }

  return {
    productId: paymentRecord.productId,
    kind: paymentRecord.productKind,
    displayName: paymentRecord.displayName,

    amount:
      Number(paymentRecord.amount),

    currency:
      paymentRecord.currency || "BRL",

    entitlement:
      paymentRecord.entitlement,

    sourceId:
      paymentRecord.sourceId || null,

    billingPeriod:
      paymentRecord.billingPeriod || null,
  };
}

/**
 * Concede entitlement apenas quando o próprio provedor
 * informou que o pagamento foi aprovado.
 *
 * @param {object} params Dados.
 * @return {Promise<boolean>} Se houve concessão.
 */
async function grantApprovedProductIfNeeded({
  userId,
  product,
  paymentId,
  paymentStatus,
  statusDetail = null,
}) {
  if (paymentStatus !== "approved") {
    return false;
  }

  const result =
    await fulfillPaidProductOnce({
      firestore:
        admin.firestore(),

      serverTimestamp:
        () =>
          admin.firestore
              .FieldValue
              .serverTimestamp(),

      arrayUnion:
        (value) =>
          admin.firestore
              .FieldValue
              .arrayUnion(value),

      userId,
      product,

      providerPaymentId:
        paymentId,

      paymentStatus,

      statusDetail,
    });

  return (
    result.fulfilled === true ||
    result.alreadyFulfilled === true
  );
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

exports.adquirirTemplateGratuito = onCall(
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Precisa de estar autenticado.",
        );
      }

      const {productId} = request.data || {};

      try {
        const product =
          await resolvePaymentProduct({
            firestore: admin.firestore(),
            productId,
          });

        if (
          product.kind !==
          "workout_template"
        ) {
          throw new HttpsError(
              "failed-precondition",
              "Este produto não é um treino.",
          );
        }

        if (product.amount !== 0) {
          throw new HttpsError(
              "failed-precondition",
              "Este treino exige pagamento.",
          );
        }

        const result =
          await grantProductEntitlement({
            firestore: admin.firestore(),

            serverTimestamp: () =>
              admin.firestore.FieldValue
                  .serverTimestamp(),

            arrayUnion: (value) =>
              admin.firestore.FieldValue
                  .arrayUnion(value),

            userId: request.auth.uid,

            product,

            acquisitionType: "free",
          });

        return {
          success: true,
          productId: product.productId,
          entitlementId:
            result.entitlementId,
        };
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }

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
              "Treino não disponível.",
          );
        }

        console.error(
            "Erro ao adquirir treino gratuito:",
            error,
        );

        throw new HttpsError(
            "internal",
            "Erro ao adquirir treino.",
        );
      }
    },
);

exports.solicitarCancelamentoAssinatura = onCall(
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Precisa de estar autenticado.",
        );
      }

      try {
        const result =
          await requestSubscriptionCancellation({
            firestore: admin.firestore(),

            serverTimestamp: () =>
              admin.firestore.FieldValue
                  .serverTimestamp(),

            userId: request.auth.uid,
          });

        return {
          success: true,

          alreadyInactive:
            result.alreadyInactive === true,

          cancelAtPeriodEnd:
            result.cancelAtPeriodEnd === true,

          status:
            result.status || null,
        };
      } catch (error) {
        const code = error?.message;

        if (code === "SUBSCRIPTION_NOT_FOUND") {
          throw new HttpsError(
              "failed-precondition",
              "Assinatura não encontrada.",
          );
        }

        if (
          code === "INVALID_SUBSCRIPTION_USER_ID"
        ) {
          throw new HttpsError(
              "invalid-argument",
              "Usuário inválido.",
          );
        }

        console.error(
            "Erro ao solicitar cancelamento:",
            error,
        );

        throw new HttpsError(
            "internal",
            "Erro ao solicitar cancelamento.",
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

      const {productId} = request.data || {};
      const uid = request.auth.uid;
      const email =
        request.auth.token.email || "email@teste.com";

      try {
        const product =
          await resolveCheckoutProduct(productId);

        const client = getMercadoPagoClient();
        const payment = new Payment(client);

        const result = await payment.create({
          body: {
            transaction_amount: product.amount,
            description: product.displayName,
            payment_method_id: "pix",
            payer: {
              email,
            },
            external_reference: uid,
            metadata: {
              product_id: product.productId,
              product_kind: product.kind,
              source_id: product.sourceId || "",
            },
          },
        });

        await persistPaymentRecord({
          firestore: admin.firestore(),

          serverTimestamp: () =>
            admin.firestore.FieldValue.serverTimestamp(),

          providerPaymentId: result.id,
          userId: uid,
          product,

          paymentMethodType: "pix",

          providerPaymentMethodId:
            result.payment_method_id || "pix",

          installments: 1,

          status:
            result.status || "pending",

          statusDetail:
            result.status_detail || null,
        });

        await persistPendingSubscriptionIfNeeded({
          userId: uid,
          product,
          paymentId: result.id,
          paymentStatus: result.status,
        });

        await grantApprovedProductIfNeeded({
          userId: uid,
          product,
          paymentId: result.id,
          paymentStatus: result.status,
        });

        return {
          id: result.id,
          productId: product.productId,
          qr_code:
            result.point_of_interaction
                .transaction_data.qr_code,
          qr_code_base64:
            result.point_of_interaction
                .transaction_data.qr_code_base64,
        };
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }

        console.error(
            "Erro ao gerar pagamento PIX:",
            error,
        );

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
        productId,
        tokenCartao,
        parcelas,
        metodoPagamentoId,
        emailPagador,
        tipoDoc,
        numeroDoc,
      } = request.data || {};

      const uid = request.auth.uid;

      try {
        const product =
          await resolveCheckoutProduct(productId);

        const client = getMercadoPagoClient();
        const payment = new Payment(client);

        const result = await payment.create({
          body: {
            transaction_amount: product.amount,
            token: tokenCartao,
            description: product.displayName,
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
            metadata: {
              product_id: product.productId,
              product_kind: product.kind,
              source_id: product.sourceId || "",
            },
          },
        });

        await persistPaymentRecord({
          firestore: admin.firestore(),

          serverTimestamp: () =>
            admin.firestore.FieldValue.serverTimestamp(),

          providerPaymentId: result.id,
          userId: uid,
          product,

          paymentMethodType: "card",

          providerPaymentMethodId:
            result.payment_method_id ||
            metodoPagamentoId ||
            null,

          installments:
            result.installments ||
            Number(parcelas),

          status:
            result.status || "pending",

          statusDetail:
            result.status_detail || null,
        });

        await persistPendingSubscriptionIfNeeded({
          userId: uid,
          product,
          paymentId: result.id,
          paymentStatus: result.status,
        });

        await grantApprovedProductIfNeeded({
          userId: uid,
          product,
          paymentId: result.id,
          paymentStatus: result.status,
        });

        return {
          id: result.id,
          productId: product.productId,
          status: result.status,
          status_detail: result.status_detail,
        };
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }

        console.error(
            "Erro Mercado Pago:",
            error,
        );

        let mensagemReal =
          "Erro desconhecido no pagamento.";

        if (
          error.cause &&
          error.cause.length > 0
        ) {
          mensagemReal =
            error.cause[0].description;
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
      secrets: [
        mercadoPagoAccessToken,
        mercadoPagoWebhookSecret,
      ],
    },
    async (req, res) => {
      const type =
  normalizeWebhookValue(
      req.body?.type,
  );

      const queryPaymentId =
  normalizeWebhookValue(
      req.query?.["data.id"],
  );

      const bodyPaymentId =
  normalizeWebhookValue(
      req.body?.data?.id,
  );

      const xSignature =
  req.headers["x-signature"];

      const xRequestId =
  req.headers["x-request-id"];

      const signatureIsValid =
  verifyWebhookSignature({
    xSignature,
    xRequestId,
    dataId: queryPaymentId,
    secret:
      mercadoPagoWebhookSecret.value(),
  });

      if (!signatureIsValid) {
        console.warn(
            "Webhook Mercado Pago " +
      "com assinatura inválida.",
        );

        return res
            .status(401)
            .send("Assinatura inválida");
      }

      /*
 * O data.id usado na assinatura vem da query.
 * O corpo deve apontar para o mesmo pagamento.
 */
      if (
        !queryPaymentId ||
  !bodyPaymentId ||
  queryPaymentId !== bodyPaymentId
      ) {
        console.error(
            "Webhook Mercado Pago com " +
      "data.id inconsistente.",
        );

        return res
            .status(400)
            .send("Pagamento inconsistente");
      }

      const requestedPaymentId =
  queryPaymentId;

      const notificationId =
  normalizeWebhookValue(
      req.body?.id,
  );

      if (!notificationId) {
        return res
            .status(400)
            .send(
                "Notificação sem identificador",
            );
      }

      if (type !== "payment") {
        return res
            .status(200)
            .send("Ignorado");
      }

      if (!requestedPaymentId) {
        return res
            .status(400)
            .send("Pagamento inválido");
      }

      try {
        const eventAlreadyProcessed =
          await isWebhookEventProcessed({
            firestore:
              admin.firestore(),

            notificationId,
          });

        if (eventAlreadyProcessed) {
          return res
              .status(200)
              .send(
                  "Notificação já processada",
              );
        }

        const client =
          getMercadoPagoClient();

        const payment =
          new Payment(client);

        /*
         * Nunca confiamos apenas no corpo do webhook.
         * Consultamos o pagamento diretamente no MP.
         */
        const pagamentoInfo =
          await payment.get({
            id: requestedPaymentId,
          });

        const documentId =
          getPaymentDocumentId(
              pagamentoInfo.id,
          );

        const paymentRef =
          admin.firestore()
              .collection("payments")
              .doc(documentId);

        const paymentSnapshot =
          await paymentRef.get();

        /*
         * Fail closed:
         * sem pagamento interno conhecido,
         * nenhum entitlement é concedido.
         */
        if (!paymentSnapshot.exists) {
          console.error(
              "Webhook recebeu pagamento " +
              "sem registro interno:",
              pagamentoInfo.id,
          );

          return res
              .status(409)
              .send(
                  "Pagamento não registrado",
              );
        }

        const paymentRecord =
          paymentSnapshot.data() || {};

        const providerUserId =
          String(
              pagamentoInfo
                  .external_reference || "",
          );

        if (
          providerUserId !==
          paymentRecord.userId
        ) {
          console.error(
              "UID divergente no pagamento:",
              pagamentoInfo.id,
          );

          return res
              .status(409)
              .send("Pagamento inconsistente");
        }

        const metadataProductId =
          String(
              pagamentoInfo
                  .metadata
                  ?.product_id || "",
          );

        if (
          metadataProductId !==
          paymentRecord.productId
        ) {
          console.error(
              "Produto divergente no pagamento:",
              pagamentoInfo.id,
          );

          return res
              .status(409)
              .send("Pagamento inconsistente");
        }

        const providerAmount =
          Number(
              pagamentoInfo
                  .transaction_amount,
          );

        const recordedAmount =
          Number(paymentRecord.amount);

        if (
          !Number.isFinite(providerAmount) ||
          !Number.isFinite(recordedAmount) ||
          Number(providerAmount.toFixed(2)) !==
            Number(recordedAmount.toFixed(2))
        ) {
          console.error(
              "Valor divergente no pagamento:",
              pagamentoInfo.id,
          );

          return res
              .status(409)
              .send("Pagamento inconsistente");
        }

        const providerCurrency =
          String(
              pagamentoInfo.currency_id ||
              "BRL",
          );

        if (
          providerCurrency !==
          paymentRecord.currency
        ) {
          console.error(
              "Moeda divergente no pagamento:",
              pagamentoInfo.id,
          );

          return res
              .status(409)
              .send("Pagamento inconsistente");
        }

        const status =
          String(
              pagamentoInfo.status ||
              "unknown",
          );

        await paymentRef.set(
            {
              status,

              statusDetail:
                pagamentoInfo
                    .status_detail || null,

              updatedAt:
                admin.firestore
                    .FieldValue
                    .serverTimestamp(),
            },
            {merge: true},
        );

        if (status === "approved") {
          const product =
              buildProductFromPaymentRecord(
                  paymentRecord,
              );

          await grantApprovedProductIfNeeded({
            userId:
                paymentRecord.userId,

            product,

            paymentId:
                pagamentoInfo.id,

            paymentStatus:
                status,

            statusDetail:
                pagamentoInfo
                    .status_detail || null,
          });
        } else {
          /*
            * Pagamentos ainda não aprovados
            * não têm fulfillment.
            * Apenas reconciliamos o estado.
            */
          await paymentRef.set(
              {
                status,

                statusDetail:
                    pagamentoInfo
                        .status_detail || null,

                updatedAt:
                    admin.firestore
                        .FieldValue
                        .serverTimestamp(),
              },
              {
                merge: true,
              },
          );
        }

        await markWebhookEventProcessed({
          firestore:
              admin.firestore(),

          serverTimestamp:
              () =>
                admin.firestore
                    .FieldValue
                    .serverTimestamp(),

          notificationId,

          providerPaymentId:
              pagamentoInfo.id,

          requestId:
              normalizeWebhookValue(
                  xRequestId,
              ),

          outcome:
              status === "approved" ?
                "approved_reconciled" :
                "status_reconciled",
        });

        return res
            .status(200)
            .send(
                "Notificação recebida",
            );
      } catch (error) {
        console.error(
            "Erro no Webhook:",
            error,
        );

        return res
            .status(500)
            .send("Erro interno");
      }
    },
);

exports.expirarAssinaturasPremium =
  onSchedule(
      "every 60 minutes",
      async () => {
        const firestore =
          admin.firestore();

        const now =
          admin.firestore
              .Timestamp
              .now();

        /*
         * currentPeriodEnd é removido quando
         * a assinatura expira, então o documento
         * deixa naturalmente esta consulta.
         */
        const snapshot =
          await firestore
              .collection(
                  "subscriptions",
              )
              .where(
                  "currentPeriodEnd",
                  "<=",
                  now,
              )
              .limit(200)
              .get();

        let expiredCount = 0;

        for (
          const subscription
          of snapshot.docs
        ) {
          const result =
            await expirePremiumSubscriptionIfNeeded({
              firestore,

              serverTimestamp:
                () =>
                  admin.firestore
                      .FieldValue
                      .serverTimestamp(),

              userId:
                subscription.id,

              now:
                () => now.toDate(),
            });

          if (
            result.expired === true
          ) {
            expiredCount += 1;
          }
        }

        console.log(
            "Expiração Premium concluída.",
            {
              candidates:
                snapshot.size,

              expired:
                expiredCount,
            },
        );
      },
  );
