const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");

const admin = require("firebase-admin");

const {
  MercadoPagoConfig,
  Payment,
} = require("mercadopago");


admin.initializeApp();


// ============================================================================
// 1. CONFIGURAÇÃO SEGURA DO MERCADO PAGO
// ============================================================================

/**
 * O Access Token do Mercado Pago NÃO fica mais salvo no código.
 *
 * O valor real será armazenado no Google Cloud Secret Manager.
 *
 * Para cadastrar o secret:
 *
 * firebase functions:secrets:set MERCADO_PAGO_ACCESS_TOKEN
 *
 */
const mercadoPagoAccessToken = defineSecret(
  "MERCADO_PAGO_ACCESS_TOKEN",
);


/**
 * Cria o cliente do Mercado Pago somente durante
 * a execução de uma Function autorizada a acessar o secret.
 */
function getMercadoPagoClient() {
  return new MercadoPagoConfig({
    accessToken: mercadoPagoAccessToken.value(),
  });
}


// ============================================================================
// 2. MOTOR DE NOTIFICAÇÕES PUSH
// ============================================================================

exports.enviarPushNotificationGenerica = onDocumentCreated(
  "users/{userId}/notifications/{notificationId}",

  async (event) => {
    if (!event.data) {
      return;
    }

    const novaNotificacao =
      event.data.data();

    const userId =
      event.params.userId;


    // Busca os dados do usuário
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();


    if (!userDoc.exists) {
      return;
    }


    const tokens =
      userDoc.data().fcmTokens;


    // Usuário ainda não possui
    // dispositivos registrados.
    if (
      !tokens ||
      tokens.length === 0
    ) {
      return;
    }


    const payload = {
      notification: {
        title:
          novaNotificacao.title ||
          "Nova Notificação",

        body:
          novaNotificacao.body ||
          "Nova mensagem no Okan.",
      },

      data: {
        type: String(
          novaNotificacao.type ||
          "geral",
        ),

        actionId: String(
          novaNotificacao.actionId ||
          "",
        ),
      },

      android: {
        notification: {
          channelId:
            "high_importance_channel",

          sound:
            "default",
        },
      },

      tokens:
        tokens,
    };


    try {
      await admin
        .messaging()
        .sendEachForMulticast(
          payload,
        );
    } catch (error) {
      console.error(
        "Erro ao enviar Push:",
        error,
      );
    }
  },
);


// ============================================================================
// 3A. GERAR PAGAMENTO PIX
// ============================================================================

