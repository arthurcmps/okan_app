# OKAN-030 — Repository boundaries no Flutter

## Problema

A camada de apresentação conhecia detalhes de infraestrutura Firebase: nomes de coleções, queries, snapshots, batches e chamadas de Functions. Isso aumentava acoplamento, dificultava testes e tornava a futura separação por features mais arriscada.

## Risco atual tratado

- telas e controllers acoplados diretamente ao Firestore;
- regra de leitura e escrita espalhada por widgets/controllers;
- dificuldade para testar apresentação sem Firebase;
- mudanças de schema exigindo alterações em múltiplas telas;
- futura modularização de Workouts, Students, Assessments, Chat, Arena, Store e Tasks ficando dependente da infraestrutura.

## Decisão arquitetural

O Okan passa a usar repositories orientados por domínio.

Não será criado `GenericFirestoreRepository<T>`.

Cada domínio define seu próprio contrato em `domain/repositories` e sua implementação Firebase em `data/repositories`.

A camada de apresentação consome contratos e entidades de domínio. O repository pode receber dependências Firebase por injeção para permitir testes e evolução gradual.

O OKAN-030 estabelece uma fronteira **incremental**: as fatias migradas devem ficar totalmente livres de Firestore/Functions em `presentation`; as dívidas que já existiam na `main` ficam registradas em um baseline nominal e removível. Qualquer novo arquivo com acesso direto fora desse baseline faz o teste arquitetural falhar.

## Fatias migradas

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

### Tasks

`TasksRepository` concentra:

- stream das metas do usuário;
- criação de meta;
- conclusão/reabertura;
- exclusão e restauração;
- edição do título.

`TarefaController` deixa de importar Firestore e passa a depender do contrato de repository. A entidade `Tarefa` também deixa de depender de `Timestamp`; a conversão Firebase fica restrita a `FirebaseTasksRepository`.

O antigo caminho `features/auth/data/models/tarefa_model.dart` permanece como export de compatibilidade para evitar uma mudança de imports ampla antes da separação física da feature Tasks.

## Compatibilidade preservada

- `professorId` continua canônico com fallback temporário para `personalId` na leitura de Students;
- User Schema v2 continua sendo normalizado pelo `UserModel` existente;
- valores legados de Premium continuam aceitando boolean `true` e string `"true"` durante a janela de compatibilidade;
- Tasks continua lendo `dataCriacao` com fallback legado para `data`;
- nenhuma coleção, documento ou schema é migrado nesta tarefa;
- comportamento visual das telas permanece o mesmo.

## Baseline legado de infraestrutura em `presentation`

O teste `presentation_repository_boundary_test.dart` mantém apenas arquivos nominais que já tinham acesso direto ao Firebase antes da conclusão da modularização. Cada entrada aponta para a tarefa responsável por removê-la:

| Arquivo | Destino |
| --- | --- |
| `anamnese_tab.dart` | OKAN-033 |
| `assessments_tab.dart` | OKAN-033 |
| `arena_page.dart` | OKAN-034 |
| `create_workout_page.dart` | OKAN-031 |
| `discover_workouts_page.dart` | OKAN-031 / OKAN-034 |
| `evolution_charts_page.dart` | OKAN-031 / OKAN-033 |
| `home_page.dart` | composição das features da Fase 6 |
| `library_admin_page.dart` | OKAN-034 |
| `manage_workouts_page.dart` | OKAN-031 |
| `personal_data_page.dart` | follow-up Profile/Auth |
| `professor_subscription_page.dart` | follow-up Subscriptions/pagamentos |
| `profile_page.dart` | follow-up Profile/Auth |
| `register_page.dart` | follow-up Auth |
| `student_detail_page.dart` | OKAN-032 |
| `super_admin_page.dart` | OKAN-034 |
| `train_page.dart` | OKAN-031 |
| `weekly_plan_page.dart` | OKAN-031 |
| `workout_history_page.dart` | OKAN-031 |

O baseline não é um bypass genérico. O teste verifica que:

