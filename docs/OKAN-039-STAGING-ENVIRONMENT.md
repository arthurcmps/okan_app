# OKAN-039 — Ambiente staging

## 1. Problema

Após o OKAN-038, o Okan possui produção e desenvolvimento local separados, mas staging precisava de um Firebase cloud próprio e de um contrato que impedisse qualquer fallback para produção.

## 2. Projeto staging oficial

O primeiro projeto `okan-staging` foi descartado porque o Firestore `(default)` foi criado em `nam5`, divergindo da arquitetura canônica `southamerica-east1`.

O projeto Firebase staging oficial de substituição é:

```text
okan-staging-24829
```

Esse é o único project ID aceito pelo contrato `OKAN_ENV=staging`.

Produção e desenvolvimento continuam separados:

```text
PROD    app-academia-2914d
STAGING okan-staging-24829
DEV     demo-okan-dev
```

## 3. Comportamento preservado

- `OKAN_ENV=prod` continua sendo o default;
- `OKAN_ENV=dev` continua usando `demo-okan-dev` + Emulator Suite;
- nenhuma dependência é atualizada;
- nenhum schema, Rule ou dado é alterado;
- não existe deploy automático para staging.

## 4. Contrato staging

`staging`:

- usa Firebase cloud, não Emulator Suite;
- exige configuração Firebase explícita por `--dart-define`;
- aceita somente `OKAN_STAGING_FIREBASE_PROJECT_ID=okan-staging-24829`;
- habilita App Check;
- habilita push/FCM para homologação próxima de produção;
- mantém pagamentos externos desativados;
- exibe banner `STAGING`;
- usa título `Okan App [STAGING]`.

## 5. Configuração Firebase obrigatória

O build exige:

```text
OKAN_STAGING_FIREBASE_PROJECT_ID
OKAN_STAGING_FIREBASE_MESSAGING_SENDER_ID
OKAN_STAGING_FIREBASE_STORAGE_BUCKET
OKAN_STAGING_FIREBASE_WEB_API_KEY
OKAN_STAGING_FIREBASE_WEB_APP_ID
OKAN_STAGING_FIREBASE_WEB_AUTH_DOMAIN
OKAN_STAGING_FIREBASE_ANDROID_API_KEY
OKAN_STAGING_FIREBASE_ANDROID_APP_ID
OKAN_STAGING_FIREBASE_IOS_API_KEY
OKAN_STAGING_FIREBASE_IOS_APP_ID
OKAN_STAGING_FIREBASE_IOS_BUNDLE_ID
```

A configuração Firebase de cliente não é tratada como segredo, mas permanece fora do código para impedir mistura acidental entre ambientes.

## 6. Execução

Depois de registrar os apps Web/Android/iOS no projeto `okan-staging-24829`:

```powershell
flutter run `
  --dart-define=OKAN_ENV=staging `
  --dart-define=OKAN_STAGING_FIREBASE_PROJECT_ID=okan-staging-24829 `
  --dart-define=OKAN_STAGING_FIREBASE_MESSAGING_SENDER_ID=<sender-id> `
  --dart-define=OKAN_STAGING_FIREBASE_STORAGE_BUCKET=<bucket> `
  --dart-define=OKAN_STAGING_FIREBASE_WEB_API_KEY=<web-api-key> `
  --dart-define=OKAN_STAGING_FIREBASE_WEB_APP_ID=<web-app-id> `
  --dart-define=OKAN_STAGING_FIREBASE_WEB_AUTH_DOMAIN=<auth-domain> `
  --dart-define=OKAN_STAGING_FIREBASE_ANDROID_API_KEY=<android-api-key> `
  --dart-define=OKAN_STAGING_FIREBASE_ANDROID_APP_ID=<android-app-id> `
  --dart-define=OKAN_STAGING_FIREBASE_IOS_API_KEY=<ios-api-key> `
  --dart-define=OKAN_STAGING_FIREBASE_IOS_APP_ID=<ios-app-id> `
  --dart-define=OKAN_STAGING_FIREBASE_IOS_BUNDLE_ID=com.sankofa.okan
```

## 7. Bootstrap foreground/background

O handler de Firebase Messaging em background resolve `OkanEnvironmentConfig.current` e chama `FirebaseEnvironmentService.initialize(environment)`, assim como o bootstrap principal.

Isso impede que um build staging reconecte ao Firebase de produção ao receber uma notificação em background.

## 8. Pagamentos

`enableExternalPayments` é verdadeiro somente em produção.

Portanto, staging preserva as guards antes de:

- `api.mercadopago.com`;
- `criarPagamentoPix`;
- `criarPagamentoCartao`;
- fluxo de assinatura externa.

A mensagem legada ainda menciona DEV; a redação é dívida de nomenclatura, não uma falha do bloqueio.

## 9. Android e iOS

Identificadores oficiais atuais do app:

```text
Android applicationId: com.sankofa.okan
iOS bundle identifier: com.sankofa.okan
```

Em Android debug, `FirebaseInitProvider` nativo permanece removido e o Dart controla o Firebase `[DEFAULT]`. O primeiro teste cloud staging deve ser feito em debug antes de qualquer artefato release staging.

## 10. Migração de dados

Não.

Staging deve começar vazio. Não existe cópia automática de dados de produção.

## 11. Testes locais

```powershell
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test test/core/config/app_environment_test.dart test/core/services/firebase_environment_architecture_test.dart
flutter test
```

## 12. Risco de produção

Baixo.

Produção continua default e staging falha fechado se qualquer valor Firebase obrigatório estiver ausente ou se o project ID for diferente de `okan-staging-24829`.

## 13. Critérios de aceite

- [x] staging é ambiente reconhecido;
- [x] staging não usa emuladores;
- [x] staging exige Firebase config explícita;
- [x] project ID oficial fixado em `okan-staging-24829`;
- [x] staging mostra banner próprio;
- [x] App Check e push permanecem habilitados em staging;
- [x] pagamentos externos ficam bloqueados em staging;
- [x] bootstrap FCM background respeita o ambiente;
- [x] produção permanece default;
- [x] dev permanece Emulator Suite;
- [x] projeto Firebase staging de substituição criado;
- [ ] apps Firebase Web/Android/iOS registrados no projeto de substituição;
- [ ] Auth/Firestore/Storage/Functions provisionados;
- [ ] App Check staging configurado;
- [ ] validação integrada cloud staging concluída;
- [ ] Flutter CI verde no HEAD final;
- [ ] analyzer local sem erro fatal;
- [ ] suíte completa local verde.
