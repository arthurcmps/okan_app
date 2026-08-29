# OKAN-031 — Separar Workouts no Flutter

## 1. Problema

A feature de treinos ainda está fisicamente misturada dentro de `features/auth` e várias telas conhecem diretamente coleções, snapshots, `Timestamp` e `FieldValue` do Firestore.

Isso impede que Workouts tenha uma fronteira de domínio própria e faz mudanças no schema ou no fluxo de execução atingirem apresentação e persistência ao mesmo tempo.

## 2. Risco atual

- `create_workout_page.dart`, `manage_workouts_page.dart`, `train_page.dart`, `weekly_plan_page.dart`, `workout_history_page.dart` e partes de outras telas acessam Firebase diretamente;
- `WorkoutHistory` dependia de `Timestamp`;
- modelos de treino permaneciam dentro da feature Auth;
- CRUD, execução e histórico duplicavam conhecimento dos caminhos Firestore;
- a separação posterior de Students, Assessments e Store ficava acoplada a Workouts.

## 3. Comportamento preservado

Esta melhoria não altera schema nem nomes de coleções.

Permanecem:

- `workouts` para modelos de treino;
- `exercises` para catálogo de exercícios;
- `workout_plans/{studentId}` para ficha semanal;
- `workout_history` para histórico;
- `personalId`, `criadoEm` e `atualizadoEm` nos modelos;
- feedback do treino no histórico;
- reset de `concluido` após finalizar um treino;
- UI e rotas existentes por meio de exports de compatibilidade.

## 4. Novo comportamento arquitetural

Workouts passa a possuir:

```text
lib/features/workouts/
  data/repositories/firebase_workouts_repository.dart
  domain/entities/workout_exercise.dart
  domain/entities/workout_history.dart
  domain/entities/workout_model.dart
  domain/repositories/workouts_repository.dart
  presentation/pages/
```

`WorkoutsRepository` é orientado ao domínio e concentra operações de modelos, catálogo, execução e histórico. Não existe repository genérico de Firestore.

`FirebaseWorkoutsRepository` recebe `FirebaseFirestore` opcional por injeção.

## 5. Migração de dados

Não.

Não há escrita de script de migração, mudança de coleção ou mudança de documento neste ticket.

## 6. Arquivos alterados — checkpoint A

### Novos

- `lib/features/workouts/domain/entities/workout_exercise.dart`
- `lib/features/workouts/domain/entities/workout_history.dart`
- `lib/features/workouts/domain/entities/workout_model.dart`
- `lib/features/workouts/domain/repositories/workouts_repository.dart`
- `lib/features/workouts/data/repositories/firebase_workouts_repository.dart`
- `lib/features/workouts/presentation/pages/create_workout_page.dart`
- `lib/features/workouts/presentation/pages/manage_workouts_page.dart`
- `lib/features/workouts/presentation/pages/train_page.dart`
- `lib/features/workouts/presentation/pages/workout_history_page.dart`
- `test/features/workouts/workouts_repository_architecture_test.dart`

### Compatibilidade

Os caminhos antigos abaixo permanecem como `export` para não quebrar imports e rotas durante a separação gradual:

- `features/auth/data/models/workout_plans_model.dart`
- `features/auth/data/models/workout_history_model.dart`
- `features/auth/presentation/pages/create_workout_page.dart`
- `features/auth/presentation/pages/manage_workouts_page.dart`
- `features/auth/presentation/pages/train_page.dart`
- `features/auth/presentation/pages/workout_history_page.dart`

## 7. Validação local

Checkpoint A:

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test test/features/workouts/workouts_repository_architecture_test.dart
flutter test test/architecture/presentation_repository_boundary_test.dart
flutter test
```

A suíte completa é obrigatória porque os exports de compatibilidade podem afetar imports que não aparecem no teste focado.

## 8. Firebase Emulator

Este checkpoint não muda Security Rules nem schema. Emulator não é obrigatório para a separação estrutural, mas poderá ser usado quando o fluxo semanal completo for migrado.

## 9. Risco para produção

Moderado.

O risco principal é de compilação/import durante a realocação física, seguido por regressão na serialização dos exercícios e histórico.

A persistência continua centralizada nos mesmos caminhos Firebase.

## 10. Rollback

Reverter o merge do OKAN-031.

Não existe rollback de banco porque não há migração de dados.

## 11. Critérios de aceite

### Checkpoint A

- [x] Existe `features/workouts` com camadas `domain`, `data` e `presentation`.
- [x] `WorkoutExercise` está no domínio sem Firebase.
- [x] `WorkoutHistory` está no domínio sem `Timestamp`.
- [x] Existe `WorkoutsRepository` específico do domínio.
- [x] Existe implementação Firebase injetável.
- [x] Create Workout não acessa Firestore diretamente.
- [x] Manage Workouts não acessa Firestore diretamente.
- [x] Train não acessa Firestore diretamente.
- [x] Workout History não acessa Firestore diretamente.
- [x] Caminhos antigos permanecem como exports de compatibilidade.
- [ ] Testes focados passam localmente.
- [ ] Suíte Flutter completa passa localmente.

### Conclusão do OKAN-031

- [ ] `weekly_plan_page.dart` sai do Firestore direto e entra em Workouts.
- [ ] Operações de catálogo/template usadas pelo Weekly Plan entram no repository boundary adequado.
- [ ] A parte de Workouts de `discover_workouts_page.dart` deixa de acessar Firestore/Functions de treino diretamente sem absorver o escopo de Store/Payments.
- [ ] A parte de histórico de `evolution_charts_page.dart` usa boundary de Workouts; Assessments permanece para OKAN-033.
- [ ] Entradas correspondentes do baseline arquitetural são removidas.
- [ ] Suíte completa passa após a conclusão.

## 12. Documentação

Este arquivo é atualizado a cada checkpoint do OKAN-031. O ticket só poderá ser marcado como concluído quando o bloco final de critérios estiver integralmente verde.
