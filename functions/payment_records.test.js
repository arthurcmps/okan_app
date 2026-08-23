"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  getPaymentDocumentId,
  normalizeInstallments,
  buildPaymentRecord,
  persistPaymentRecord,
} = require("./payment_records");

const subscriptionProduct = {
  productId: "personal_mestre_sankofa_monthly",
  kind: "personal_subscription",
  displayName: "Mestre Sankofa",
  amount: 49.90,
  currency: "BRL",
};

test(
    "gera ID deterministico para pagamento Mercado Pago",
    () => {
      assert.equal(
          getPaymentDocumentId(123456),
          "mercadopago_123456",
      );
    },
);

test(
    "monta registro PIX sem dados sensiveis",
    () => {
      const record = buildPaymentRecord({
        providerPaymentId: 123,
        userId: "user-1",
        product: subscriptionProduct,
        paymentMethodType: "pix",
        providerPaymentMethodId: "pix",
        installments: 1,
        status: "pending",
        createdAt: "timestamp",
        updatedAt: "timestamp",
      });

      assert.equal(record.provider, "mercadopago");
      assert.equal(
          record.providerPaymentId,
          "123",
      );
      assert.equal(record.userId, "user-1");
      assert.equal(
          record.productId,
          "personal_mestre_sankofa_monthly",
      );
      assert.equal(record.amount, 49.90);
      assert.equal(
          record.paymentMethodType,
          "pix",
      );

      assert.equal(
          Object.hasOwn(record, "tokenCartao"),
          false,
      );

      assert.equal(
          Object.hasOwn(record, "numeroDoc"),
          false,
      );

      assert.equal(
          Object.hasOwn(record, "cpf"),
          false,
      );
    },
);

test(
    "monta registro de template pago",
    () => {
      const record = buildPaymentRecord({
        providerPaymentId: "999",
        userId: "aluno-1",
        product: {
          productId:
            "workout_template:template-1",
          kind: "workout_template",
          displayName: "Treino Premium",
          amount: 19.90,
          currency: "BRL",
          sourceId: "template-1",
        },
        paymentMethodType: "card",
        providerPaymentMethodId: "visa",
        installments: 1,
        status: "approved",
        statusDetail: "accredited",
        createdAt: "created",
        updatedAt: "updated",
      });

      assert.equal(
          record.sourceId,
          "template-1",
      );

      assert.equal(
          record.productKind,
          "workout_template",
      );

      assert.equal(
          record.paymentMethodType,
          "card",
      );
    },
);

test(
    "rejeita ID de pagamento vazio",
    () => {
      assert.throws(
          () => getPaymentDocumentId(""),
          /INVALID_PROVIDER_PAYMENT_ID/,
      );
    },
);

test(
    "rejeita numero de parcelas invalido",
    () => {
      assert.throws(
          () => normalizeInstallments(0),
          /INVALID_INSTALLMENTS/,
      );
    },
);

test(
    "persistencia usa caminho deterministico",
    async () => {
      let capturedPath;
      let capturedRecord;
      let capturedOptions;

      const fakeFirestore = {
        collection(collectionName) {
          assert.equal(
              collectionName,
              "payments",
          );

          return {
            doc(documentId) {
              capturedPath = documentId;

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
        await persistPaymentRecord({
          firestore: fakeFirestore,
          serverTimestamp:
            () => "server-timestamp",
          providerPaymentId: 456,
          userId: "user-1",
          product: subscriptionProduct,
          paymentMethodType: "pix",
          providerPaymentMethodId: "pix",
          installments: 1,
          status: "pending",
        });

      assert.equal(
          capturedPath,
          "mercadopago_456",
      );

      assert.equal(
          capturedRecord.userId,
          "user-1",
      );

      assert.deepEqual(
          capturedOptions,
          {merge: true},
      );

      assert.equal(
          result.documentId,
          "mercadopago_456",
      );
    },
);