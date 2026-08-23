"use strict";

const STATIC_PRODUCTS = Object.freeze({
  personal_mestre_sankofa_monthly: Object.freeze({
    productId: "personal_mestre_sankofa_monthly",
    kind: "personal_subscription",
    displayName: "Mestre Sankofa",
    amount: 49.90,
    currency: "BRL",
    active: true,
    entitlement: "personal_premium",
    billingPeriod: "monthly",
  }),
});

/**
 * Normaliza um valor monetario em reais.
 *
 * @param {unknown} value Valor recebido.
 * @return {number} Valor com duas casas decimais.
 */
function normalizeAmount(value) {
  const amount = Number(value);

  if (!Number.isFinite(amount) || amount < 0) {
    throw new Error("INVALID_PRODUCT_PRICE");
  }

  return Number(amount.toFixed(2));
}

/**
 * Busca um produto estatico do catalogo.
 *
 * @param {string} productId ID do produto.
 * @return {object|null} Produto ou null.
 */
function getStaticProduct(productId) {
  const product = STATIC_PRODUCTS[productId];

  if (!product || product.active !== true) {
    return null;
  }

  return {
    ...product,
  };
}

/**
 * Resolve qualquer produto vendavel pelo Okan.
 *
 * Produtos fixos ficam neste arquivo.
 * Treinos da Loja Oficial sao resolvidos pelo Firestore.
 *
 * @param {object} params Parametros.
 * @param {FirebaseFirestore.Firestore} params.firestore Firestore Admin.
 * @param {string} params.productId ID publico do produto.
 * @return {Promise<object>} Produto normalizado.
 */
async function resolvePaymentProduct({
  firestore,
  productId,
}) {
  if (
    typeof productId !== "string" ||
    productId.trim().length === 0
  ) {
    throw new Error("INVALID_PRODUCT_ID");
  }

  const normalizedProductId = productId.trim();

  const staticProduct =
    getStaticProduct(normalizedProductId);

  if (staticProduct) {
    return staticProduct;
  }

  const templatePrefix = "workout_template:";

  if (normalizedProductId.startsWith(templatePrefix)) {
    const templateId = normalizedProductId
        .substring(templatePrefix.length)
        .trim();

    if (!templateId) {
      throw new Error("INVALID_PRODUCT_ID");
    }

    const templateSnapshot = await firestore
        .collection("workout_templates")
        .doc(templateId)
        .get();

    if (!templateSnapshot.exists) {
      throw new Error("PRODUCT_NOT_FOUND");
    }

    const data = templateSnapshot.data() || {};

    /*
     * Apenas os templates da Loja Oficial podem
     * virar produtos de pagamento neste momento.
     */
    if (data.personalId !== "SYSTEM_ADMIN") {
      throw new Error("PRODUCT_NOT_FOR_SALE");
    }

    const displayName =
      String(data.nome || "").trim();

    if (!displayName) {
      throw new Error("INVALID_PRODUCT_NAME");
    }

    const amount = normalizeAmount(data.preco);

    return {
      productId: normalizedProductId,
      kind: "workout_template",
      displayName,
      amount,
      currency: "BRL",
      active: true,
      entitlement: "workout_template",
      sourceId: templateId,
    };
  }

  throw new Error("PRODUCT_NOT_FOUND");
}

module.exports = {
  STATIC_PRODUCTS,
  getStaticProduct,
  normalizeAmount,
  resolvePaymentProduct,
};