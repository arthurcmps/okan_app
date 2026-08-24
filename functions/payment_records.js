"use strict";

const PAYMENT_SCHEMA_VERSION = 1;
const PAYMENT_PROVIDER = "mercadopago";

/**
 * Normaliza o ID de pagamento recebido do provedor.
 *
 * @param {unknown} value ID externo.
 * @return {string} ID normalizado.
 */
function normalizeProviderPaymentId(value) {
  const id = String(value ?? "").trim();

  if (!id) {
    throw new Error("INVALID_PROVIDER_PAYMENT_ID");
  }

  return id;
}

/**
 * Gera um ID deterministico para o documento Firestore.
 *
 * @param {unknown} providerPaymentId ID do Mercado Pago.
 * @return {string} ID do documento.
 */
function getPaymentDocumentId(providerPaymentId) {
  const id =
    normalizeProviderPaymentId(providerPaymentId);

  return `${PAYMENT_PROVIDER}_${id}`;
}

/**
 * Normaliza numero de parcelas.
 *
 * @param {unknown} value Parcelas.
 * @return {number} Parcelas normalizadas.
 */
function normalizeInstallments(value) {
  const installments = Number(value ?? 1);

  if (
    !Number.isInteger(installments) ||
    installments < 1
  ) {
    throw new Error("INVALID_INSTALLMENTS");
  }

  return installments;
}

/**
 * Monta o documento interno de pagamento.
 *
 * Nenhum dado sensivel de cartao ou documento pessoal
 * deve ser armazenado aqui.
 *
 * @param {object} params Dados do pagamento.
 * @return {object} Registro normalizado.
 */
function buildPaymentRecord({
  providerPaymentId,
  userId,
  product,
  paymentMethodType,
  providerPaymentMethodId = null,
  installments = 1,
  status = "pending",
  statusDetail = null,
  createdAt,
  updatedAt,
}) {
  const normalizedPaymentId =
    normalizeProviderPaymentId(providerPaymentId);

  if (
    typeof userId !== "string" ||
    !userId.trim()
  ) {
    throw new Error("INVALID_USER_ID");
  }

  if (
    !product ||
    typeof product.productId !== "string" ||
    !product.productId.trim()
  ) {
    throw new Error("INVALID_PRODUCT_ID");
  }

  if (
    typeof product.kind !== "string" ||
    !product.kind.trim()
  ) {
    throw new Error("INVALID_PRODUCT_KIND");
  }

  if (
    typeof product.entitlement !== "string" ||
    !product.entitlement.trim()
  ) {
    throw new Error(
        "INVALID_PRODUCT_ENTITLEMENT",
    );
  }

  if (
    typeof product.displayName !== "string" ||
    !product.displayName.trim()
  ) {
    throw new Error("INVALID_PRODUCT_NAME");
  }

  const amount = Number(product.amount);

  if (
    !Number.isFinite(amount) ||
    amount <= 0
  ) {
    throw new Error("INVALID_PAYMENT_AMOUNT");
  }

  if (
    typeof paymentMethodType !== "string" ||
    !paymentMethodType.trim()
  ) {
    throw new Error("INVALID_PAYMENT_METHOD");
  }

  return {
    schemaVersion: PAYMENT_SCHEMA_VERSION,
    provider: PAYMENT_PROVIDER,
    providerPaymentId:
      normalizedPaymentId,

    userId: userId.trim(),

    productId:
      product.productId,

    productKind:
      product.kind,

    sourceId:
      product.sourceId || null,

    displayName:
      product.displayName,

    entitlement:
      product.entitlement,

    billingPeriod:
      product.billingPeriod || null,

    amount:
      Number(amount.toFixed(2)),

    currency:
      product.currency || "BRL",

    paymentMethodType:
      paymentMethodType.trim(),

    providerPaymentMethodId:
      providerPaymentMethodId || null,

    installments:
      normalizeInstallments(installments),

    status:
      String(status || "pending"),

    statusDetail:
      statusDetail || null,

    createdAt,
    updatedAt,
  };
}

/**
 * Salva o registro do pagamento no Firestore.
 *
 * @param {object} params Dependencias e dados.
 * @return {Promise<object>} Registro persistido.
 */
async function persistPaymentRecord({
  firestore,
  serverTimestamp,
  providerPaymentId,
  userId,
  product,
  paymentMethodType,
  providerPaymentMethodId = null,
  installments = 1,
  status = "pending",
  statusDetail = null,
}) {
  if (!firestore) {
    throw new Error("FIRESTORE_REQUIRED");
  }

  if (typeof serverTimestamp !== "function") {
    throw new Error("SERVER_TIMESTAMP_REQUIRED");
  }

  const timestamp = serverTimestamp();

  const record = buildPaymentRecord({
    providerPaymentId,
    userId,
    product,
    paymentMethodType,
    providerPaymentMethodId,
    installments,
    status,
    statusDetail,
    createdAt: timestamp,
    updatedAt: timestamp,
  });

  const documentId =
    getPaymentDocumentId(providerPaymentId);

  await firestore
      .collection("payments")
      .doc(documentId)
      .set(record, {merge: true});

  return {
    documentId,
    record,
  };
}

module.exports = {
  PAYMENT_SCHEMA_VERSION,
  PAYMENT_PROVIDER,
  normalizeProviderPaymentId,
  getPaymentDocumentId,
  normalizeInstallments,
  buildPaymentRecord,
  persistPaymentRecord,
};
