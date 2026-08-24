"use strict";

const {
  normalizeProviderPaymentId,
  getPaymentDocumentId,
} = require("./payment_records");

const {
  buildEntitlementWritePlan,
} = require("./entitlements");

const FULFILLMENT_SCHEMA_VERSION = 1;

const FULFILLMENT_STATUS =
  Object.freeze({
    FULFILLED: "fulfilled",
  });

const {
  calculateMonthlySubscriptionPeriod,
} = require("./subscription_periods");

/**
 * O fulfillment usa o mesmo ID determinístico
 * do registro interno de pagamento.
 *
 * @param {unknown} providerPaymentId ID do pagamento.
 * @return {string} ID do fulfillment.
 */
function getPaymentFulfillmentDocumentId(
    providerPaymentId,
) {
  return getPaymentDocumentId(
      providerPaymentId,
  );
}

/**
 * Concede os benefícios de um pagamento aprovado
 * exatamente uma vez.
 *
 * O marcador de fulfillment e os entitlements são
 * gravados na mesma transação.
 *
 * @param {object} params Dependências e pagamento.
 * @return {Promise<object>} Resultado.
 */
async function fulfillPaidProductOnce({
  firestore,
  serverTimestamp,
  arrayUnion,
  userId,
  product,
  providerPaymentId,
  paymentStatus,
  statusDetail = null,
  now = () => new Date(),
}) {
  if (
    !firestore ||
    typeof firestore.runTransaction !==
      "function"
  ) {
    throw new Error(
        "FIRESTORE_TRANSACTION_REQUIRED",
    );
  }

  if (
    typeof serverTimestamp !== "function"
  ) {
    throw new Error(
        "SERVER_TIMESTAMP_REQUIRED",
    );
  }

  if (typeof arrayUnion !== "function") {
    throw new Error(
        "ARRAY_UNION_REQUIRED",
    );
  }

  const normalizedStatus =
    String(paymentStatus || "").trim();

  if (normalizedStatus !== "approved") {
    return {
      fulfilled: false,
      alreadyFulfilled: false,
      reason:
        "PAYMENT_NOT_APPROVED",
    };
  }

  const normalizedPaymentId =
    normalizeProviderPaymentId(
        providerPaymentId,
    );

  const documentId =
    getPaymentFulfillmentDocumentId(
        normalizedPaymentId,
    );

  const fulfillmentRef =
    firestore
        .collection(
            "payment_fulfillments",
        )
        .doc(documentId);

  const paymentRef =
    firestore
        .collection("payments")
        .doc(
            getPaymentDocumentId(
                normalizedPaymentId,
            ),
        );

  return firestore.runTransaction(
      async (transaction) => {
        /*
         * A leitura precisa ocorrer antes
         * de qualquer escrita.
         */
        const fulfillmentSnapshot =
          await transaction.get(
              fulfillmentRef,
          );

        const timestamp =
          serverTimestamp();


        let subscriptionPeriod =
  null;

        if (
          product.kind ===
  "personal_subscription"
        ) {
          const subscriptionRef =
    firestore
        .collection("subscriptions")
        .doc(String(userId));

          /*
   * Continua sendo uma leitura da transação.
   * Nenhuma escrita ocorreu ainda.
   */
          const subscriptionSnapshot =
    await transaction.get(
        subscriptionRef,
    );

          const subscriptionData =
    subscriptionSnapshot.exists ?
      subscriptionSnapshot.data() || {} :
      {};

          subscriptionPeriod =
    calculateMonthlySubscriptionPeriod({
      now: now(),

      currentPeriodStart:
        subscriptionData
            .currentPeriodStart ||
        null,

      currentPeriodEnd:
        subscriptionData
            .currentPeriodEnd ||
        null,
    });
        }
        /*
         * Já concedido:
         * atualizamos apenas o estado do pagamento.
         */
        if (fulfillmentSnapshot.exists) {
          transaction.set(
              paymentRef,
              {
                status:
                  normalizedStatus,

                statusDetail:
                  statusDetail || null,

                updatedAt:
                  timestamp,
              },
              {
                merge: true,
              },
          );

          return {
            fulfilled: false,
            alreadyFulfilled: true,
            documentId,
          };
        }

        /*
         * O plano contém entitlement +
         * campos de compatibilidade.
         */
        const plan =
          buildEntitlementWritePlan({
            firestore,
            subscriptionPeriod,

            serverTimestamp:
              () => timestamp,

            arrayUnion,

            userId,
            product,

            providerPaymentId:
              normalizedPaymentId,

            acquisitionType:
              "payment",
          });

        for (const write of plan.writes) {
          transaction.set(
              write.ref,
              write.data,
              write.options,
          );
        }

        transaction.set(
            fulfillmentRef,
            {
              schemaVersion:
                FULFILLMENT_SCHEMA_VERSION,

              provider:
                "mercadopago",

              providerPaymentId:
                normalizedPaymentId,

              userId:
                String(userId),

              productId:
                product.productId,

              entitlementId:
                plan.entitlementId,

              status:
                FULFILLMENT_STATUS
                    .FULFILLED,

              fulfilledAt:
                timestamp,
            },
        );

        transaction.set(
            paymentRef,
            {
              status:
                normalizedStatus,

              statusDetail:
                statusDetail || null,

              fulfillmentStatus:
                FULFILLMENT_STATUS
                    .FULFILLED,

              fulfilledAt:
                timestamp,

              updatedAt:
                timestamp,
            },
            {
              merge: true,
            },
        );

        return {
          fulfilled: true,
          alreadyFulfilled: false,
          documentId,
          entitlementId:
            plan.entitlementId,
        };
      },
  );
}

module.exports = {
  FULFILLMENT_SCHEMA_VERSION,
  FULFILLMENT_STATUS,
  getPaymentFulfillmentDocumentId,
  fulfillPaidProductOnce,
};
