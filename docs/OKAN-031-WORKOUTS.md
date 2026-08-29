# OKAN-031 — Separar Workouts no Flutter

## 1. Problema

A feature de treinos ainda estava fisicamente misturada dentro de `features/auth` e várias telas conheciam diretamente coleções, snapshots, `Timestamp` e `FieldValue` do Firestore.

Isso impedia Workouts de ter uma fronteira de domínio própria e fazia mudanças no schema ou no fluxo de execução atingirem apresentação e persistência ao mesmo tempo.

## 2. Risco tratado

- telas de criação, gestão, execução, ficha semanal e histórico acopladas ao Firestore;
- `WorkoutHistory` dependente de `Timestamp`;
- modelos de treino dentro da feature Auth;
- CRUD, execução, feedback, templates, validade e histórico duplicando conhecimento de caminhos Firestore;
- separação posterior de Students, Assessments e Store acoplada a Workouts.

## 3. Comportamento preservado

Esta melhoria não altera schema nem nomes de coleções.

Permanecem:

- `workouts` para modelos de treino;
- `exercises` para catálogo de exercícios;
- `workout_plans/{studentId}` para ficha semanal;
- `workout_history` para histórico;
- `workout_templates` para templates do profissional e catálogo da loja;
- subcoleção `users/{uid}/notifications` para avisos de treino;
- `personalId`, `criadoEm` e `atualizadoEm` nos modelos;
- compatibilidade de `professorId` via `UserModel` v2;
- feedback do treino;
- solicitação de alteração de exercício;
- validade e aviso de vencimento;
- reset de `concluido` após finalizar um treino;
- catálogo, templates, vídeos e timer de descanso;
- checkout/Store/Payments de `discover_workouts_page.dart` permanece fora do escopo deste ticket;
- avaliações corporais de `evolution_charts_page.dart` permanecem para OKAN-033;
- rotas/imports antigos por exports de compatibilidade.

## 4. Arquitetura

Workouts passa a possuir:

```text
lib/features/workouts/
  data/repositories/firebase_workouts_repository.dart
  domain/entities/
    weekly_workout_plan.dart
    workout_exercise.dart
    workout_history.dart
    workout_model.dart
  domain/repositories/workouts_repository.dart
  presentation/pages/
    create_workout_page.dart
    manage_workouts_page.dart
    train_page.dart
    weekly_plan_page.dart
    workout_history_page.dart
```

`WorkoutsRepository` é orientado ao domínio. Não existe repository genérico de Firestore.

`FirebaseWorkoutsRepository` recebe `FirebaseFirestore` por injeção opcional e concentra a tradução entre entidades e infraestrutura Firebase.

## 5. Migração de dados

Não.

Nenhuma coleção, documento, Security Rule ou Function é alterado neste ticket.

## 6. Checkpoint A — núcleo de Workouts

Migrados para `features/workouts`:

- Create Workout;
- Manage Workouts;
- Train;
- Workout History;
- `WorkoutExercise`;
- `WorkoutHistory`;
- `WorkoutModel`;
- `WorkoutsRepository` e implementação Firebase.

Os caminhos antigos em `features/auth` permanecem como `export` de compatibilidade.

### Validação local recebida

- `flutter analyze --no-fatal-infos --no-fatal-warnings`: sem erro fatal;
- analyzer: 173 issues legadas não bloqueantes;
- testes específicos de Workouts + gate arquitetural: `+6`, todos passaram;
- a primeira saída da suíte completa terminou durante resolução de dependências e não foi contabilizada.

## 7. Checkpoint B — Weekly Plan

`WeeklyPlanPage` foi movida fisicamente para `features/workouts/presentation/pages`.

A apresentação não acessa mais Firestore diretamente para:

- identificar se o usuário atua como profissional;
- assistir a ficha semanal;
- salvar lista de exercícios por dia;
- salvar/limpar feedback;
- concluir treino e gerar histórico;
- definir validade;
- marcar aviso de vencimento;
- localizar o profissional do aluno;
- criar notificações de treino;
- listar/salvar/excluir templates;
- listar catálogo de exercícios.

Essas operações agora passam pelo `WorkoutsRepository`.

O `UserModel` existente continua sendo usado dentro da camada `data` para preservar a semântica canônica de `memberType`/`isTrainingProfessional` e o fallback já normalizado de `professorId`.

O caminho antigo `features/auth/presentation/pages/weekly_plan_page.dart` virou export de compatibilidade.

O gate arquitetural removeu `weekly_plan_page.dart` do baseline legado e passou a exigir `WorkoutsRepository` na nova página.

### Validação local recebida

- analyzer sem erro fatal;
- analyzer: 160 issues legadas não bloqueantes;
- Workouts + gate arquitetural: `+7`, todos passaram;
- suíte completa: `+47`, todos passaram;
- branch sincronizada com `origin` e working tree limpa.

