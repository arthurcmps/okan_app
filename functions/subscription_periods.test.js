"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  addCalendarMonth,
  calculateMonthlySubscriptionPeriod,
} = require("./subscription_periods");

test(
    "cria um periodo mensal novo",
    () => {
      const result =
        calculateMonthlySubscriptionPeriod({
          now:
            new Date(
                "2026-08-23T12:00:00Z",
            ),
        });

      assert.equal(
          result.currentPeriodStart
              .toISOString(),
          "2026-08-23T12:00:00.000Z",
      );

      assert.equal(
          result.currentPeriodEnd
              .toISOString(),
          "2026-09-23T12:00:00.000Z",
      );
    },
);

test(
    "renovacao antecipada preserva saldo",
    () => {
      const result =
        calculateMonthlySubscriptionPeriod({
          now:
            new Date(
                "2026-09-10T12:00:00Z",
            ),

          currentPeriodStart:
            new Date(
                "2026-08-23T12:00:00Z",
            ),

          currentPeriodEnd:
            new Date(
                "2026-09-23T12:00:00Z",
            ),
        });

      assert.equal(
          result.currentPeriodStart
              .toISOString(),
          "2026-08-23T12:00:00.000Z",
      );

      assert.equal(
          result.currentPeriodEnd
              .toISOString(),
          "2026-10-23T12:00:00.000Z",
      );
    },
);

test(
    "assinatura vencida inicia novo periodo",
    () => {
      const result =
        calculateMonthlySubscriptionPeriod({
          now:
            new Date(
                "2026-10-01T12:00:00Z",
            ),

          currentPeriodStart:
            new Date(
                "2026-08-23T12:00:00Z",
            ),

          currentPeriodEnd:
            new Date(
                "2026-09-23T12:00:00Z",
            ),
        });

      assert.equal(
          result.currentPeriodStart
              .toISOString(),
          "2026-10-01T12:00:00.000Z",
      );

      assert.equal(
          result.currentPeriodEnd
              .toISOString(),
          "2026-11-01T12:00:00.000Z",
      );
    },
);

test(
    "fim de janeiro respeita fim de fevereiro",
    () => {
      assert.equal(
          addCalendarMonth(
              new Date(
                  "2026-01-31T12:00:00Z",
              ),
          ).toISOString(),
          "2026-02-28T12:00:00.000Z",
      );
    },
);
