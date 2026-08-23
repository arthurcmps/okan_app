"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  SUBSCRIPTION_STATUS,
  getSubscriptionDocumentId,
  buildSubscriptionRecord,
  persistSubscriptionRecord,
} = require("./subscription_records");

const subscriptionProduct = {
  productId: "personal_mestre_sankofa_monthly",
  kind: "personal_subscription",
  displayName: "Mestre Sankofa",
  amount: 49.90,
  currency: "BRL",
  billingPeriod: "monthly",
};

test(
    "usa UID como ID deterministico da assinatura",
    () => {
      assert.equal(
          getSubscriptionDocumentId("user-1"),
          "user-1",
      );
    },
);

test(
    "monta assinatura mensal pendente",
    () => {
      const record = buildSubscriptionRecord({
        userId: "user-1",
        product: subscriptionProduct,
        status: SUBSCRIPTION_STATUS.PENDING,
        latestPaymentId: "123",
        createdAt: "created",
        updatedAt: "updated",
      });

      assert.equal(record.userId, "user-1");

      assert.equal(
          record.productId,
          "personal_mestre_sankofa_monthly",
      );

      assert.equal(
          record.status,
          "pending",
      );

      assert.equal(
          record.billingPeriod,
          "monthly",
      );

      assert.equal(
          record.latestPaymentId,
          "123",
      );

      assert.equal(
          record.cancelAtPeriodEnd,
          false,
      );
    },
);

test(
    "rejeita produto que nao e assinatura",
    () => {
      assert.throws(
          () => buildSubscriptionRecord({
            userId: "user-1",
            product: {
              productId:
                "workout_template:template-1",
              kind: "workout_template",
              displayName: "Treino",
              amount: 19.90,
              currency: "BRL",
            },
            createdAt: "created",
            updatedAt: "updated",
          }),
          /PRODUCT_IS_NOT_SUBSCRIPTION/,
      );
    },
);

test(
    "rejeita status desconhecido",
    () => {
      assert.throws(
          () => buildSubscriptionRecord({
            userId: "user-1",
            product: subscriptionProduct,
            status: "qualquer_coisa",
            createdAt: "created",
            updatedAt: "updated",
          }),
          /INVALID_SUBSCRIPTION_STATUS/,
      );
    },
);

test(
    "persistencia usa subscriptions por UID",
    async () => {
      let capturedCollection;
      let capturedDocumentId;
      let capturedRecord;
      let capturedOptions;

      const fakeFirestore = {
        collection(collectionName) {
          capturedCollection = collectionName;

          return {
            doc(documentId) {
              capturedDocumentId = documentId;

              return {
                async set(record, options) {
                  capturedRecord = record;
                  capturedOptions = options;
                },
              };
            },
          };
        },
      };

      const result =
        await persistSubscriptionRecord({
          firestore: fakeFirestore,
          serverTimestamp:
            () => "server-timestamp",
          userId: "user-1",
          product: subscriptionProduct,
          status: SUBSCRIPTION_STATUS.PENDING,
          latestPaymentId: "456",
        });

      assert.equal(
          capturedCollection,
          "subscriptions",
      );

      assert.equal(
          capturedDocumentId,
          "user-1",
      );

      assert.equal(
          capturedRecord.latestPaymentId,
          "456",
      );

      assert.deepEqual(
          capturedOptions,
          {merge: true},
      );

      assert.equal(
          result.documentId,
          "user-1",
      );
    },
);

test(
    "solicita cancelamento sem encerrar assinatura imediatamente",
    async () => {
      let savedPatch;
      let savedOptions;

      const fakeFirestore = {
        collection(collectionName) {
          assert.equal(
              collectionName,
              "subscriptions",
          );

          return {
            doc(documentId) {
              assert.equal(documentId, "user-1");

              return {
                async get() {
                  return {
                    exists: true,
                    data() {
                      return {
                        userId: "user-1",
                        status: "active",
                        cancelAtPeriodEnd: false,
                      };
                    },
                  };
                },

                async set(patch, options) {
                  savedPatch = patch;
                  savedOptions = options;
                },
              };
            },
          };
        },
      };

      const {
        requestSubscriptionCancellation,
      } = require("./subscription_records");

      const result =
        await requestSubscriptionCancellation({
          firestore: fakeFirestore,
          serverTimestamp:
            () => "server-timestamp",
          userId: "user-1",
        });

      assert.equal(
          savedPatch.cancelAtPeriodEnd,
          true,
      );

      assert.equal(
          savedPatch.cancellationRequestedAt,
          "server-timestamp",
      );

      assert.equal(
          savedPatch.updatedAt,
          "server-timestamp",
      );

      assert.deepEqual(
          savedOptions,
          {merge: true},
      );

      assert.equal(
          result.alreadyInactive,
          false,
      );
    },
);

test(
    "rejeita cancelamento quando assinatura nao existe",
    async () => {
      const fakeFirestore = {
        collection() {
          return {
            doc() {
              return {
                async get() {
                  return {
                    exists: false,
                  };
                },
              };
            },
          };
        },
      };

      const {
        requestSubscriptionCancellation,
      } = require("./subscription_records");

      await assert.rejects(
          () => requestSubscriptionCancellation({
            firestore: fakeFirestore,
            serverTimestamp:
              () => "server-timestamp",
            userId: "user-1",
          }),
          /SUBSCRIPTION_NOT_FOUND/,
      );
    },
);