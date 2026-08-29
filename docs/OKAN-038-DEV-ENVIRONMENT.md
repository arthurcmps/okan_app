# OKAN-038 — Ambiente dev

## 1. Problema

O app inicializava sempre `DefaultFirebaseOptions`, que aponta para o projeto Firebase de produção. Antes deste ticket não existia um modo explícito de executar o Flutter contra o Local Emulator Suite.

## 2. Risco tratado

- autenticação local usando produção;
- leituras/escritas locais em Firestore/Storage reais;
- callable Functions locais atingindo backend real;
- App Check e FCM sendo inicializados durante desenvolvimento;
- ambiente `staging` ou valor inválido caindo silenciosamente em produção.

## 3. Comportamento preservado

Sem `--dart-define`, o app continua usando:

```text
OKAN_ENV=prod
```

Produção mantém `DefaultFirebaseOptions`, App Check e push notifications.

Não houve mudança de schema, dados, Rules, Functions, dependências ou `pubspec.lock`.

## 4. Novo contrato de ambiente

Ambientes aceitos neste ticket:

```text
prod
dev
```

`staging` é reservado ao OKAN-039 e falha explicitamente até ser configurado.

Valores desconhecidos também falham; não existe fallback para produção.

## 5. Dev Firebase

O app dev inicializa um Firebase app sintético com:

```text
projectId = demo-okan-dev
```

Serviços redirecionados:

```text
Auth       9099
Firestore  8080
Functions  5001
Storage    9199
```

As regiões de Functions configuradas são:

```text
us-central1
southamerica-east1
```

## 6. Host obrigatório

`OKAN_ENV=dev` exige `OKAN_EMULATOR_HOST`.

Android Emulator:

```powershell
flutter run `
  --dart-define=OKAN_ENV=dev `
  --dart-define=OKAN_EMULATOR_HOST=10.0.2.2
```

Windows/web no mesmo computador:

```powershell
flutter run `
  --dart-define=OKAN_ENV=dev `
  --dart-define=OKAN_EMULATOR_HOST=127.0.0.1
```

Aparelho Android físico conectado por USB usa `adb reverse`, mantendo os emuladores acessíveis apenas em localhost no computador:

```powershell
adb reverse tcp:9099 tcp:9099
adb reverse tcp:8080 tcp:8080
adb reverse tcp:5001 tcp:5001
adb reverse tcp:9199 tcp:9199

flutter run `
  --dart-define=OKAN_ENV=dev `
  --dart-define=OKAN_EMULATOR_HOST=127.0.0.1
```

Isso evita expor Auth, Firestore, Functions e Storage Emulator para a rede local.

## 7. Integrações desativadas em dev

Em `dev` o app não inicializa:

- Firebase App Check;
- Firebase Messaging/background handler;
- registro de push/local notification channel pelo bootstrap principal.

Isso evita registrar tokens ou depender de serviços cloud de produção durante desenvolvimento local.

## 8. Identificação visual

Build dev exibe banner:

```text
DEV • LOCAL
```

O título também passa a ser `Okan App [DEV]`.

## 9. Android

Somente o manifest de `debug` permite cleartext HTTP, necessário para o Functions Emulator.

O manifest principal/release não recebe `usesCleartextTraffic=true`.

## 10. Migração de dados

Não.

O ambiente local começa vazio e não importa dados de produção automaticamente.

## 11. Arquivos alterados

- `lib/core/config/app_environment.dart`;
- `lib/core/services/firebase_environment_service.dart`;
- `lib/main.dart`;
- `android/app/src/debug/AndroidManifest.xml`;
- testes do contrato dev;
- esta documentação.

## 12. Testes locais

```powershell
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test test/core/config/app_environment_test.dart test/core/services/firebase_environment_architecture_test.dart
flutter test
```

## 13. Teste integrado com backend local

Terminal 1:

```powershell
cd C:\Users\Public\Documents\Projetos\Academia\okan_backend
npm run dev:emulators
```

Terminal 2, Android Emulator:

```powershell
cd C:\Users\Public\Documents\Projetos\Academia\okan_app
flutter run `
  --dart-define=OKAN_ENV=dev `
  --dart-define=OKAN_EMULATOR_HOST=10.0.2.2
```

Terminal 2, aparelho Android físico por USB:

```powershell
adb reverse tcp:9099 tcp:9099
adb reverse tcp:8080 tcp:8080
adb reverse tcp:5001 tcp:5001
adb reverse tcp:9199 tcp:9199

cd C:\Users\Public\Documents\Projetos\Academia\okan_app
flutter run `
  --dart-define=OKAN_ENV=dev `
  --dart-define=OKAN_EMULATOR_HOST=127.0.0.1
```

Critério visual: o app precisa exibir `DEV • LOCAL` e qualquer usuário criado no Auth Emulator deve existir somente no ambiente local.

## 14. Risco de produção

Baixo.

O modo padrão continua produção, enquanto o modo dev é fail-closed e usa um project ID `demo-` separado. Em aparelho físico, o fluxo recomendado usa `adb reverse` em vez de abrir os emuladores para a LAN.

## 15. Rollback

Reverter o merge do OKAN-038. Não existe rollback de dados.

## 16. Critérios de aceite

- [x] `prod` preserva comportamento atual;
- [x] `dev` exige host explícito;
- [x] dev usa `demo-okan-dev`;
- [x] Auth/Firestore/Functions/Storage usam emuladores;
- [x] App Check desativado em dev;
- [x] FCM/push bootstrap desativado em dev;
- [x] staging não pode cair em produção;
- [x] ambiente desconhecido não pode cair em produção;
- [x] cleartext HTTP restrito a Android debug;
- [x] aparelho físico usa fluxo localhost via `adb reverse`;
- [x] banner visual de ambiente criado;
- [x] testes automatizados do contrato criados;
- [ ] Flutter CI verde no HEAD final;
- [ ] analyzer local sem erro fatal;
- [ ] testes focados locais verdes;
- [ ] suíte completa local verde;
- [ ] teste integrado com Emulator Suite verde;
- [ ] working tree local limpa após merge.

## 17. Próximo ticket

OKAN-039 — ambiente staging.
