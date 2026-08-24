"use strict";

const crypto = require("crypto");

/**
 * Normaliza um valor recebido do webhook.
 *
 * @param {unknown} value Valor.
 * @return {string} Valor normalizado.
 */
function normalizeWebhookValue(value) {
  if (Array.isArray(value)) {
    return String(value[0] ?? "").trim();
  }

  return String(value ?? "").trim();
}

/**
 * Extrai ts e v1 do header x-signature.
 *
 * Exemplo:
 * ts=1704908010,v1=abc123
 *
 * @param {unknown} header Header x-signature.
 * @return {{ts: string, v1: string}|null} Partes da assinatura.
 */
function parseSignatureHeader(header) {
  const normalized =
    normalizeWebhookValue(header);

  if (!normalized) {
    return null;
  }

  const parts = {};

  for (const item of normalized.split(",")) {
    const separatorIndex =
      item.indexOf("=");

    if (separatorIndex <= 0) {
      continue;
    }

    const key = item
        .slice(0, separatorIndex)
        .trim();

    const value = item
        .slice(separatorIndex + 1)
        .trim();

    if (key && value) {
      parts[key] = value;
    }
  }

  if (!parts.ts || !parts.v1) {
    return null;
  }

  return {
    ts: parts.ts,
    v1: parts.v1,
  };
}

/**
 * Monta o manifesto assinado pelo Mercado Pago.
 *
 * @param {object} params Dados.
 * @return {string} Manifesto.
 */
function buildWebhookManifest({
  dataId,
  xRequestId,
  ts,
}) {
  const normalizedDataId =
    normalizeWebhookValue(dataId);

  const normalizedRequestId =
    normalizeWebhookValue(xRequestId);

  const normalizedTs =
    normalizeWebhookValue(ts);

  if (
    !normalizedDataId ||
    !normalizedRequestId ||
    !normalizedTs
  ) {
    throw new Error(
        "INVALID_WEBHOOK_MANIFEST_DATA",
    );
  }

  return (
    `id:${normalizedDataId};` +
    `request-id:${normalizedRequestId};` +
    `ts:${normalizedTs};`
  );
}

/**
 * Comparação segura entre hashes hexadecimais.
 *
 * @param {string} expected Hash esperado.
 * @param {string} received Hash recebido.
 * @return {boolean} Resultado.
 */
function safeCompareHex(
    expected,
    received,
) {
  if (
    typeof expected !== "string" ||
    typeof received !== "string"
  ) {
    return false;
  }

  if (
    !/^[a-f0-9]+$/i.test(expected) ||
    !/^[a-f0-9]+$/i.test(received)
  ) {
    return false;
  }

  const expectedBuffer =
    Buffer.from(expected, "hex");

  const receivedBuffer =
    Buffer.from(received, "hex");

  if (
    expectedBuffer.length === 0 ||
    expectedBuffer.length !==
      receivedBuffer.length
  ) {
    return false;
  }

  return crypto.timingSafeEqual(
      expectedBuffer,
      receivedBuffer,
  );
}

/**
 * Verifica a assinatura HMAC do webhook.
 *
 * @param {object} params Dados recebidos.
 * @return {boolean} Se a assinatura é válida.
 */
function verifyWebhookSignature({
  xSignature,
  xRequestId,
  dataId,
  secret,
}) {
  const normalizedSecret =
    normalizeWebhookValue(secret);

  if (!normalizedSecret) {
    return false;
  }

  const parsed =
    parseSignatureHeader(xSignature);

  if (!parsed) {
    return false;
  }

  try {
    const manifest =
      buildWebhookManifest({
        dataId,
        xRequestId,
        ts: parsed.ts,
      });

    const expectedSignature =
      crypto
          .createHmac(
              "sha256",
              normalizedSecret,
          )
          .update(manifest)
          .digest("hex");

    return safeCompareHex(
        expectedSignature,
        parsed.v1,
    );
  } catch {
    return false;
  }
}

module.exports = {
  normalizeWebhookValue,
  parseSignatureHeader,
  buildWebhookManifest,
  safeCompareHex,
  verifyWebhookSignature,
};
