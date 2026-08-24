"use strict";

/**
 * Converte Date, Firestore Timestamp ou valor parseável
 * em um Date válido.
 *
 * @param {unknown} value Valor.
 * @return {Date} Data normalizada.
 */
function toDate(value) {
  let date;

  if (value instanceof Date) {
    date = new Date(value.getTime());
  } else if (
    value &&
    typeof value.toDate === "function"
  ) {
    date = value.toDate();
  } else {
    date = new Date(value);
  }

  if (
    !(date instanceof Date) ||
    Number.isNaN(date.getTime())
  ) {
    throw new Error(
        "INVALID_SUBSCRIPTION_DATE",
    );
  }

  return date;
}

/**
 * Adiciona um mês de calendário preservando
 * horário e limitando o dia ao último dia
 * disponível do mês de destino.
 *
 * Exemplo:
 * 31/01 -> 28/02 ou 29/02.
 *
 * @param {unknown} value Data base.
 * @return {Date} Data acrescida de um mês.
 */
function addCalendarMonth(value) {
  const source = toDate(value);

  const year =
    source.getUTCFullYear();

  const month =
    source.getUTCMonth();

  const day =
    source.getUTCDate();

  const hour =
    source.getUTCHours();

  const minute =
    source.getUTCMinutes();

  const second =
    source.getUTCSeconds();

  const millisecond =
    source.getUTCMilliseconds();

  /*
   * Primeiro dia do próximo mês.
   */
  const target =
    new Date(
        Date.UTC(
            year,
            month + 1,
            1,
            hour,
            minute,
            second,
            millisecond,
        ),
    );

  const lastDay =
    new Date(
        Date.UTC(
            target.getUTCFullYear(),
            target.getUTCMonth() + 1,
            0,
            hour,
            minute,
            second,
            millisecond,
        ),
    ).getUTCDate();

  target.setUTCDate(
      Math.min(day, lastDay),
  );

  return target;
}

/**
 * Calcula o novo período mensal.
 *
 * Se ainda houver saldo de assinatura,
 * preserva o início atual e acrescenta
 * um mês ao vencimento existente.
 *
 * @param {object} params Dados.
 * @return {object} Novo período.
 */
function calculateMonthlySubscriptionPeriod({
  now,
  currentPeriodStart = null,
  currentPeriodEnd = null,
}) {
  const nowDate =
    toDate(now);

  let periodStart =
    nowDate;

  let extensionBase =
    nowDate;

  if (currentPeriodEnd) {
    const existingEnd =
      toDate(currentPeriodEnd);

    if (
      existingEnd.getTime() >
      nowDate.getTime()
    ) {
      extensionBase =
        existingEnd;

      if (currentPeriodStart) {
        const existingStart =
          toDate(currentPeriodStart);

        if (
          existingStart.getTime() <=
          nowDate.getTime()
        ) {
          periodStart =
            existingStart;
        }
      }
    }
  }

  return {
    currentPeriodStart:
      periodStart,

    currentPeriodEnd:
      addCalendarMonth(
          extensionBase,
      ),
  };
}

module.exports = {
  toDate,
  addCalendarMonth,
  calculateMonthlySubscriptionPeriod,
};
