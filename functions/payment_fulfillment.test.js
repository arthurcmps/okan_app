"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  getPaymentFulfillmentDocumentId,
  fulfillPaidProductOnce,
} = require("./payment_fulfillment");

const subscriptionProduct = {
  productId:
    "personal_mestre_sankofa_monthly",
  kind:
    "personal_subscription",
  displayName:
    "Mestre Sankofa",
  amount: 49.90,
  currency: "BRL",
  entitlement:
    "personal_premium",
  billingPeriod:
    "monthly",
};

const workoutProduct = {
  productId:
    "workout_template:template-1",
  kind:
    "workout_template",
  displayName:
    "Treino Premium",
  amount: 19.90,
  currency: "BRL",
  entitlement:
    "workout_template",
  sourceId:
    "template-1",
};

function createFakeFirestore() {
  const state = new Map();
  const writes = [];

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

      async get() {
        return {
          exists:
            state.has(path),

          data() {
            return state.get(path);
          },
        };
      },

      async set(data, options) {
        const previous =
          state.get(path) || {};

        const stored =
          options?.merge
            ? {
                ...previous,
                ...data,
              }
            : data;

        state.set(path, stored);
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

          const stored =
            options?.merge
              ? {
                  ...previous,
                  ...data,
                }
              : data;

          state.set(
              ref.path,
              stored,
          );

          writes.push({
            path: ref.path,
            data,
            options,
          });
        },
      };

      return callback(transaction);
    },
  };

  return {
    firestore,
    state,
    writes,
  };
}

test(
    "gera ID deterministico de fulfillment",
    () => {
      assert.equal(
          getPaymentFulfillmentDocumentId(
              "123",
          ),
          "mercadopago_123",
      );
    },
);

test(
    "nao concede pagamento ainda nao aprovado",
    async () => {
      const fake =
        createFakeFirestore();

      const result =
        await fulfillPaidProductOnce({
          firestore:
            fake.firestore,

          serverTimestamp:
            () => "timestamp",

          arrayUnion:
            (value) => ({
              arrayUnion: value,
            }),

          userId: "user-1",

          product:
            subscriptionProduct,

          providerPaymentId:
            "123",

          paymentStatus:
            "pending",
        });

      assert.equal(
          result.fulfilled,
          false,
      );

      assert.equal(
          fake.writes.length,
          0,
      );
    },
);

test(
    "concede assinatura aprovada uma vez",
    async () => {
      const fake =
        createFakeFirestore();

      const params = {
        firestore:
          fake.firestore,

        serverTimestamp:
          () => "timestamp",

          now:
            () =>
              new Date(
                  "2026-08-23T12:00:00Z",
              ),

        arrayUnion:
          (value) => ({
            arrayUnion: value,
          }),

        userId: "user-1",

        product:
          subscriptionProduct,

        providerPaymentId:
          "456",

        paymentStatus:
          "approved",
      };

      const first =
        await fulfillPaidProductOnce(
            params,
        );

      assert.equal(
          first.fulfilled,
          true,
      );

      const subscription =
  fake.state.get(
      "subscriptions/user-1",
  );

  assert.ok(subscription);

  assert.equal(
    subscription
        .currentPeriodStart
        .toISOString(),
    "2026-08-23T12:00:00.000Z",
);

assert.equal(
    subscription
        .currentPeriodEnd
        .toISOString(),
    "2026-09-23T12:00:00.000Z",
);

      assert.equal(
          fake.state.has(
              "payment_fulfillments/" +
              "mercadopago_456",
          ),
          true,
      );

      const writeCount =
        fake.writes.length;

      const second =
        await fulfillPaidProductOnce(
            params,
        );

      assert.equal(
          second.fulfilled,
          false,
      );

      assert.equal(
          second.alreadyFulfilled,
          true,
      );

      /*
       * Na repetição só pode haver atualização
       * do registro do pagamento.
       */
      assert.equal(
          fake.writes.length,
          writeCount + 1,
      );
    },
);

test(
    "pagamentos diferentes podem ter fulfillment proprio",
    async () => {
      const fake =
        createFakeFirestore();

      const base = {
        firestore:
          fake.firestore,

        serverTimestamp:
          () => "timestamp",

        arrayUnion:
          (value) => ({
            arrayUnion: value,
          }),

        userId: "user-1",

        product:
          subscriptionProduct,

        paymentStatus:
          "approved",
      };

      await fulfillPaidProductOnce({
        ...base,
        providerPaymentId: "100",
      });

      await fulfillPaidProductOnce({
        ...base,
        providerPaymentId: "101",
      });

      assert.equal(
          fake.state.has(
              "payment_fulfillments/" +
              "mercadopago_100",
          ),
          true,
      );

      assert.equal(
          fake.state.has(
              "payment_fulfillments/" +
              "mercadopago_101",
          ),
          true,
      );
    },
);

test(
    "template pago usa fulfillment transacional",
    async () => {
      const fake =
        createFakeFirestore();

      await fulfillPaidProductOnce({
        firestore:
          fake.firestore,

        serverTimestamp:
          () => "timestamp",

        arrayUnion:
          (value) => ({
            arrayUnion: value,
          }),

        userId: "aluno-1",

        product:
          workoutProduct,

        providerPaymentId:
          "789",

        paymentStatus:
          "approved",
      });

      const user =
        fake.state.get(
            "users/aluno-1",
        );

      assert.deepEqual(
          user.purchased_templates,
          {
            arrayUnion:
              "template-1",
          },
      );
    },
);

test(
    "renovacao antecipada acrescenta um mes ao saldo",
    async () => {
      const fake =
        createFakeFirestore();

      fake.state.set(
          "subscriptions/user-1",
          {
            status: "active",

            currentPeriodStart:
              new Date(
                  "2026-08-23T12:00:00Z",
              ),

            currentPeriodEnd:
              new Date(
                  "2026-09-23T12:00:00Z",
              ),
          },
      );

      await fulfillPaidProductOnce({
        firestore:
          fake.firestore,

        serverTimestamp:
          () => "timestamp",

        arrayUnion:
          (value) => ({
            arrayUnion: value,
          }),

        now:
          () =>
            new Date(
                "2026-09-10T12:00:00Z",
            ),

        userId:
          "user-1",

        product:
          subscriptionProduct,

        providerPaymentId:
          "renew-1",

        paymentStatus:
          "approved",
      });

      const subscription =
        fake.state.get(
            "subscriptions/user-1",
        );

      assert.equal(
          subscription
              .currentPeriodStart
              .toISOString(),
          "2026-08-23T12:00:00.000Z",
      );

      assert.equal(
          subscription
              .currentPeriodEnd
              .toISOString(),
          "2026-10-23T12:00:00.000Z",
      );
    },
);
