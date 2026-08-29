# OKAN-030 — Repository boundaries no Flutter

## Problema

A camada de apresentação conhecia detalhes de infraestrutura Firebase: nomes de coleções, queries, snapshots, batches e chamadas de Functions. Isso aumentava acoplamento, dificultava testes e tornava a futura separação por features mais arriscada.

## Risco atual tratado

- telas acopladas diretamente ao Firestore;
- regra de leitura e escrita espalhada por widgets;
- dificuldade para testar apresentação sem Firebase;
- mudanças de schema exigindo alterações em múltiplas telas;
- futura modularização de Workouts, Students, Assessments, Chat, Arena e Store ficando dependente da infraestrutura.

## Decisão arquitetural

O Okan passa a usar repositories orientados por domínio.

Não será criado `GenericFirestoreRepository<T>`.

Cada domínio define seu próprio contrato em `domain/repositories` e sua implementação Firebase em `data/repositories`.

A camada de apresentação consome contratos e entidades de domínio. O repository pode receber dependências Firebase por injeção para permitir testes e evolução gradual.

## Primeiras fatias migradas

### Students

`StudentsRepository` concentra:

- status Premium do professor;
- alunos ativos;
- busca de aluno canônico por e-mail;
- convites pendentes;
- criação/cancelamento de convite;
- desvinculação.

As mutações privilegiadas continuam delegadas ao backend canônico por `ProfessionalRelationshipsService`.

### Chat

`ChatRepository` concentra:

- nome e foto de usuários;
- stream de mensagens;
- persistência da mensagem;
- atualização de metadados do chat;
- criação da notificação de nova mensagem.

A identidade determinística do chat permanece no domínio existente.

### Notifications

`NotificationsRepository` concentra:

- convites pendentes;
- notificações recentes;
- leitura, exclusão e marcação em lote;
- carregamento de perfis necessários à navegação;
- resposta a convite via backend canônico.

## Compatibilidade preservada

- `professorId` continua canônico com fallback temporário para `personalId` na leitura de Students;
- User Schema v2 continua sendo normalizado pelo `UserModel` existente;
- valores legados de Premium continuam aceitando boolean `true` e string `"true"` durante a janela de compatibilidade;
- nenhuma coleção, documento ou schema é migrado nesta tarefa;
- comportamento visual das telas permanece o mesmo.

## Exceção legada explícita

`professor_subscription_page.dart` ainda contém acesso direto a Firestore/Functions porque reúne assinatura, tokenização de cartão e checkout em uma única tela grande.

Ela permanece em allowlist explícita no teste arquitetural para não transformar o OKAN-030 em uma refatoração de pagamentos. A exceção deve ser removida quando `subscriptions` for separada como feature própria.

A allowlist não permite novos acessos diretos em outras telas.

## Arquivos principais

```text
lib/features/students/
  data/repositories/firebase_students_repository.dart
  domain/entities/
  domain/repositories/students_repository.dart

lib/features/chat/
  data/repositories/firebase_chat_repository.dart
  domain/entities/chat_message.dart
  domain/repositories/chat_repository.dart

lib/features/notifications/
  data/repositories/firebase_notifications_repository.dart
  domain/entities/notification_models.dart
  domain/repositories/notifications_repository.dart
```

Telas migradas nesta etapa:

- `students_page.dart`
- `chat_page.dart`
- `notifications_page.dart`

## Testes

```bash
flutter analyze
flutter test
flutter test test/features/students/students_repository_test.dart
flutter test test/features/students/students_repository_architecture_test.dart
flutter test test/architecture/presentation_repository_boundary_test.dart
```

## Firebase Emulator

O OKAN-030 não modifica Security Rules nem schema. Os repositories mantêm os mesmos caminhos e contratos já protegidos pelas Rules existentes.

Testes de integração com Emulator podem ser adicionados na Fase 7 sem bloquear a criação da fronteira arquitetural desta tarefa.

## Risco para produção

Moderado-baixo.

O maior risco é regressão de compilação ou de integração do Flutter, pois a mudança altera dependências das telas sem mudar dados persistidos.

Por isso `flutter analyze` e `flutter test` são gate obrigatório antes do merge.

## Rollback

Reverter o merge do OKAN-030.

Não existe rollback de banco, Functions ou migração de dados.

## Critério de aceite

- [x] Existe contrato de repository por domínio, sem repository genérico de Firestore.
- [x] Implementações Firebase aceitam dependências injetáveis.
- [x] Students não acessa Firestore diretamente na apresentação.
- [x] Chat não acessa Firestore diretamente na apresentação.
- [x] Notifications não acessa Firestore diretamente na apresentação.
- [x] Novos acessos diretos de Firestore/Functions em presentation são bloqueados por teste arquitetural.
- [x] Dívida de Subscriptions permanece explícita e isolada em allowlist.
- [x] Nenhuma migração de dados é necessária.
- [ ] `flutter analyze` passa.
- [ ] `flutter test` passa.
