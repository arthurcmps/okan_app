"use strict";

const ENTITLEMENT_SCHEMA_VERSION = 1;

const ENTITLEMENT_STATUS = Object.freeze({
  ACTIVE: "active",
});

/**
 * Normaliza o UID dono do entitlement.
 *
 * @param {unknown} value UID.
 * @return {string} UID normalizado.
 */
function normalizeEntitlementUserId(value) {
  const userId = String(value ?? "").trim();

  if (!userId) {
    throw new Error("INVALID_ENTITLEMENT_USER_ID");
  }

  return userId;
}

/**
 * Gera um ID deterministico para o entitlement.
 *
 * @param {object} product Produto do catalogo.
 * @return {string} ID do entitlement.
 */
function getEntitlementDocumentId(product) {
  if (!product || !product.kind) {
    throw new Error("INVALID_ENTITLEMENT_PRODUCT");
  }

  if (product.kind === "personal_subscription") {
    return "personal_premium";
  }

  if (product.kind === "workout_template") {
    const sourceId =
      String(product.sourceId ?? "").trim();

    if (!sourceId) {
      throw new Error("INVALID_ENTITLEMENT_SOURCE_ID");
    }

    return `workout_template_${sourceId}`;
  }

  throw new Error("UNSUPPORTED_PRODUCT_KIND");
}

/**
 * Monta o documento canonico de entitlement.
 *
 * @param {object} params Dados.
 * @return {object} Entitlement.
 */
function buildEntitlementRecord({
  userId,
  product,
  providerPaymentId = null,
  acquisitionType = "payment",
  grantedAt,
  updatedAt,
}) {
  const normalizedUserId =
    normalizeEntitlementUserId(userId);

  const entitlementId =
    getEntitlementDocumentId(product);

  if (
    typeof product.productId !== "string" ||
    !product.productId.trim()
  ) {
    throw new Error("INVALID_PRODUCT_ID");
  }

  if (
    typeof product.entitlement !== "string" ||
    !product.entitlement.trim()
  ) {
    throw new Error("INVALID_ENTITLEMENT_TYPE");
  }

  if (
    acquisitionType !== "payment" &&
    acquisitionType !== "free"
  ) {
    throw new Error("INVALID_ACQUISITION_TYPE");
  }

  if (
    acquisitionType === "payment" &&
    !String(providerPaymentId ?? "").trim()
  ) {
    throw new Error("PAYMENT_ID_REQUIRED");
  }

  if (
    acquisitionType === "free" &&
    Number(product.amount) !== 0
  ) {
    throw new Error("PAID_PRODUCT_REQUIRES_PAYMENT");
  }

  return {
    schemaVersion: ENTITLEMENT_SCHEMA_VERSION,

    entitlementId,

    userId: normalizedUserId,

    entitlementType: product.entitlement,

    productId: product.productId,
    productKind: product.kind,

    sourceId: product.sourceId || null,

    status: ENTITLEMENT_STATUS.ACTIVE,

    acquisitionType,

    providerPaymentId:
      providerPaymentId === null
        ? null
        : String(providerPaymentId),

    grantedAt,
    updatedAt,
  };
}

/**
 * Concede um entitlement usando somente o backend.
 *
 * Tambem atualiza campos legados usados atualmente pelo app
 * ate a migracao completa do modelo de usuarios.
 *
 * @param {object} params Dependencias e produto.
 * @return {Promise<object>} Entitlement concedido.
 */
async function grantProductEntitlement({
  firestore,
  serverTimestamp,
  arrayUnion,
  userId,
  product,
  providerPaymentId = null,
  acquisitionType = "payment",
}) {
  if (!firestore) {
    throw new Error("FIRESTORE_REQUIRED");
  }

  if (typeof serverTimestamp !== "function") {
    throw new Error("SERVER_TIMESTAMP_REQUIRED");
  }

  if (typeof arrayUnion !== "function") {
    throw new Error("ARRAY_UNION_REQUIRED");
  }

  if (typeof firestore.batch !== "function") {
    throw new Error("FIRESTORE_BATCH_REQUIRED");
  }

  const timestamp = serverTimestamp();

  const entitlement =
    buildEntitlementRecord({
      userId,
      product,
      providerPaymentId,
      acquisitionType,
      grantedAt: timestamp,
      updatedAt: timestamp,
    });

  const normalizedUserId =
    entitlement.userId;

  const userRef = firestore
      .collection("users")
      .doc(normalizedUserId);

  const entitlementRef = userRef
      .collection("entitlements")
      .doc(entitlement.entitlementId);

  const batch = firestore.batch();

  batch.set(
      entitlementRef,
      entitlement,
      {merge: true},
  );

  if (product.kind === "personal_subscription") {
    batch.set(
        userRef,
        {
          isPremium: true,
          subscriptionPlan: product.displayName,
          subscriptionDate: timestamp,
        },
        {merge: true},
    );

    const subscriptionRef = firestore
        .collection("subscriptions")
        .doc(normalizedUserId);

    batch.set(
        subscriptionRef,
        {
          status: "active",

          latestPaymentId:
            String(providerPaymentId),

          cancelAtPeriodEnd: false,
          cancellationRequestedAt: null,
          canceledAt: null,

          updatedAt: timestamp,
        },
        {merge: true},
    );
  } else if (product.kind === "workout_template") {
    batch.set(
        userRef,
        {
          purchased_templates:
            arrayUnion(product.sourceId),
        },
        {merge: true},
    );
  } else {
    throw new Error("UNSUPPORTED_PRODUCT_KIND");
  }

  await batch.commit();

  return {
    entitlementId:
      entitlement.entitlementId,

    entitlement,
  };
}

module.exports = {
  ENTITLEMENT_SCHEMA_VERSION,
  ENTITLEMENT_STATUS,
  normalizeEntitlementUserId,
  getEntitlementDocumentId,
  buildEntitlementRecord,
  grantProductEntitlement,
};