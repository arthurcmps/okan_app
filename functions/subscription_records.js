"use strict";

const SUBSCRIPTION_SCHEMA_VERSION = 1;
const SUBSCRIPTION_PROVIDER = "mercadopago";

const SUBSCRIPTION_STATUS = Object.freeze({
  PENDING: "pending",
  ACTIVE: "active",
  PAST_DUE: "past_due",
  CANCELED: "canceled",
  EXPIRED: "expired",
});

/**
 * Valida e normaliza o UID do assinante.
 *
 * @param {unknown} value UID.
 * @return {string} UID normalizado.
 */
function normalizeSubscriptionUserId(value) {
  const userId = String(value ?? "").trim();

  if (!userId) {
    throw new Error("INVALID_SUBSCRIPTION_USER_ID");
  }

  return userId;
}

/**
 * ID deterministico: uma assinatura atual por usuario.
 *
 * @param {unknown} userId UID.
 * @return {string} ID do documento.
 */
function getSubscriptionDocumentId(userId) {
  return normalizeSubscriptionUserId(userId);
}

/**
 * Verifica se o produto pode gerar uma assinatura.
 *
 * @param {object} product Produto do catalogo.
 */
function validateSubscriptionProduct(product) {
  if (
    !product ||
    typeof product.productId !== "string" ||
    !product.productId.trim()
  ) {
    throw new Error("INVALID_SUBSCRIPTION_PRODUCT");
  }

  if (product.kind !== "personal_subscription") {
    throw new Error("PRODUCT_IS_NOT_SUBSCRIPTION");
  }

  if (product.billingPeriod !== "monthly") {
    throw new Error("INVALID_BILLING_PERIOD");
  }
}

/**
 * Monta o estado de uma assinatura.
 *
 * @param {object} params Dados.
 * @return {object} Assinatura normalizada.
 */
function buildSubscriptionRecord({
  userId,
  product,
  status = SUBSCRIPTION_STATUS.PENDING,
  latestPaymentId = null,
  providerSubscriptionId = null,
  currentPeriodStart = null,
  currentPeriodEnd = null,
  cancelAtPeriodEnd = false,
  canceledAt = null,
  cancellationRequestedAt = null,
  createdAt,
  updatedAt,
}) {
  const normalizedUserId =
    normalizeSubscriptionUserId(userId);

  validateSubscriptionProduct(product);

  const validStatuses =
    Object.values(SUBSCRIPTION_STATUS);

  if (!validStatuses.includes(status)) {
    throw new Error("INVALID_SUBSCRIPTION_STATUS");
  }

  if (typeof cancelAtPeriodEnd !== "boolean") {
    throw new Error("INVALID_CANCEL_AT_PERIOD_END");
  }

  return {
    schemaVersion: SUBSCRIPTION_SCHEMA_VERSION,

    userId: normalizedUserId,

    productId: product.productId,
    productKind: product.kind,
    displayName: product.displayName,

    billingPeriod: product.billingPeriod,
    currency: product.currency || "BRL",

    provider: SUBSCRIPTION_PROVIDER,

    providerSubscriptionId:
      providerSubscriptionId || null,

    latestPaymentId:
      latestPaymentId
        ? String(latestPaymentId)
        : null,

    status,

    currentPeriodStart,
    currentPeriodEnd,

    cancelAtPeriodEnd,
    cancellationRequestedAt,
    canceledAt,

    createdAt,
    updatedAt,
  };
}

/**
 * Persiste o estado atual da assinatura.
 *
 * @param {object} params Dados.
 * @return {Promise<object>} Resultado.
 */
async function persistSubscriptionRecord({
  firestore,
  serverTimestamp,
  userId,
  product,
  status = SUBSCRIPTION_STATUS.PENDING,
  latestPaymentId = null,
  providerSubscriptionId = null,
  currentPeriodStart = null,
  currentPeriodEnd = null,
  cancellationRequestedAt = null,
  cancelAtPeriodEnd = false,
  canceledAt = null,
}) {
  if (!firestore) {
    throw new Error("FIRESTORE_REQUIRED");
  }

  if (typeof serverTimestamp !== "function") {
    throw new Error("SERVER_TIMESTAMP_REQUIRED");
  }

  const timestamp = serverTimestamp();

  const record = buildSubscriptionRecord({
    userId,
    product,
    status,
    latestPaymentId,
    providerSubscriptionId,
    currentPeriodStart,
    currentPeriodEnd,
    cancelAtPeriodEnd,
    cancellationRequestedAt,
    canceledAt,
    createdAt: timestamp,
    updatedAt: timestamp,
  });

  const documentId =
    getSubscriptionDocumentId(userId);

  await firestore
      .collection("subscriptions")
      .doc(documentId)
      .set(record, {merge: true});

  return {
    documentId,
    record,
  };
}

/**
 * Registra uma solicitacao de cancelamento.
 *
 * Nao remove acesso imediatamente. O encerramento efetivo
 * sera reconciliado pelo backend conforme o ciclo da assinatura.
 *
 * @param {object} params Dependencias.
 * @return {Promise<object>} Estado da solicitacao.
 */
async function requestSubscriptionCancellation({
  firestore,
  serverTimestamp,
  userId,
}) {
  if (!firestore) {
    throw new Error("FIRESTORE_REQUIRED");
  }

  if (typeof serverTimestamp !== "function") {
    throw new Error("SERVER_TIMESTAMP_REQUIRED");
  }

  const normalizedUserId =
    normalizeSubscriptionUserId(userId);

  const documentId =
    getSubscriptionDocumentId(normalizedUserId);

  const ref = firestore
      .collection("subscriptions")
      .doc(documentId);

  const snapshot = await ref.get();

  if (!snapshot.exists) {
    throw new Error("SUBSCRIPTION_NOT_FOUND");
  }

  const data = snapshot.data() || {};

  if (
    data.userId &&
    data.userId !== normalizedUserId
  ) {
    throw new Error("INVALID_SUBSCRIPTION_OWNER");
  }

  if (
    data.status === SUBSCRIPTION_STATUS.CANCELED ||
    data.status === SUBSCRIPTION_STATUS.EXPIRED
  ) {
    return {
      documentId,
      alreadyInactive: true,
      status: data.status,
    };
  }

  const timestamp = serverTimestamp();

  const cancellationRequestedAt =
    data.cancellationRequestedAt || timestamp;

  await ref.set(
      {
        cancelAtPeriodEnd: true,
        cancellationRequestedAt,
        updatedAt: timestamp,
      },
      {merge: true},
  );

  return {
    documentId,
    alreadyInactive: false,
    cancelAtPeriodEnd: true,
    cancellationRequestedAt,
  };
}

module.exports = {
  SUBSCRIPTION_SCHEMA_VERSION,
  SUBSCRIPTION_PROVIDER,
  SUBSCRIPTION_STATUS,
  normalizeSubscriptionUserId,
  getSubscriptionDocumentId,
  validateSubscriptionProduct,
  buildSubscriptionRecord,
  persistSubscriptionRecord,
  requestSubscriptionCancellation,
};