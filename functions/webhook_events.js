"use strict";

const crypto = require("crypto");

const WEBHOOK_EVENT_SCHEMA_VERSION = 1;

/**
 * Normaliza o ID único da notificação.
 *
 * @param {unknown} value ID.
 * @return {string} ID normalizado.
 */
function normalizeWebhookNotificationId(
    value,
) {
  const notificationId =
    String(value ?? "").trim();

  if (!notificationId) {
    throw new Error(
        "INVALID_WEBHOOK_NOTIFICATION_ID",
    );
  }

  return notificationId;
}

/**
 * Gera um ID seguro para o documento Firestore.
 *
 * O ID original continua salvo no documento.
 *
 * @param {unknown} notificationId ID do evento.
 * @return {string} ID do documento.
 */
function getWebhookEventDocumentId(
    notificationId,
) {
  const normalized =
    normalizeWebhookNotificationId(
        notificationId,
    );

  const hash =
    crypto
        .createHash("sha256")
        .update(normalized)
        .digest("hex");

  return `mercadopago_${hash}`;
}

/**
 * Verifica se a notificação já foi processada.
 *
 * @param {object} params Dependências.
 * @return {Promise<boolean>} Resultado.
 */
async function isWebhookEventProcessed({
  firestore,
  notificationId,
}) {
  if (!firestore) {
    throw new Error(
        "FIRESTORE_REQUIRED",
    );
  }

  const documentId =
    getWebhookEventDocumentId(
        notificationId,
    );

  const snapshot =
    await firestore
        .collection("webhook_events")
        .doc(documentId)
        .get();

  return snapshot.exists;
}

/**
 * Marca a notificação como processada.
 *
 * @param {object} params Dados.
 * @return {Promise<object>} Documento criado.
 */
async function markWebhookEventProcessed({
  firestore,
  serverTimestamp,
  notificationId,
  providerPaymentId,
  requestId = null,
  outcome = "processed",
}) {
  if (!firestore) {
    throw new Error(
        "FIRESTORE_REQUIRED",
    );
  }

  if (
    typeof serverTimestamp !==
    "function"
  ) {
    throw new Error(
        "SERVER_TIMESTAMP_REQUIRED",
    );
  }

  const normalizedNotificationId =
    normalizeWebhookNotificationId(
        notificationId,
    );

  const documentId =
    getWebhookEventDocumentId(
        normalizedNotificationId,
    );

  const record = {
    schemaVersion:
      WEBHOOK_EVENT_SCHEMA_VERSION,

    provider:
      "mercadopago",

    notificationId:
      normalizedNotificationId,

    providerPaymentId:
      String(
          providerPaymentId ?? "",
      ),

    requestId:
      requestId ?
        String(requestId) :
        null,

    outcome:
      String(outcome),

    processedAt:
      serverTimestamp(),
  };

  const eventRef =
  firestore
      .collection("webhook_events")
      .doc(documentId);

  try {
  /*
   * create() é atômico:
   * somente a primeira requisição consegue criar
   * o documento desse notificationId.
   */
    await eventRef.create(record);

    return {
      documentId,
      record,
      created: true,
      alreadyProcessed: false,
    };
  } catch (error) {
  /*
   * Firestore gRPC ALREADY_EXISTS = código 6.
   * Algumas versões também expõem a string.
   */
    if (
      error?.code === 6 ||
    error?.code === "already-exists"
    ) {
      return {
        documentId,
        record: null,
        created: false,
        alreadyProcessed: true,
      };
    }

    throw error;
  }
}

module.exports = {
  WEBHOOK_EVENT_SCHEMA_VERSION,
  normalizeWebhookNotificationId,
  getWebhookEventDocumentId,
  isWebhookEventProcessed,
  markWebhookEventProcessed,
};
