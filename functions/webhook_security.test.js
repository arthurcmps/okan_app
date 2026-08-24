"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("crypto");

const {
  normalizeWebhookValue,
  parseSignatureHeader,
  buildWebhookManifest,
  verifyWebhookSignature,
} = require("./webhook_security");

const SECRET =
  "segredo-de-teste-nao-real";

function generateSignature({
  dataId,
  requestId,
  ts,
}) {
  const manifest =
    buildWebhookManifest({
      dataId,
      xRequestId: requestId,
      ts,
    });

  const signature =
    crypto
        .createHmac("sha256", SECRET)
        .update(manifest)
        .digest("hex");

  return `ts=${ts},v1=${signature}`;
}

test(
    "normaliza valores do webhook",
    () => {
      assert.equal(
          normalizeWebhookValue(" 123 "),
          "123",
      );

      assert.equal(
          normalizeWebhookValue(["456"]),
          "456",
      );
    },
);

test(
    "extrai ts e v1 de x-signature",
    () => {
      const result =
        parseSignatureHeader(
            "ts=123456,v1=abcdef",
        );

      assert.deepEqual(
          result,
          {
            ts: "123456",
            v1: "abcdef",
          },
      );
    },
);

test(
    "monta manifesto oficial",
    () => {
      assert.equal(
          buildWebhookManifest({
            dataId: "999",
            xRequestId: "request-1",
            ts: "123456",
          }),
          "id:999;" +
          "request-id:request-1;" +
          "ts:123456;",
      );
    },
);

test(
    "aceita assinatura valida",
    () => {
      const dataId = "999";
      const requestId = "request-1";
      const ts = "1704908010";

      const xSignature =
        generateSignature({
          dataId,
          requestId,
          ts,
        });

      assert.equal(
          verifyWebhookSignature({
            xSignature,
            xRequestId: requestId,
            dataId,
            secret: SECRET,
          }),
          true,
      );
    },
);

test(
    "rejeita data id alterado",
    () => {
      const requestId = "request-1";
      const ts = "1704908010";

      const xSignature =
        generateSignature({
          dataId: "999",
          requestId,
          ts,
        });

      assert.equal(
          verifyWebhookSignature({
            xSignature,
            xRequestId: requestId,
            dataId: "1000",
            secret: SECRET,
          }),
          false,
      );
    },
);

test(
    "rejeita assinatura malformada",
    () => {
      assert.equal(
          verifyWebhookSignature({
            xSignature: "invalida",
            xRequestId: "request-1",
            dataId: "999",
            secret: SECRET,
          }),
          false,
      );
    },
);

test(
    "rejeita request id ausente",
    () => {
      const xSignature =
        generateSignature({
          dataId: "999",
          requestId: "request-1",
          ts: "1704908010",
        });

      assert.equal(
          verifyWebhookSignature({
            xSignature,
            xRequestId: "",
            dataId: "999",
            secret: SECRET,
          }),
          false,
      );
    },
);
