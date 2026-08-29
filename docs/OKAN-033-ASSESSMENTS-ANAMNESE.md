# OKAN-033 — Separar Assessments/Anamnese no Flutter

## 1. Problema

Anamnese, avaliações físicas, gráfico de evolução corporal e notas privadas do profissional ainda conheciam diretamente Firebase na camada de apresentação.

Os principais acessos estavam espalhados entre:

- `auth/presentation/pages/anamnese_tab.dart`;
- `auth/presentation/pages/assessments_tab.dart`;
- `auth/presentation/pages/evolution_charts_page.dart`;
- `core/widgets/professor_notes_widget.dart`.

## 2. Risco atual tratado

- dados médicos lidos/escritos diretamente pela UI;
- avaliações físicas acopladas a `QuerySnapshot`, `Timestamp` e `FieldValue`;
- gráfico corporal lendo Firestore diretamente;
- nota privada do profissional contendo autenticação, autorização e persistência dentro do widget;
- paths sensíveis distribuídos em vários componentes de apresentação.

## 3. Comportamento preservado

O ticket preserva:

- `users/{studentId}/medical/anamnese`;
- `users/{studentId}/assessments`;
- `users/{studentId}/private_notes/{professionalId}`;
- campos e opções atuais da ficha de anamnese;
- formulário completo de avaliação física;
- cálculo e armazenamento de IMC;
- atualização de `peso`, `altura`, `bodyFatPercentage` e `imc` no documento do aluno;
- gráfico de medidas corporais;
- gráfico de força/cargas via WorkoutsRepository;
- visibilidade da nota privada somente para o profissional vinculado;
- imports antigos através de exports de compatibilidade.

## 4. Novo comportamento arquitetural

A feature passa a ser:

```text
lib/features/assessments/
  data/repositories/firebase_assessments_repository.dart
  domain/entities/
    anamnese_record.dart
    physical_assessment.dart
    professor_note_state.dart
  domain/repositories/assessments_repository.dart
  presentation/pages/
    anamnese_tab.dart
    assessments_tab.dart
    evolution_charts_page.dart
  presentation/widgets/
    professor_notes_widget.dart
```

A apresentação não conhece `FirebaseFirestore`, `FirebaseAuth`, `DocumentSnapshot`, `Timestamp` ou `FieldValue`.

`EvolutionChartsPage` combina duas fronteiras explícitas:

- `AssessmentsRepository` para medidas corporais;
- `WorkoutsRepository` para evolução de cargas.

## 5. Integridade da gravação

A criação da avaliação física e a atualização do resumo físico do aluno passam a usar o mesmo Firestore batch.

Os mesmos documentos e campos são escritos, mas não há mais risco de criar a avaliação e falhar antes de atualizar o resumo do usuário, ou vice-versa.

## 6. Migração de dados

Não.

Nenhum documento existente precisa ser convertido.

## 7. Segurança

Não há mudança em Firestore Rules ou Functions.

As regras e autorizações blindadas nas fases anteriores continuam sendo a autoridade final.

A nota privada mantém também a checagem client-side do vínculo professor/aluno antes de ser exibida ou salva.

## 8. Arquivos de compatibilidade

Os caminhos antigos passam a exportar a nova implementação:

- `lib/features/auth/presentation/pages/anamnese_tab.dart`;
- `lib/features/auth/presentation/pages/assessments_tab.dart`;
- `lib/features/auth/presentation/pages/evolution_charts_page.dart`;
- `lib/core/widgets/professor_notes_widget.dart`.

## 9. Testes locais obrigatórios

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test \
  test/features/assessments/assessments_repository_test.dart \
  test/features/assessments/assessments_repository_architecture_test.dart \
  test/architecture/presentation_repository_boundary_test.dart
flutter test
```

Validação final executada em 2026-08-29:

- analyzer: sem erro fatal; 145 issues legadas não bloqueantes;
- gate Assessments + arquitetura: 11/11;
- gate Workouts afetado pela mudança física de `EvolutionChartsPage`: 5/5 após atualização do caminho arquitetural;
- suíte Flutter completa: 58/58;
- branch sincronizada com `origin/refactor/frontend-okan-033-assessments`;
- working tree limpa.

## 10. Firebase Emulator

Não é obrigatório para este ticket porque não há alteração de Rules, Functions ou schema.

## 11. Risco para produção

Moderado e concentrado em frontend/data mapping:

- carregamento e salvamento da anamnese;
- criação/listagem de avaliações;
- atualização do resumo físico;
- gráfico de medidas;
- nota privada do profissional;
- imports de compatibilidade.

## 12. Rollback

Reverter o merge do OKAN-033.

Não existe rollback de banco porque não há migração.

## 13. Critérios de aceite

- [x] feature `assessments` criada;
- [x] domínio de Assessments livre de Firebase;
- [x] Anamnese usa `AssessmentsRepository`;
- [x] Assessments usa `AssessmentsRepository`;
- [x] Evolution usa `AssessmentsRepository` para medidas e `WorkoutsRepository` para cargas;
- [x] Professor Notes usa `AssessmentsRepository`;
- [x] `Timestamp` é convertido para `DateTime` na camada data;
- [x] avaliação + resumo físico são gravados atomicamente;
- [x] paths persistidos foram preservados;
- [x] paths antigos são exports de compatibilidade;
- [x] exceções OKAN-033 saíram do baseline global;
- [x] nenhuma migração de dados é necessária;
- [x] analyzer final sem erro fatal;
- [x] gate Assessments + arquitetura verde;
- [x] suíte Flutter completa verde;
- [x] working tree local limpa e sincronizada.

## 14. Próximos tickets preservados

- OKAN-034: Chat/Arena/Store;
- OKAN-035: CI Flutter.

## 15. Status

OKAN-033 concluído e pronto para merge.
