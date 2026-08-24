"use strict";

const ENTITLEMENT_SCHEMA_VERSION = 1;

const ENTITLEMENT_STATUS = Object.freeze({
  ACTIVE: "active",
  EXPIRED: "expired",
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
  validFrom = null,
  validUntil = null,
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
    throw new Error(
        "INVALID_ENTITLEMENT_TYPE",
    );
  }

  if (
    acquisitionType !== "payment" &&
    acquisitionType !== "free"
  ) {
    throw new Error(
        "INVALID_ACQUISITION_TYPE",
    );
  }

  if (
    acquisitionType === "payment" &&
    !String(providerPaymentId ?? "").trim()
  ) {
    throw new Error(
        "PAYMENT_ID_REQUIRED",
    );
  }

  if (
    acquisitionType === "free" &&
    Number(product.amount) !== 0
  ) {
    throw new Error(
        "PAID_PRODUCT_REQUIRES_PAYMENT",
    );
  }

  /*
   * Assinaturas precisam obrigatoriamente
   * possuir um período de validade.
   */
  if (
    product.kind ===
      "personal_subscription" &&
    (!validFrom || !validUntil)
  ) {
    throw new Error(
        "SUBSCRIPTION_PERIOD_REQUIRED",
    );
  }

  return {
    schemaVersion:
      ENTITLEMENT_SCHEMA_VERSION,

    entitlementId,

    userId:
      normalizedUserId,

    entitlementType:
      product.entitlement,

    productId:
      product.productId,

    productKind:
      product.kind,

    sourceId:
      product.sourceId || null,

    status:
      ENTITLEMENT_STATUS.ACTIVE,

    validFrom:
      product.kind ===
        "personal_subscription" ?
        validFrom :
        null,

    validUntil:
      product.kind ===
        "personal_subscription" ?
        validUntil :
        null,

    acquisitionType,

    providerPaymentId:
      providerPaymentId === null ?
        null :
        String(providerPaymentId),

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

/**
 * Monta todas as escritas necessárias para conceder
 * um entitlement.
 *
 * A função não executa commit. Isso permite reutilizar
 * as mesmas escritas em Batch ou Transaction.
 *
 * @param {object} params Dependências e produto.
 * @return {object} Plano de escritas.
 */
function buildEntitlementWritePlan({
  firestore,
  serverTimestamp,
  arrayUnion,
  userId,
  product,
  providerPaymentId = null,
  acquisitionType = "payment",
  subscriptionPeriod = null,
}) {
  if (!firestore) {
    throw new Error("FIRESTORE_REQUIRED");
  }

  if (typeof serverTimestamp !== "function") {
    throw new Error(
        "SERVER_TIMESTAMP_REQUIRED",
    );
  }

  if (typeof arrayUnion !== "function") {
    throw new Error(
        "ARRAY_UNION_REQUIRED",
    );
  }

  const timestamp = serverTimestamp();

  const entitlement =
  buildEntitlementRecord({
    userId,
    product,
    providerPaymentId,
    acquisitionType,

    validFrom:
      subscriptionPeriod
          ?.currentPeriodStart || null,

    validUntil:
      subscriptionPeriod
          ?.currentPeriodEnd || null,

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

  const writes = [
    {
      ref: entitlementRef,
      data: entitlement,
      options: {
        merge: true,
      },
    },
  ];

  if (
    product.kind ===
    "personal_subscription"
  ) {
    writes.push({
      ref: userRef,
      data: {
        isPremium: true,

        subscriptionPlan:
        product.displayName,

        subscriptionDate:
        subscriptionPeriod
            .currentPeriodStart,
      },
      options: {
        merge: true,
      },
    });

    const subscriptionRef =
    firestore
        .collection("subscriptions")
        .doc(normalizedUserId);

    writes.push({
      ref: subscriptionRef,
      data: {
        status: "active",

        latestPaymentId:
        String(providerPaymentId),

        currentPeriodStart:
        subscriptionPeriod
            .currentPeriodStart,

        currentPeriodEnd:
        subscriptionPeriod
            .currentPeriodEnd,

        cancelAtPeriodEnd: false,

        cancellationRequestedAt:
        null,

        canceledAt:
        null,

        updatedAt:
        timestamp,
      },
      options: {
        merge: true,
      },
    });
  } else if (
    product.kind ===
    "workout_template"
  ) {
    writes.push({
      ref: userRef,
      data: {
        purchased_templates:
        arrayUnion(
            product.sourceId,
        ),
      },
      options: {
        merge: true,
      },
    });
  } else {
    throw new Error(
        "UNSUPPORTED_PRODUCT_KIND",
    );
  }

  return {
    entitlementId:
      entitlement.entitlementId,

    entitlement,

    writes,
  };
}

/**
 * Concede um entitlement diretamente pelo backend.
 *
 * Utilizado, por exemplo, em produtos gratuitos.
 * Pagamentos usam fulfillment transacional separado.
 *
 * @param {object} params Dependências e produto.
 * @return {Promise<object>} Entitlement concedido.
 */
async function grantProductEntitlement(
    params,
) {
  const {firestore} = params;

  if (
    !firestore ||
    typeof firestore.batch !== "function"
  ) {
    throw new Error(
        "FIRESTORE_BATCH_REQUIRED",
    );
  }

  const plan =
    buildEntitlementWritePlan(params);

  const batch = firestore.batch();

  for (const write of plan.writes) {
    batch.set(
        write.ref,
        write.data,
        write.options,
    );
  }

  await batch.commit();

  return {
    entitlementId:
      plan.entitlementId,

    entitlement:
      plan.entitlement,
  };
}

module.exports = {
  ENTITLEMENT_SCHEMA_VERSION,
  ENTITLEMENT_STATUS,
  normalizeEntitlementUserId,
  getEntitlementDocumentId,
  buildEntitlementRecord,
  buildEntitlementWritePlan,
  grantProductEntitlement,
};
