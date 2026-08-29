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
- `workout_templates` para templates do profissional;
- subcoleção `users/{uid}/notifications` para avisos de treino;
- `personalId`, `criadoEm` e `atualizadoEm` nos modelos;
- compatibilidade de `professorId` via `UserModel` v2;
- feedback do treino;
- solicitação de alteração de exercício;
- validade e aviso de vencimento;
- reset de `concluido` após finalizar um treino;
- catálogo, templates, vídeos e timer de descanso;
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
- a saída enviada da suíte completa termina durante a resolução de dependências e não contém resultado final; portanto ela não é contabilizada como aprovada.

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

## 8. Testes

Checkpoint B:

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test \
  test/features/workouts/workouts_repository_architecture_test.dart \
  test/architecture/presentation_repository_boundary_test.dart
flutter test
```

A suíte completa continua obrigatória porque existem exports de compatibilidade e a nova página semanal possui grande superfície de UI/integração.

## 9. Firebase Emulator

O OKAN-031 não muda Security Rules nem schema.

O Emulator não é necessário para validar a separação estrutural, mas pode ser usado na Fase 7 para testes de integração do fluxo completo de Workouts.

## 10. Risco para produção

Moderado.

Os principais riscos são:

- compilação/import após realocação física;
- regressão em operações da ficha semanal;
- serialização de exercícios/histórico/templates;
- notificações e validade.

A persistência permanece nos mesmos caminhos Firebase.

## 11. Rollback

Reverter o merge do OKAN-031.

Não existe rollback de banco porque não há migração de dados.

## 12. Critérios de aceite

### Concluídos

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

### Pendentes para concluir OKAN-031

- [ ] Validar localmente o checkpoint B.
- [ ] A parte de Workouts de `discover_workouts_page.dart` deixa de escrever diretamente em `workout_plans`, sem absorver Store/Payments.
- [ ] A parte de histórico de `evolution_charts_page.dart` usa boundary de Workouts; Assessments permanece para OKAN-033.
- [ ] Baseline de `discover_workouts_page.dart` passa a pertencer somente ao OKAN-034.
- [ ] Baseline de `evolution_charts_page.dart` passa a pertencer somente ao OKAN-033.
- [ ] Suíte completa passa após a conclusão.

## 13. Documentação

Este arquivo é atualizado a cada checkpoint do OKAN-031. O ticket só será concluído quando os critérios finais estiverem verdes.