1. qualquer acesso direto novo fora dessa lista falha;
2. cada exceção continua existindo e realmente contém infraestrutura direta;
3. quando uma exceção deixa de usar Firebase diretamente, o próprio teste manda removê-la do baseline;
4. Students, Chat, Notifications e Tasks possuem assertions adicionais exigindo repository boundary e ausência de imports Firestore/Functions.

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

lib/features/tasks/
  data/repositories/firebase_tasks_repository.dart
  domain/entities/task_item.dart
  domain/repositories/tasks_repository.dart
```

Apresentação migrada nesta etapa:

- `students_page.dart`
- `chat_page.dart`
- `notifications_page.dart`
- `tarefa_controller.dart`

## Testes

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test test/features/students/students_repository_test.dart
flutter test test/features/students/students_repository_architecture_test.dart
flutter test test/features/tasks/tasks_repository_architecture_test.dart
flutter test test/architecture/presentation_repository_boundary_test.dart
flutter test
```

O projeto possui dívida técnica legada de lint/depreciações. O gate do OKAN-030 é ausência de erro real de análise/compilação, sucesso dos testes e ausência de novas violações arquiteturais. A limpeza global do analyzer entra na etapa de qualidade/CI.

## Evidências de validação

### Primeira rodada

- testes focados: `+7 -1`;
- suíte completa: `+40 -1`;
- única falha: o gate encontrou Firestore direto no `TarefaController` legado;
- correção: Tasks foi migrado para repository em vez de entrar na allowlist.

### Segunda rodada

- `flutter analyze --no-fatal-infos --no-fatal-warnings` executou sem erro fatal;
- diagnóstico caiu de 179 para 174 issues legadas;
- testes focados chegaram a `+9 -1`;
- única falha: o gate encontrou `anamnese_tab.dart`, uma dependência já existente e pertencente ao OKAN-033;
- a suíte completa não foi executada porque o script interrompe corretamente após a falha dos testes focados;
- correção: o teste passou a usar baseline incremental explícito e a acumular todas as violações inesperadas antes de falhar.

### Terceira rodada

- working tree limpo e branch sincronizada;
- o gate arquitetural executou e encontrou apenas `train_page.dart` fora do baseline;
- `train_page.dart` já existia na `main` com leitura/escrita direta em `workout_plans` e `workout_history`;
- a suíte focada e a suíte completa não executaram porque o script interrompe corretamente quando o gate falha;
- correção: `train_page.dart` foi adicionado nominalmente ao baseline do OKAN-031.

## Firebase Emulator

O OKAN-030 não modifica Security Rules nem schema. Os repositories mantêm os mesmos caminhos e contratos já protegidos pelas Rules existentes.

Testes de integração com Emulator podem ser adicionados na Fase 7 sem bloquear a criação da fronteira arquitetural desta tarefa.

## Risco para produção

Moderado-baixo.

O maior risco é regressão de compilação ou integração Flutter, pois a mudança altera dependências da apresentação sem mudar dados persistidos.

Por isso a suíte Flutter e os gates arquiteturais são obrigatórios antes do merge.

## Rollback

Reverter o merge do OKAN-030.

Não existe rollback de banco, Functions ou migração de dados.

## Critério de aceite

- [x] Existe contrato de repository por domínio, sem repository genérico de Firestore.
- [x] Implementações Firebase aceitam dependências injetáveis.
- [x] Students não acessa Firestore diretamente na apresentação.
- [x] Chat não acessa Firestore diretamente na apresentação.
- [x] Notifications não acessa Firestore diretamente na apresentação.
- [x] Tasks não acessa Firestore diretamente na apresentação.
- [x] Novos acessos diretos de Firestore/Functions em `presentation` são bloqueados por teste arquitetural incremental.
- [x] Dívida legada permanece nominal, documentada e removível por tarefa futura.
- [x] Nenhuma migração de dados é necessária.
- [x] Analyzer não apresenta erro fatal com infos/warnings legados não bloqueantes.
- [ ] Gates focados do OKAN-030 passam com o baseline completo.
- [ ] Suíte completa `flutter test` passa com o baseline completo.