exports.criarPagamentoPix = onCall(
  {
    // Somente esta Function
    // recebe acesso ao secret.
    secrets: [
      mercadoPagoAccessToken,
    ],
  },

  async (request) => {
    // ------------------------------------------------------------------------
    // AUTENTICAÇÃO
    // ------------------------------------------------------------------------

    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Precisa de estar autenticado.",
      );
    }


    // ------------------------------------------------------------------------
    // DADOS ENVIADOS PELO APP
    //
    // IMPORTANTE:
    // preço ainda vem do aplicativo.
    //
    // Isso será corrigido posteriormente no OKAN-008/009,
    // quando criarmos o catálogo server-side.
    // ------------------------------------------------------------------------

    const {
      planoNome,
      preco,
    } = request.data;


    const uid =
      request.auth.uid;


    const email =
      request.auth.token.email ||
      "email@teste.com";


    try {
      // ----------------------------------------------------------------------
      // CRIA CLIENTE MERCADO PAGO
      //
      // O Access Token só é acessado aqui,
      // durante a execução da Function.
      // ----------------------------------------------------------------------

      const client =
        getMercadoPagoClient();


      const payment =
        new Payment(client);


      // ----------------------------------------------------------------------
      // CRIA PAGAMENTO PIX
      // ----------------------------------------------------------------------

      const result =
        await payment.create({
          body: {
            transaction_amount:
              preco,

            description:
              planoNome,

            payment_method_id:
              "pix",

            payer: {
              email:
                email,
            },

            external_reference:
              uid,

            notification_url:
              "https://webhookmercadopago-pxytyhhu5q-uc.a.run.app",
          },
        });


      // ----------------------------------------------------------------------
      // RETORNA DADOS DO PIX PARA O APP
      // ----------------------------------------------------------------------

      return {
        id:
          result.id,

        qr_code:
          result
            .point_of_interaction
            .transaction_data
            .qr_code,

        qr_code_base64:
          result
            .point_of_interaction
            .transaction_data
            .qr_code_base64,
      };
    } catch (error) {
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


// ============================================================================
// 3B. PAGAMENTO COM CARTÃO DE CRÉDITO
// ============================================================================

exports.criarPagamentoCartao = onCall(
  {
    // Esta Function também precisa
    // acessar o Mercado Pago.
    secrets: [
      mercadoPagoAccessToken,
    ],
  },

  async (request) => {
    // ------------------------------------------------------------------------
    // AUTENTICAÇÃO
    // ------------------------------------------------------------------------

    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Precisa de estar autenticado.",
      );
    }


    // ------------------------------------------------------------------------
    // DADOS DO CHECKOUT
    // ------------------------------------------------------------------------

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


    const uid =
      request.auth.uid;


    try {
      // ----------------------------------------------------------------------
      // CLIENTE MERCADO PAGO
      // ----------------------------------------------------------------------

      const client =
        getMercadoPagoClient();


      const payment =
        new Payment(client);


      // ----------------------------------------------------------------------
      // CRIA PAGAMENTO
      // ----------------------------------------------------------------------

      const result =
        await payment.create({
          body: {
            transaction_amount:
              Number(preco),

            token:
              tokenCartao,

            description:
              planoNome,

            installments:
              Number(parcelas),

            payment_method_id:
              metodoPagamentoId,

            payer: {
              email:
                emailPagador,

              identification: {
                type:
                  tipoDoc,

                number:
                  numeroDoc,
              },
            },

            external_reference:
              uid,

            notification_url:
              "https://webhookmercadopago-pxytyhhu5q-uc.a.run.app",
          },
        });


      // ----------------------------------------------------------------------
      // RETORNA STATUS PARA O APP
      // ----------------------------------------------------------------------

      return {
        id:
          result.id,

        status:
          result.status,

        status_detail:
          result.status_detail,
      };
    } catch (error) {
      console.error(
        "Erro Mercado Pago:",
        error,
      );


      // ----------------------------------------------------------------------
      // TENTA OBTER A MENSAGEM REAL DO MERCADO PAGO
      // ----------------------------------------------------------------------

      let mensagemReal =
        "Erro desconhecido no pagamento.";


      if (
        error.cause &&
        error.cause.length > 0
      ) {
        mensagemReal =
          error.cause[0].description;
      } else if (
        error.message
      ) {
        mensagemReal =
          error.message;
      }


      throw new HttpsError(
        "invalid-argument",
        `Aviso do Banco: ${mensagemReal}`,
      );
    }
  },
);


// ============================================================================
// 4. WEBHOOK DO MERCADO PAGO
// ============================================================================

exports.webhookMercadoPago = onRequest(
  {
    // O webhook também consulta
    // a API do Mercado Pago.
    secrets: [
      mercadoPagoAccessToken,
    ],
  },

  async (req, res) => {
    const {
      type,
      data,
    } = req.body;


    // ------------------------------------------------------------------------
    // SOMENTE EVENTOS DE PAGAMENTO
    // ------------------------------------------------------------------------

    if (
      type !== "payment"
    ) {
      return res
        .status(200)
        .send(
          "Ignorado",
        );
    }


    try {
      // ----------------------------------------------------------------------
      // CLIENTE MERCADO PAGO
      // ----------------------------------------------------------------------

      const client =
        getMercadoPagoClient();


      const payment =
        new Payment(client);


      // ----------------------------------------------------------------------
      // BUSCA PAGAMENTO DIRETAMENTE NO MERCADO PAGO
      // ----------------------------------------------------------------------

      const pagamentoInfo =
        await payment.get({
          id:
            data.id,
        });


      // ----------------------------------------------------------------------
      // PAGAMENTO APROVADO
      // ----------------------------------------------------------------------

      if (
        pagamentoInfo.status ===
        "approved"
      ) {
        const uid =
          pagamentoInfo
            .external_reference;


        // --------------------------------------------------------------------
        // ATIVA PREMIUM
        //
        // IMPORTANTE:
        // Esse modelo será melhorado posteriormente.
        //
        // Vamos substituir isPremium direto por:
        //
        // payments
        // subscriptions
        // entitlements
        //
        // nos próximos itens do nosso plano.
        // --------------------------------------------------------------------

        await admin
          .firestore()
          .collection("users")
          .doc(uid)
          .update({
            isPremium:
              true,

            subscriptionPlan:
              pagamentoInfo
                .description,

            subscriptionDate:
              admin
                .firestore
                .FieldValue
                .serverTimestamp(),
          });
      }


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
        .send(
          "Erro interno",
        );
    }
  },
);