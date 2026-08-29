# OKAN-035 — CI Flutter

## 1. Problema

Até o OKAN-034, a validação Flutter era executada manualmente antes de cada merge. O projeto já possuía gates arquiteturais e uma suíte crescente, mas não havia workflow em `.github/workflows` para executar esses checks automaticamente em Pull Requests e no `main`.

Isso permitia que uma alteração futura fosse enviada ao GitHub sem que o próprio repositório verificasse analyzer, testes e drift do lockfile.

## 2. Risco atual tratado

- regressões poderiam chegar ao `main` sem execução automática da suíte;
- o resultado local dependia da disciplina de quem executava os comandos;
- uma resolução diferente de dependências poderia modificar `pubspec.lock` silenciosamente;
- usar `stable` sem versão fixa permitiria que a toolchain mudasse sem alteração no repositório;
- actions referenciadas apenas por tags móveis aumentariam o risco de supply-chain.

## 3. Comportamento preservado

O CI não altera comportamento do aplicativo, schema, Firebase, Functions, Rules ou dependências.

Ele automatiza a validação Flutter já usada localmente:

```bash
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

Também verifica que `flutter pub get` não alterou o `pubspec.lock` versionado.

## 4. Workflow

Arquivo:

```text
.github/workflows/flutter-ci.yml
```

Triggers:

- Pull Requests destinados a `main`;
- pushes em `main`;
- execução manual por `workflow_dispatch`.

Job:

```text
Analyze and test
```

Runner:

```text
ubuntu-24.04
```

Timeout:

```text
20 minutos
```

## 5. Toolchain reproduzível

A primeira versão do OKAN-035 usou Flutter 3.38.9 porque a `.metadata` contém a revisão `67323de285b00232883f53b84095eb72be97d35c`, correspondente a esse release.

A primeira execução real mostrou que `.metadata` registra a revisão histórica do projeto/migração e não necessariamente o SDK usado para gerar o lockfile atual.

Com Flutter 3.38.9 / Dart 3.10.8, `flutter pub get` tentou rebaixar sete dependências transitivas e alterou `pubspec.lock`. O gate de lockfile bloqueou corretamente o pipeline antes do analyzer e dos testes.

O lockfile atual coincide com os pins do Flutter 3.47.0, incluindo:

- `characters 1.4.1`;
- `intl 0.20.3`;
- `matcher 0.12.20`;
- `material_color_utilities 0.13.0`;
- `test_api 0.7.12`;
- `vector_math 2.4.2`;
- SDK Dart `>=3.11.0-0`.

O workflow final fixa:

```yaml
flutter-version: '3.47.0'
channel: stable
```

A execução verde confirmou Flutter 3.47.0 com Dart 3.13.0 e lockfile inalterado.

O OKAN-035 não modifica `pubspec.lock` para acomodar a CI; a CI reproduz o contrato já versionado pelo projeto.

## 6. Actions fixadas por SHA

Para evitar referências flutuantes, as actions são chamadas por SHA completo:

- `actions/checkout` v6 → `d23441a48e516b6c34aea4fa41551a30e30af803`;
- `subosito/flutter-action` v2 → `1a449444c387b1966244ae4d4f8c696479add0b2`.

A primeira execução verde ainda usava checkout v4 e revelou o warning de depreciação do runtime Node 20. Como o runner já utiliza Node 24, o workflow foi atualizado para checkout v6 antes do merge.

A execução final com checkout v6 também ficou verde e não apresentou o warning de Node 20.

Atualizações futuras desses SHAs devem ocorrer em ticket explícito e ser revisadas como alteração de infraestrutura.

## 7. Lockfile

Depois de `flutter pub get`, o workflow executa:

```bash
git diff --exit-code -- pubspec.lock
```

Se a resolução modificar o lockfile, o job falha. A primeira execução do OKAN-035 comprovou esse gate ao detectar a incompatibilidade de Flutter 3.38.9.

Com Flutter 3.47.0 o check passou sem qualquer modificação do lockfile, inclusive na execução final com checkout v6.

## 8. Analyzer

O projeto possui infos/warnings legados conhecidos. Para preservar o contrato utilizado durante a Fase 6, a CI executa:

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
```