## 8. Checkpoint C — telas mistas

### `discover_workouts_page.dart`

A tela continua sendo uma composição temporária de Store/Payments + recomendações + aplicação de treino.

O OKAN-031 remove apenas a responsabilidade de persistência da ficha:

- a apresentação não lê mais `workout_plans` para concatenar exercícios;
- a apresentação não grava mais `workout_plans` diretamente;
- a aplicação de fichas adquiridas usa `WorkoutsRepository.appendWorkoutDays()`;
- a implementação Firebase faz a concatenação dentro de transação;
- checkout, `FirebaseFunctions`, templates premium, compras e recomendação permanecem para OKAN-034.

### `evolution_charts_page.dart`

A tela continua temporariamente misturando Assessments + histórico de treino.

O OKAN-031 remove apenas a responsabilidade de histórico de treino:

- lista de exercícios já realizados vem de `WorkoutsRepository.watchWorkoutHistory()`;
- gráfico de progressão de carga usa entidades `WorkoutHistory`/`WorkoutExercise` puras;
- a apresentação não consulta mais a coleção `workout_history` diretamente;
- `users/{studentId}/assessments` e `Timestamp` de avaliações permanecem para OKAN-033.

### Baseline arquitetural

- `discover_workouts_page.dart`: reclassificado de `OKAN-031 / OKAN-034` para somente `OKAN-034`;
- `evolution_charts_page.dart`: reclassificado de `OKAN-031 / OKAN-033` para somente `OKAN-033`.

O teste de Workouts agora bloqueia regressões que reintroduzam `collection('workout_plans')` em Discover ou `collection('workout_history')` em Evolution Charts.

## 9. Validação final

Executado localmente após o Checkpoint C:

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test \
  test/features/workouts/workouts_repository_architecture_test.dart \
  test/architecture/presentation_repository_boundary_test.dart
flutter test
```

Resultado:

- analyzer sem erro fatal;
- 153 issues legadas não bloqueantes;
- gate final Workouts + arquitetura: `+8`, todos passaram;
- suíte Flutter completa: `+48`, todos passaram;
- branch sincronizada com `origin`;
- working tree limpa.

As issues do analyzer permanecem como dívida técnica independente. Dependências e CI não são alterados no OKAN-031.

## 10. Firebase Emulator

O OKAN-031 não muda Security Rules nem schema.

O Emulator não é necessário para validar a separação estrutural. Testes de integração do fluxo completo de Workouts permanecem para a Fase 7.

## 11. Risco para produção

Moderado.

Os principais riscos tratados são:

- compilação/import após realocação física;
- regressão em operações da ficha semanal;
- serialização de exercícios/histórico/templates;
- concatenação de fichas adquiridas;
- notificações e validade.

A persistência permanece nos mesmos caminhos Firebase.

## 12. Rollback

Reverter o merge do OKAN-031.

Não existe rollback de banco porque não há migração de dados.

## 13. Critérios de aceite

- [x] Existe `features/workouts` com `domain`, `data` e `presentation`.
- [x] `WorkoutExercise` está no domínio sem Firebase.
- [x] `WorkoutHistory` está no domínio sem `Timestamp`.
- [x] Existe `WorkoutsRepository` específico do domínio.
- [x] Existe implementação Firebase injetável.
- [x] Create Workout não acessa Firestore diretamente.
- [x] Manage Workouts não acessa Firestore diretamente.
- [x] Train não acessa Firestore diretamente.
- [x] Workout History não acessa Firestore diretamente.
- [x] Weekly Plan não acessa Firestore diretamente.
- [x] Catálogo/templates/feedback/validade/notificações do Weekly Plan passam pelo repository.
- [x] Caminhos antigos migrados permanecem como exports de compatibilidade.
- [x] Gate arquitetural protege as páginas migradas.
- [x] Nenhuma migração de dados é necessária.
- [x] Checkpoint B validado localmente: analyzer sem erro fatal, gate `+7`, suíte `+47`, tree limpa.
- [x] Discover deixa de escrever diretamente em `workout_plans`.
- [x] Evolution Charts deixa de consultar diretamente `workout_history`.
- [x] Baseline de Discover pertence somente ao OKAN-034.
- [x] Baseline de Evolution Charts pertence somente ao OKAN-033.
- [x] Validação final após Checkpoint C: analyzer sem erro fatal, gate `+8`, suíte `+48`, tree limpa.

## 14. Status

**OKAN-031 concluído e apto para merge.**

A separação de Students continua no OKAN-032; Assessments/Anamnese no OKAN-033; Chat/Arena/Store no OKAN-034; CI Flutter no OKAN-035.
