"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  getEntitlementDocumentId,
  buildEntitlementRecord,
  grantProductEntitlement,
} = require("./entitlements");

const subscriptionProduct = {
  productId: "personal_mestre_sankofa_monthly",
  kind: "personal_subscription",
  displayName: "Mestre Sankofa",
  amount: 49.90,
  currency: "BRL",
  entitlement: "personal_premium",
  billingPeriod: "monthly",
  entitlement: "personal_premium",
  billingPeriod: "monthly",
};

const paidWorkoutProduct = {
  productId: "workout_template:template-1",
  kind: "workout_template",
  displayName: "Treino Premium",
  amount: 19.90,
  currency: "BRL",
  entitlement: "workout_template",
  sourceId: "template-1",
  entitlement: "workout_template",
};

const freeWorkoutProduct = {
  ...paidWorkoutProduct,
  productId: "workout_template:template-free",
  displayName: "Treino Gratuito",
  amount: 0,
  sourceId: "template-free",
};

function createFakeFirestore() {
  const writes = [];
  let committed = false;

  function makeDocumentRef(path) {
    return {
      path,

      collection(name) {
        return {
          doc(id) {
            return makeDocumentRef(
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
          return makeDocumentRef(
              `${name}/${id}`,
          );
        },
      };
    },

    batch() {
      return {
        set(ref, data, options) {
          writes.push({
            path: ref.path,
            data,
            options,
          });
        },

        async commit() {
          committed = true;
        },
      };
    },
  };

  return {
    firestore,
    writes,
    wasCommitted() {
      return committed;
    },
  };
}

test(
    "gera entitlement deterministico para assinatura",
    () => {
      assert.equal(
          getEntitlementDocumentId(
              subscriptionProduct,
          ),
          "personal_premium",
      );
    },
);

test(
    "gera entitlement deterministico para template",
    () => {
      assert.equal(
          getEntitlementDocumentId(
              paidWorkoutProduct,
          ),
          "workout_template_template-1",
      );
    },
);

test(
    "monta entitlement de pagamento aprovado",
    () => {
      const record = buildEntitlementRecord({
        userId: "user-1",
        product: subscriptionProduct,
        providerPaymentId: "123",
        acquisitionType: "payment",
        grantedAt: "timestamp",
        updatedAt: "timestamp",
      });

      assert.equal(
          record.entitlementType,
          "personal_premium",
      );

      assert.equal(
          record.providerPaymentId,
          "123",
      );

      assert.equal(
          record.status,
          "active",
      );
    },
);

test(
    "concede assinatura e atualiza compatibilidade",
    async () => {
      const fake =
        createFakeFirestore();

      const result =
        await grantProductEntitlement({
          firestore: fake.firestore,
          serverTimestamp:
            () => "server-timestamp",
          arrayUnion:
            (value) => ({
              arrayUnion: value,
            }),
          userId: "user-1",
          product: subscriptionProduct,
          providerPaymentId: "456",
          acquisitionType: "payment",
        });

      assert.equal(
          result.entitlementId,
          "personal_premium",
      );

      assert.equal(
          fake.wasCommitted(),
          true,
      );

      assert.equal(
          fake.writes.length,
          3,
      );

      assert.equal(
          fake.writes[0].path,
          "users/user-1/entitlements/personal_premium",
      );

      assert.equal(
          fake.writes[1].path,
          "users/user-1",
      );

      assert.equal(
          fake.writes[1].data.isPremium,
          true,
      );

      assert.equal(
          fake.writes[2].path,
          "subscriptions/user-1",
      );

      assert.equal(
          fake.writes[2].data.status,
          "active",
      );
    },
);

test(
    "concede template pago ao usuario",
    async () => {
      const fake =
        createFakeFirestore();

      await grantProductEntitlement({
        firestore: fake.firestore,
        serverTimestamp:
          () => "server-timestamp",
        arrayUnion:
          (value) => ({
            arrayUnion: value,
          }),
        userId: "aluno-1",
        product: paidWorkoutProduct,
        providerPaymentId: "789",
        acquisitionType: "payment",
      });

      assert.equal(
          fake.writes.length,
          2,
      );

      assert.equal(
          fake.writes[0].path,
          "users/aluno-1/entitlements/workout_template_template-1",
      );

      assert.deepEqual(
          fake.writes[1].data
              .purchased_templates,
          {
            arrayUnion: "template-1",
          },
      );
    },
);

test(
    "permite entitlement de template gratuito",
    async () => {
      const fake =
        createFakeFirestore();

      const result =
        await grantProductEntitlement({
          firestore: fake.firestore,
          serverTimestamp:
            () => "server-timestamp",
          arrayUnion:
            (value) => ({
              arrayUnion: value,
            }),
          userId: "aluno-1",
          product: freeWorkoutProduct,
          acquisitionType: "free",
        });

      assert.equal(
          result.entitlement.acquisitionType,
          "free",
      );

      assert.equal(
          result.entitlement
              .providerPaymentId,
          null,
      );
    },
);

test(
    "bloqueia produto pago como aquisicao gratuita",
    async () => {
      const fake =
        createFakeFirestore();

      await assert.rejects(
          () => grantProductEntitlement({
            firestore: fake.firestore,
            serverTimestamp:
              () => "server-timestamp",
            arrayUnion:
              (value) => ({
                arrayUnion: value,
              }),
            userId: "aluno-1",
            product: paidWorkoutProduct,
            acquisitionType: "free",
          }),
          /PAID_PRODUCT_REQUIRES_PAYMENT/,
      );
    },
);

test(
    "pagamento exige ID do provedor",
    () => {
      assert.throws(
          () => buildEntitlementRecord({
            userId: "user-1",
            product: subscriptionProduct,
            acquisitionType: "payment",
            grantedAt: "timestamp",
            updatedAt: "timestamp",
          }),
          /PAYMENT_ID_REQUIRED/,
      );
    },
);