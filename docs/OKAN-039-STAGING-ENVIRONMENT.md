# OKAN-039 — Ambiente staging

## 1. Problema

Após o OKAN-038, o Okan possui produção e desenvolvimento local separados, mas `staging` ainda não possui configuração própria. Sem um contrato explícito, um build de homologação poderia cair no Firebase de produção.

## 2. Risco atual

- build de homologação autenticando em produção;
- Firestore/Storage de produção recebendo dados de teste;
- Functions de produção sendo chamadas durante QA;
- FCM em background reinicializando o projeto de produção;
- pagamentos externos reais sendo disparados em um ambiente não produtivo.

## 3. Comportamento preservado

- `OKAN_ENV=prod` continua sendo o default;
- `OKAN_ENV=dev` continua usando `demo-okan-dev` + Emulator Suite;
- nenhuma dependência é atualizada;
- nenhum schema, Rule ou dado é alterado;
- não existe deploy automático para staging.

## 4. Novo comportamento

Ambientes válidos:

```text
prod
staging
dev
```

`staging`:

- usa Firebase cloud, não Emulator Suite;
- exige configuração Firebase explícita por `--dart-define`;
- rejeita o project ID de produção;
- rejeita `demo-okan-dev` e qualquer project ID `demo-*`;
- habilita App Check;
- habilita push/FCM para permitir homologação próxima de produção;
- mantém pagamentos externos desativados;
- exibe banner `STAGING`;
- usa título `Okan App [STAGING]`.

## 5. Configuração Firebase obrigatória

Nenhum project ID de staging é inventado ou versionado antes do provisionamento real. O build exige:

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

A configuração Firebase de cliente não é tratada como segredo, mas continua fora do código para impedir mistura acidental entre ambientes.

## 6. Execução

Depois que o projeto Firebase staging existir e os apps Web/Android/iOS forem registrados:

```powershell
flutter run `
  --dart-define=OKAN_ENV=staging `
  --dart-define=OKAN_STAGING_FIREBASE_PROJECT_ID=<staging-project-id> `
  --dart-define=OKAN_STAGING_FIREBASE_MESSAGING_SENDER_ID=<sender-id> `
  --dart-define=OKAN_STAGING_FIREBASE_STORAGE_BUCKET=<bucket> `
  --dart-define=OKAN_STAGING_FIREBASE_WEB_API_KEY=<web-api-key> `
  --dart-define=OKAN_STAGING_FIREBASE_WEB_APP_ID=<web-app-id> `
  --dart-define=OKAN_STAGING_FIREBASE_WEB_AUTH_DOMAIN=<auth-domain> `
  --dart-define=OKAN_STAGING_FIREBASE_ANDROID_API_KEY=<android-api-key> `
  --dart-define=OKAN_STAGING_FIREBASE_ANDROID_APP_ID=<android-app-id> `
  --dart-define=OKAN_STAGING_FIREBASE_IOS_API_KEY=<ios-api-key> `
  --dart-define=OKAN_STAGING_FIREBASE_IOS_APP_ID=<ios-app-id> `
  --dart-define=OKAN_STAGING_FIREBASE_IOS_BUNDLE_ID=<ios-bundle-id>
```

## 7. Bootstrap foreground/background

O handler de Firebase Messaging em background não usa mais `DefaultFirebaseOptions` diretamente. Ele resolve `OkanEnvironmentConfig.current` e chama `FirebaseEnvironmentService.initialize(environment)`, assim como o bootstrap principal.

Isso impede que um build staging reconecte ao Firebase de produção ao receber uma notificação em background.

## 8. Pagamentos

`enableExternalPayments` é verdadeiro somente em produção.

Portanto, staging preserva as guards já existentes antes de:

- `api.mercadopago.com`;
- `criarPagamentoPix`;
- `criarPagamentoCartao`;
- fluxo de assinatura externa.

A mensagem continua:

```text
Pagamentos externos estão desativados no ambiente DEV.
```

A redação dessa mensagem é dívida de nomenclatura; o comportamento de bloqueio é o critério de segurança deste ticket.

## 9. Android

O OKAN-039 mantém o comportamento do OKAN-038: em debug, `FirebaseInitProvider` nativo é removido e o Dart controla o Firebase `[DEFAULT]`.

Enquanto o projeto staging real não estiver provisionado, a validação integrada será feita em debug. Um artefato release staging deve ser validado após registrar o app Android staging e seu App Check no projeto correspondente.

## 10. Migração de dados

Não.

Staging deve começar vazio. Não existe cópia automática de dados de produção.

## 11. Arquivos alterados

- `lib/core/config/app_environment.dart`;
- `lib/core/services/firebase_environment_service.dart`;
- `lib/main.dart`;
- testes de ambiente/arquitetura;
- esta documentação.

## 12. Testes locais

```powershell
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test test/core/config/app_environment_test.dart test/core/services/firebase_environment_architecture_test.dart
flutter test
```

## 13. Risco de produção

Baixo.

Produção continua default e staging falha fechado se qualquer valor Firebase obrigatório estiver ausente ou se o project ID coincidir com produção/dev/demo.

## 14. Rollback

Reverter o merge do OKAN-039. Não existe rollback de dados porque o ticket não migra nem escreve dados automaticamente.

## 15. Critérios de aceite

- [x] staging é ambiente reconhecido;
- [x] staging não usa emuladores;
- [x] staging exige Firebase config explícita;
- [x] staging rejeita `app-academia-2914d`;
- [x] staging rejeita `demo-okan-dev` e `demo-*`;
- [x] staging mostra banner próprio;
- [x] App Check e push permanecem habilitados em staging;
- [x] pagamentos externos ficam bloqueados em staging;
- [x] bootstrap FCM background respeita o ambiente;
- [x] produção permanece default;
- [x] dev permanece Emulator Suite;
- [ ] projeto Firebase staging real provisionado;
- [ ] App Check staging configurado;
- [ ] validação integrada cloud staging concluída;
- [ ] Flutter CI verde no HEAD final;
- [ ] analyzer local sem erro fatal;
- [ ] suíte completa local verde.
