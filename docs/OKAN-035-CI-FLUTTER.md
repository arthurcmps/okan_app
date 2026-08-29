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

Ele automatiza exatamente a validação Flutter já usada localmente:

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

A `.metadata` do projeto aponta para a revisão Flutter:

```text
67323de285b00232883f53b84095eb72be97d35c
```

Essa revisão corresponde ao release:

```text
Flutter 3.38.9
```

Por isso o workflow fixa explicitamente:

```yaml
flutter-version: '3.38.9'
channel: stable
```

Nenhum upgrade de Flutter ou dependência é realizado pelo OKAN-035.

## 6. Actions fixadas por SHA

Para evitar referências flutuantes no pipeline, as actions são chamadas por commit SHA completo, mantendo o comentário da major tag apenas para legibilidade:

- `actions/checkout` v4 → `11d5960a326750d5838078e36cf38b85af677262`;
- `subosito/flutter-action` v2 → `1a449444c387b1966244ae4d4f8c696479add0b2`.

A atualização futura desses SHAs deve ocorrer em ticket explícito e ser revisada como alteração de infraestrutura.

## 7. Lockfile

Depois de `flutter pub get`, o workflow executa:

```bash
git diff --exit-code -- pubspec.lock
```

Se a resolução de dependências modificar o lockfile, o job falha. Isso obriga qualquer mudança de resolução a ser versionada explicitamente em vez de acontecer apenas dentro da CI.

## 8. Analyzer

O projeto possui infos/warnings legados conhecidos. Para preservar o contrato já utilizado durante a Fase 6, a CI executa:

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
```

Assim:

- erros reais continuam bloqueando o job;
- infos/warnings legados continuam visíveis no log;
- o OKAN-035 não mistura criação de CI com uma limpeza ampla de lint.

A redução do baseline de warnings deve ocorrer em trabalho separado.

## 9. Testes

A CI executa a suíte completa com:

```bash
flutter test
```

Isso inclui os testes funcionais existentes e os gates arquiteturais criados nas fases anteriores.

Nenhuma lista manual de testes é mantida no workflow, evitando que novos testes sejam esquecidos no pipeline.

## 10. Permissões e secrets

O workflow declara somente:

```yaml
permissions:
  contents: read
```

O OKAN-035 não exige Firebase credentials, service accounts, tokens de pagamento ou qualquer secret de aplicação.

## 11. Concorrência

O workflow usa `concurrency` por workflow/ref e cancela execuções antigas da mesma branch quando um commit mais novo é enviado.

Isso evita gastar minutos de CI validando commits que já foram substituídos no mesmo PR.

## 12. Migração de dados

Não.

## 13. Firebase Emulator

Não é necessário para o OKAN-035 porque não houve alteração de Rules, Functions ou schema.

Os testes Firebase/Emulator continuam pertencendo ao OKAN-037.

## 14. Risco para produção

Baixo.

O ticket adiciona apenas infraestrutura de validação do repositório. Não altera binário, runtime ou persistência do app.

O principal risco é uma configuração de CI incompatível com a toolchain real; por isso Flutter é fixado em 3.38.9 e o primeiro PR deve ser validado pelo próprio workflow antes do merge.

## 15. Rollback

Reverter o merge do OKAN-035 ou remover `.github/workflows/flutter-ci.yml`.

Não existe rollback de dados.

## 16. Critérios de aceite

- [x] workflow Flutter criado em `.github/workflows`;
- [x] PRs para `main` disparam CI;
- [x] pushes em `main` disparam CI;
- [x] execução manual disponível;
- [x] Flutter fixado em 3.38.9;
- [x] actions externas fixadas por SHA;
- [x] permissões mínimas `contents: read`;
- [x] lockfile verificado contra drift;
- [x] analyzer usa o contrato atual do projeto;
- [x] suíte Flutter completa é executada;
- [x] nenhum secret necessário;
- [x] nenhuma dependência atualizada;
- [x] nenhuma mudança de Rules/Functions/schema;
- [ ] primeira execução do workflow em PR verde;
- [ ] working tree local limpa e sincronizada após validação.

## 17. Próximo ticket

Depois do OKAN-035:

- OKAN-036 — CI Functions.

## 18. Status

Implementação do workflow concluída na branch `quality/okan-035-ci-flutter`.

Pendente validar a primeira execução real do GitHub Actions antes do merge.
