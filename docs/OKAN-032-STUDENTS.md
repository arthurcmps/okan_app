# OKAN-032 — Separar Students no Flutter

## 1. Problema

A fronteira de Students já possuía entidades e repository desde o OKAN-030, mas as telas principais continuavam fisicamente em `features/auth`.

`StudentDetailPage` ainda conhecia diretamente `FirebaseFirestore`, `DocumentSnapshot`, `Timestamp` e `FieldValue`, inclusive para carregar o cabeçalho do aluno e desvincular o relacionamento professor/aluno.

## 2. Risco atual tratado

- apresentação de Students fisicamente misturada em Auth;
- detalhe do aluno lendo `users/{studentId}` diretamente;
- detalhe do aluno alterando vínculo diretamente no documento do usuário;
- conversão de `Timestamp` ocorrendo na UI;
- desvínculo do detalhe ignorando a fronteira canônica de relacionamentos criada na Fase 5;
- telas de Students conhecendo helpers de erro da camada `auth/data`.

## 3. Comportamento preservado

O ticket não altera schema, nomes de coleções, Security Rules ou Functions.

Permanecem:

- lista de alunos ativos;
- lista de convites pendentes;
- busca de aluno canônico por e-mail;
- envio e cancelamento de convite;
- desvínculo de aluno via backend canônico;
- limitação visual do Plano Base;
- foto, idade e gênero no cabeçalho do aluno;
- acesso a Chat;
- acesso a Weekly Plan e Workout History;
- abas Anamnese e Avaliações;
- imports antigos em `features/auth` por exports de compatibilidade.

## 4. Novo comportamento arquitetural

Students passa a possuir apresentação própria:

```text
lib/features/students/
  data/repositories/firebase_students_repository.dart
  domain/entities/
    pending_student_invite.dart
    student_invite_creation_result.dart
    student_profile.dart
    student_relationship_exception.dart
    student_summary.dart
  domain/repositories/students_repository.dart
  presentation/pages/
    students_page.dart
    student_detail_page.dart
```

`StudentDetailPage` não acessa mais Firestore diretamente.

O cabeçalho usa `StudentsRepository.watchStudentProfile()` e recebe `StudentProfile` com `DateTime?`, sem `Timestamp` no domínio ou apresentação.

O desvínculo usa `StudentsRepository.unlinkStudent()`, que continua delegando ao backend canônico através de `ProfessionalRelationshipsService` na camada data.

Erros de relacionamento são convertidos em `StudentRelationshipException` antes de chegar à apresentação, evitando dependência da UI em `auth/data/services`.

## 5. Migração de dados

Não.

Nenhum documento existente precisa ser alterado.

## 6. Arquivos principais alterados

- `lib/features/students/domain/entities/student_profile.dart`;
- `lib/features/students/domain/entities/student_relationship_exception.dart`;
- `lib/features/students/domain/repositories/students_repository.dart`;
- `lib/features/students/data/repositories/firebase_students_repository.dart`;
- `lib/features/students/presentation/pages/students_page.dart`;
- `lib/features/students/presentation/pages/student_detail_page.dart`;
- exports de compatibilidade em `features/auth/presentation/pages`;
- gates arquiteturais de Students e apresentação global.

## 7. Testes locais obrigatórios

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test \
  test/features/students/students_repository_test.dart \
  test/features/students/students_repository_architecture_test.dart \
  test/architecture/presentation_repository_boundary_test.dart
flutter test
```

## 8. Firebase Emulator

Não é obrigatório para este ticket.

O OKAN-032 não altera Rules, schema nem Functions. Os fluxos de convite/desvínculo continuam usando o backend canônico já blindado e validado na Fase 5.

## 9. Risco para produção

Moderado e concentrado em apresentação:

- imports após a mudança física;
- renderização do cabeçalho do aluno;
- navegação para detalhe, Chat, Workouts, Anamnese e Assessments;
- mensagens de erro de convite/desvínculo;
- compatibilidade dos imports antigos.

## 10. Rollback

Reverter o merge do OKAN-032.

Não existe rollback de banco porque não há migração de dados.

## 11. Critérios de aceite

- [x] `StudentsPage` está em `features/students/presentation/pages`.
- [x] `StudentDetailPage` está em `features/students/presentation/pages`.
- [x] caminhos antigos em Auth são exports de compatibilidade.
- [x] `StudentDetailPage` não importa `cloud_firestore`.
- [x] `StudentDetailPage` não usa `FirebaseFirestore`, `DocumentSnapshot`, `Timestamp` ou `FieldValue`.
- [x] cabeçalho do aluno passa por `StudentsRepository.watchStudentProfile()`.
- [x] conversão de data do perfil fica na camada data.
- [x] desvínculo do detalhe passa por `StudentsRepository.unlinkStudent()`.
- [x] erros de relacionamento chegam à UI como domínio de Students.
- [x] `student_detail_page.dart` sai do baseline legado do gate global.
- [x] nenhuma migração de dados é necessária.
- [ ] analyzer final sem erro fatal.
- [ ] gate de Students + arquitetura verde.
- [ ] suíte Flutter completa verde.
- [ ] working tree local limpa e sincronizada.

## 12. Próximas fronteiras preservadas

`StudentDetailPage` continua compondo telas que pertencem a tickets seguintes:

- Anamnese e Assessments: OKAN-033;
- Chat: OKAN-034;
- Workouts: já separado no OKAN-031.

Essas dependências de composição não reabrem o escopo de Students.

## 13. Status

Implementação arquitetural concluída na branch `refactor/frontend-okan-032-students`.

Pendente apenas validação local final antes de marcar o PR como pronto para merge.
