"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  expirePremiumSubscriptionIfNeeded,
} = require("./subscription_expiration");

function createFakeFirestore() {
  const state = new Map();

  function makeRef(path) {
    return {
      path,

      collection(name) {
        return {
          doc(id) {
            return makeRef(
                `${path}/${name}/${id}`,
            );
          },
        };
      },
    };
  }

  const firestore = {
    collection(name) {
      return {
        doc(id) {
          return makeRef(
              `${name}/${id}`,
          );
        },
      };
    },

    async runTransaction(callback) {
      const transaction = {
        async get(ref) {
          return {
            exists:
              state.has(ref.path),

            data() {
              return state.get(
                  ref.path,
              );
            },
          };
        },

        set(ref, data, options) {
          const previous =
            state.get(ref.path) || {};

          state.set(
              ref.path,
              options?.merge
                ? {
                    ...previous,
                    ...data,
                  }
                : data,
          );
        },
      };

      return callback(transaction);
    },
  };

  return {
    firestore,
    state,
  };
}

test(
    "expira assinatura mensal vencida",
    async () => {
      const fake =
        createFakeFirestore();

      fake.state.set(
          "subscriptions/user-1",
          {
            status: "active",

            currentPeriodStart:
              new Date(
                  "2026-08-01T00:00:00Z",
              ),

            currentPeriodEnd:
              new Date(
                  "2026-09-01T00:00:00Z",
              ),

            cancelAtPeriodEnd:
              false,
          },
      );

      fake.state.set(
          "users/user-1",
          {
            isPremium: true,
          },
      );

      fake.state.set(
          "users/user-1/entitlements/personal_premium",
          {
            status: "active",
          },
      );

      const result =
        await expirePremiumSubscriptionIfNeeded({
          firestore:
            fake.firestore,

          serverTimestamp:
            () => "timestamp",

          userId:
            "user-1",

          now:
            () =>
              new Date(
                  "2026-09-02T00:00:00Z",
              ),
        });

      assert.equal(
          result.expired,
          true,
      );

      assert.equal(
          result.status,
          "expired",
      );

      assert.equal(
          fake.state.get(
              "users/user-1",
          ).isPremium,
          false,
      );

      assert.equal(
          fake.state.get(
              "users/user-1/entitlements/personal_premium",
          ).status,
          "expired",
      );
    },
);

test(
    "cancelamento solicitado termina como canceled",
    async () => {
      const fake =
        createFakeFirestore();

      fake.state.set(
          "subscriptions/user-1",
          {
            status: "active",

            currentPeriodEnd:
              new Date(
                  "2026-09-01T00:00:00Z",
              ),

            cancelAtPeriodEnd:
              true,
          },
      );

      const result =
        await expirePremiumSubscriptionIfNeeded({
          firestore:
            fake.firestore,

          serverTimestamp:
            () => "timestamp",

          userId:
            "user-1",

          now:
            () =>
              new Date(
                  "2026-09-02T00:00:00Z",
              ),
        });

      assert.equal(
          result.status,
          "canceled",
      );
    },
);

test(
    "nao expira assinatura ainda valida",
    async () => {
      const fake =
        createFakeFirestore();

      fake.state.set(
          "subscriptions/user-1",
          {
            status: "active",

            currentPeriodEnd:
              new Date(
                  "2026-10-01T00:00:00Z",
              ),
          },
      );

      const result =
        await expirePremiumSubscriptionIfNeeded({
          firestore:
            fake.firestore,

          serverTimestamp:
            () => "timestamp",

          userId:
            "user-1",

          now:
            () =>
              new Date(
                  "2026-09-01T00:00:00Z",
              ),
        });

      assert.equal(
          result.expired,
          false,
      );
    },
);

test(
    "assinatura inexistente nao provoca erro",
    async () => {
      const fake =
        createFakeFirestore();

      const result =
        await expirePremiumSubscriptionIfNeeded({
          firestore:
            fake.firestore,

          serverTimestamp:
            () => "timestamp",

          userId:
            "user-1",
        });

      assert.equal(
          result.expired,
          false,
      );

      assert.equal(
          result.reason,
          "SUBSCRIPTION_NOT_FOUND",
      );
    },
);
