"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  getStaticProduct,
  normalizeAmount,
  resolvePaymentProduct,
} = require("./payment_catalog");

function createFakeFirestore(documents = {}) {
  return {
    collection(collectionName) {
      return {
        doc(documentId) {
          return {
            async get() {
              const key =
                `${collectionName}/${documentId}`;

              const data = documents[key];

              return {
                exists: data !== undefined,
                data() {
                  return data;
                },
              };
            },
          };
        },
      };
    },
  };
}

test(
    "resolve plano Mestre Sankofa pelo catalogo",
    async () => {
      const firestore = createFakeFirestore();

      const product = await resolvePaymentProduct({
        firestore,
        productId:
          "personal_mestre_sankofa_monthly",
      });

      assert.equal(
          product.displayName,
          "Mestre Sankofa",
      );

      assert.equal(product.amount, 49.90);
      assert.equal(
          product.kind,
          "personal_subscription",
      );
    },
);

test(
    "resolve template pago da Loja Oficial",
    async () => {
      const firestore = createFakeFirestore({
        "workout_templates/template-1": {
          personalId: "SYSTEM_ADMIN",
          nome: "Projeto Verao",
          preco: 29.90,
          isPremium: true,
        },
      });

      const product = await resolvePaymentProduct({
        firestore,
        productId:
          "workout_template:template-1",
      });

      assert.equal(
          product.kind,
          "workout_template",
      );

      assert.equal(
          product.sourceId,
          "template-1",
      );

      assert.equal(product.amount, 29.90);
    },
);

test(
    "permite template gratuito oficial",
    async () => {
      const firestore = createFakeFirestore({
        "workout_templates/template-free": {
          personalId: "SYSTEM_ADMIN",
          nome: "Treino Gratuito",
          preco: 0,
          isPremium: true,
        },
      });

      const product = await resolvePaymentProduct({
        firestore,
        productId:
          "workout_template:template-free",
      });

      assert.equal(product.amount, 0);
    },
);

test(
    "bloqueia template de personal comum",
    async () => {
      const firestore = createFakeFirestore({
        "workout_templates/template-personal": {
          personalId: "personal-1",
          nome: "Treino Particular",
          preco: 99.90,
        },
      });

      await assert.rejects(
          resolvePaymentProduct({
            firestore,
            productId:
              "workout_template:template-personal",
          }),
          /PRODUCT_NOT_FOR_SALE/,
      );
    },
);

test(
    "bloqueia preco invalido",
    () => {
      assert.throws(
          () => normalizeAmount("abc"),
          /INVALID_PRODUCT_PRICE/,
      );
    },
);

test(
    "produto inexistente falha",
    async () => {
      const firestore = createFakeFirestore();

      await assert.rejects(
          resolvePaymentProduct({
            firestore,
            productId: "produto-inexistente",
          }),
          /PRODUCT_NOT_FOUND/,
      );
    },
);

test(
    "getStaticProduct nao retorna objeto mutavel original",
    () => {
      const first = getStaticProduct(
          "personal_mestre_sankofa_monthly",
      );

      const second = getStaticProduct(
          "personal_mestre_sankofa_monthly",
      );

      assert.notStrictEqual(first, second);
    },
);