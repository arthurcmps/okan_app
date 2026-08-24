"use strict";

const {
  normalizeSubscriptionUserId,
} = require("./subscription_records");

const {
  toDate,
} = require("./subscription_periods");

/**
 * Expira uma assinatura Premium apenas se ela
 * realmente estiver vencida no momento da transação.
 *
 * @param {object} params Dependências.
 * @return {Promise<object>} Resultado.
 */
async function expirePremiumSubscriptionIfNeeded({
  firestore,
  serverTimestamp,
  userId,
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

  const normalizedUserId =
    normalizeSubscriptionUserId(
        userId,
    );

  const userRef =
    firestore
        .collection("users")
        .doc(normalizedUserId);

  const subscriptionRef =
    firestore
        .collection("subscriptions")
        .doc(normalizedUserId);

  const entitlementRef =
    userRef
        .collection("entitlements")
        .doc("personal_premium");

  return firestore.runTransaction(
      async (transaction) => {
        /*
         * Ler novamente dentro da transação evita
         * expirar uma assinatura que acabou de ser
         * renovada simultaneamente.
         */
        const snapshot =
          await transaction.get(
              subscriptionRef,
          );

        if (!snapshot.exists) {
          return {
            expired: false,
            reason:
              "SUBSCRIPTION_NOT_FOUND",
          };
        }

        const data =
          snapshot.data() || {};

        if (data.status !== "active") {
          return {
            expired: false,
            reason:
              "SUBSCRIPTION_NOT_ACTIVE",
          };
        }

        if (!data.currentPeriodEnd) {
          return {
            expired: false,
            reason:
              "PERIOD_END_MISSING",
          };
        }

        const currentPeriodEnd =
          toDate(
              data.currentPeriodEnd,
          );

        const nowDate =
          toDate(now());

        if (
          currentPeriodEnd.getTime() >
          nowDate.getTime()
        ) {
          return {
            expired: false,
            reason:
              "SUBSCRIPTION_STILL_ACTIVE",
          };
        }

        const timestamp =
          serverTimestamp();

        const finalStatus =
          data.cancelAtPeriodEnd === true ?
            "canceled" :
            "expired";

        transaction.set(
            subscriptionRef,
            {
              status:
                finalStatus,

              lastPeriodStart:
                data.currentPeriodStart ||
                null,

              lastPeriodEnd:
                data.currentPeriodEnd,

              currentPeriodStart:
                null,

              currentPeriodEnd:
                null,

              endedAt:
                timestamp,

              canceledAt:
                finalStatus === "canceled" ?
                  (
                      data.canceledAt ||
                      timestamp
                    ) :
                  (
                      data.canceledAt ||
                      null
                    ),

              updatedAt:
                timestamp,
            },
            {
              merge: true,
            },
        );

        transaction.set(
            entitlementRef,
            {
              status:
                "expired",

              updatedAt:
                timestamp,
            },
            {
              merge: true,
            },
        );

        transaction.set(
            userRef,
            {
              isPremium:
                false,

              subscriptionPlan:
                null,
            },
            {
              merge: true,
            },
        );

        return {
          expired: true,
          status:
            finalStatus,
        };
      },
  );
}

module.exports = {
  expirePremiumSubscriptionIfNeeded,
};
