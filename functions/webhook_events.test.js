"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  normalizeWebhookNotificationId,
  getWebhookEventDocumentId,
  isWebhookEventProcessed,
  markWebhookEventProcessed,
} = require("./webhook_events");

function createFakeFirestore() {
  const state = new Map();

  function makeRef(path) {
    return {
      path,

      async get() {
        return {
          exists:
            state.has(path),

          data() {
            return state.get(path);
          },
        };
      },

      async set(data, options) {
        const previous =
          state.get(path) || {};

        state.set(
            path,
            options?.merge
              ? {
                  ...previous,
                  ...data,
                }
              : data,
        );
      },
      async create(data) {
        if (state.has(path)) {
          const error =
            new Error("ALREADY_EXISTS");

          error.code = 6;

          throw error;
        }

        state.set(path, data);
      },
    };
  }

  return {
    firestore: {
      collection(name) {
        return {
          doc(id) {
            return makeRef(
                `${name}/${id}`,
            );
          },
        };
      },
    },

    state,
  };
}

test(
    "normaliza ID da notificacao",
    () => {
      assert.equal(
          normalizeWebhookNotificationId(
              " 12345 ",
          ),
          "12345",
      );
    },
);

test(
    "ID do documento de evento e deterministico",
    () => {
      const first =
        getWebhookEventDocumentId(
            "12345",
        );

      const second =
        getWebhookEventDocumentId(
            "12345",
        );

      assert.equal(
          first,
          second,
      );

      assert.equal(
          first.startsWith(
              "mercadopago_",
          ),
          true,
      );
    },
);

test(
    "marca e detecta evento processado",
    async () => {
      const fake =
        createFakeFirestore();

      assert.equal(
          await isWebhookEventProcessed({
            firestore:
              fake.firestore,

            notificationId:
              "notif-1",
          }),
          false,
      );

      await markWebhookEventProcessed({
        firestore:
          fake.firestore,

        serverTimestamp:
          () => "timestamp",

        notificationId:
          "notif-1",

        providerPaymentId:
          "999",

        requestId:
          "request-1",

        outcome:
          "approved",
      });

      assert.equal(
          await isWebhookEventProcessed({
            firestore:
              fake.firestore,

            notificationId:
              "notif-1",
          }),
          true,
      );
    },
);

test(
    "rejeita ID vazio de notificacao",
    () => {
      assert.throws(
          () =>
            normalizeWebhookNotificationId(
                "",
            ),
          /INVALID_WEBHOOK_NOTIFICATION_ID/,
      );
    },
);

test(
    "segunda marcacao do mesmo evento e idempotente",
    async () => {
      const fake =
        createFakeFirestore();

      const params = {
        firestore:
          fake.firestore,

        serverTimestamp:
          () => "timestamp",

        notificationId:
          "notif-duplicada",

        providerPaymentId:
          "999",

        requestId:
          "request-1",

        outcome:
          "approved",
      };

      const first =
        await markWebhookEventProcessed(
            params,
        );

      const second =
        await markWebhookEventProcessed(
            params,
        );

      assert.equal(
          first.created,
          true,
      );

      assert.equal(
          first.alreadyProcessed,
          false,
      );

      assert.equal(
          second.created,
          false,
      );

      assert.equal(
          second.alreadyProcessed,
          true,
      );
    },
);