Resultado final validado no GitHub Actions:

```text
95 issues found
sem erro fatal
```

Assim:

- erros reais continuam bloqueando o job;
- infos/warnings legados continuam visíveis no log;
- o OKAN-035 não mistura criação de CI com limpeza ampla de lint.

## 9. Testes

A CI executa a suíte completa com:

```bash
flutter test
```

Resultado final validado:

```text
70 tests passed
```

Isso inclui os testes funcionais e os gates arquiteturais das fases anteriores. Nenhuma lista manual de testes é mantida no workflow.

## 10. Permissões e secrets

O workflow declara somente:

```yaml
permissions:
  contents: read
```

O OKAN-035 não exige Firebase credentials, service accounts, tokens de pagamento ou qualquer secret de aplicação.

## 11. Concorrência

O workflow usa `concurrency` por workflow/ref e cancela execuções antigas da mesma branch quando um commit mais novo é enviado.

Isso evita gastar minutos de CI validando commits substituídos no mesmo PR.

## 12. Migração de dados

Não.

## 13. Firebase Emulator

Não é necessário para o OKAN-035 porque não houve alteração de Rules, Functions ou schema.

Os testes Firebase/Emulator continuam pertencendo ao OKAN-037.

## 14. Risco para produção

Baixo.

O ticket adiciona apenas infraestrutura de validação do repositório. Não altera binário, runtime ou persistência do app.

O principal risco era escolher uma toolchain diferente daquela que gerou o lockfile. A própria primeira execução detectou esse problema antes do merge; as execuções corrigidas com Flutter 3.47.0 ficaram verdes de ponta a ponta.

## 15. Rollback

Reverter o merge do OKAN-035 ou remover `.github/workflows/flutter-ci.yml`.

Não existe rollback de dados.

## 16. Critérios de aceite

- [x] workflow Flutter criado em `.github/workflows`;
- [x] PRs para `main` disparam CI;
- [x] pushes em `main` disparam CI;
- [x] execução manual disponível;
- [x] toolchain fixada explicitamente;
- [x] Flutter alinhado ao lockfile atual em 3.47.0;
- [x] actions externas fixadas por SHA;
- [x] checkout atualizado para v6/Node 24;
- [x] permissões mínimas `contents: read`;
- [x] lockfile verificado contra drift;
- [x] analyzer usa o contrato atual do projeto;
- [x] analyzer CI sem erro fatal, 95 issues legadas;
- [x] suíte Flutter completa executada;
- [x] 70/70 testes verdes na CI;
- [x] nenhum secret necessário;
- [x] nenhuma dependência atualizada;
- [x] nenhuma mudança de Rules/Functions/schema;
- [x] gate de lockfile provou bloquear incompatibilidade de SDK;
- [x] execução corrigida do workflow em PR verde;
- [x] execução final com checkout v6 verde e sem warning de Node 20.

## 17. Próximo ticket

Depois do OKAN-035:

- OKAN-036 — CI Functions.

## 18. Status

Implementação e validação do GitHub Actions concluídas na branch `quality/okan-035-ci-flutter`.

Evidência principal:

- primeira execução: falhou no lockfile com Flutter 3.38.9, detectando toolchain incompatível;
- execução corrigida: Flutter 3.47.0, lockfile inalterado, analyzer sem erro fatal com 95 issues legadas e 70/70 testes verdes;
- execução final: checkout v6 + Flutter 3.47.0, lockfile inalterado, analyzer sem erro fatal com 95 issues legadas, 70/70 testes verdes e sem warning de runtime Node 20.

OKAN-035 concluído e pronto para merge.
