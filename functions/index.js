const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {MercadoPagoConfig, Payment} = require("mercadopago");

admin.initializeApp();

// 1. CONFIGURAÇÃO DO MERCADO PAGO
const accessToken = "TEST-7836166911445116-031722-d0c5e5953a3c421c2de9067cfad9f2f4-230652618";
const client = new MercadoPagoConfig({accessToken: accessToken});

// 2. MOTOR DE NOTIFICAÇÕES PUSH
exports.enviarPushNotificationGenerica = onDocumentCreated(
  "users/{userId}/notifications/{notificationId}",
  async (event) => {
    if (!event.data) return;
    const novaNotificacao = event.data.data();
    const userId = event.params.userId;
    const userDoc = await admin.firestore()
      .collection("users").doc(userId).get();
    if (!userDoc.exists) return;
    const tokens = userDoc.data().fcmTokens;
    if (!tokens || tokens.length === 0) return;

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
        notification: {channelId: "high_importance_channel", sound: "default"},
      },
      tokens: tokens,
    };
    try {
      await admin.messaging().sendEachForMulticast(payload);
    } catch (e) {
      console.error("Erro ao enviar Push:", e);
    }
  }
);

// 3A. GERAR PIX (V2)
exports.criarPagamentoPix = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Precisa de estar autenticado.");
  }
  const {planoNome, preco} = request.data;
  const uid = request.auth.uid;
  const email = request.auth.token.email || "email@teste.com";

  try {
    const payment = new Payment(client);
    const result = await payment.create({
      body: {
        transaction_amount: preco,
        description: planoNome,
        payment_method_id: "pix",
        payer: {email: email},
        external_reference: uid,
        notification_url: "https://webhookmercadopago-pxytyhhu5q-uc.a.run.app",
      },
    });
    return {
      id: result.id,
      qr_code: result.point_of_interaction.transaction_data.qr_code,
      qr_code_base64:
        result.point_of_interaction.transaction_data.qr_code_base64,
    };
  } catch (error) {
    console.error(error);
    throw new HttpsError("internal", "Erro ao gerar pagamento PIX.");
  }
});

// 3B. PAGAMENTO COM CARTÃO DE CRÉDITO (V2)
exports.criarPagamentoCartao = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Precisa de estar autenticado.");
  }
  const {
    planoNome, preco, tokenCartao, parcelas, 
    metodoPagamentoId, emailPagador, tipoDoc, numeroDoc,
  } = request.data;
  const uid = request.auth.uid;

  try {
    const payment = new Payment(client);
    const result = await payment.create({
      body: {
        transaction_amount: preco,
        token: tokenCartao,
        description: planoNome,
        installments: parcelas,
        payment_method_id: metodoPagamentoId,
        payer: {
          email: emailPagador,
          identification: {type: tipoDoc, number: numeroDoc},
        },
        external_reference: uid,
        notification_url: "https://webhookmercadopago-pxytyhhu5q-uc.a.run.app",
      },
    });
    return {
      id: result.id,
      status: result.status,
      status_detail: result.status_detail,
    };
  } catch (error) {
    console.error(error);
    throw new HttpsError("internal", "Erro ao processar cartão.");
  }
});

// 4. WEBHOOK (V2)
exports.webhookMercadoPago = onRequest(async (req, res) => {
  const {type, data} = req.body;
  if (type === "payment") {
    try {
      const payment = new Payment(client);
      const pagamentoInfo = await payment.get({id: data.id});
      if (pagamentoInfo.status === "approved") {
        const uid = pagamentoInfo.external_reference;
        await admin.firestore().collection("users").doc(uid).update({
          isPremium: true,
          subscriptionPlan: pagamentoInfo.description,
          subscriptionDate: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      res.status(200).send("Notificação recebida");
    } catch (error) {
      console.error("Erro no Webhook:", error);
      res.status(500).send("Erro interno");
    }
  } else {
    res.status(200).send("Ignorado");
  }
});