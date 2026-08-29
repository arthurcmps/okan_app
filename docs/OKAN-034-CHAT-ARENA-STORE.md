# OKAN-034 — Separar Chat, Arena e Store no Flutter

## 1. Problema

A Fase 6 ainda mantinha Chat, Arena e Store dentro de `features/auth/presentation`, com responsabilidades de domínio misturadas à autenticação e, no caso de Arena/Store, acesso direto a Firebase/Functions na UI.

O baseline arquitetural ainda continha exceções para:

- `arena_page.dart`;
- `discover_workouts_page.dart`;
- `library_admin_page.dart`;
- `super_admin_page.dart`.

Chat já possuía repository, mas sua tela ainda estava fisicamente em Auth e lia `FirebaseAuth` diretamente.

## 2. Risco atual tratado

- Arena concentrava amizades, duelos, ranking, mural, comentários, reações, notificações e Storage em uma única tela;
- Store conhecia Firestore, Cloud Functions, nomes de Functions e tokenização do Mercado Pago diretamente na apresentação;
- telas administrativas manipulavam `exercises` e `workout_templates` diretamente;
- Chat dependia de autenticação concreta na apresentação;
- mudanças de UI poderiam alterar inadvertidamente paths ou contratos sensíveis.

## 3. Comportamento preservado

### Chat

- chat ID determinístico;
- mensagens em `chats/{chatId}/messages`;
- metadados em `chats/{chatId}`;
- notificação de nova mensagem;
- foto/nome do interlocutor.

### Arena

- busca de atleta usando identidade User v2 canônica;
- amizades e convites em `friendships`;
- duelos em `challenges`;
- convite, aceite, recusa e saída de duelo;
- métricas `weight`, `bodyFatPercentage`, `constancy` e `volume`;
- ranking usando `users` e `workout_history`;
- mural em `challenges/{challengeId}/posts`;
- comentários, reações e contador de comentários;
- notificações da Arena;
- upload e limpeza das imagens de duelo via `StorageService`;
- remoção das imagens após o encerramento do duelo.

### Store

- catálogo premium em `workout_templates`;
- `purchased_templates` no usuário;
- matching por tags do perfil;
- aquisição gratuita;
- checkout PIX;
- checkout cartão;
- Functions existentes `adquirirTemplateGratuito`, `criarPagamentoPix`, `criarPagamentoCartao`;
- `productId = workout_template:{templateId}`;
- tokenização de cartão usando a chave pública existente do Mercado Pago;
- biblioteca de exercícios em `exercises`;
- templates pessoais e oficiais em `workout_templates`;
- templates oficiais `personalId=SYSTEM_ADMIN`;
- múltiplas fichas oficiais e cópia retrocompatível da Ficha A em `exercicios`;
- aplicação do treino comprado à semana via `WorkoutsRepository.appendWorkoutDays`.

## 4. Novo comportamento arquitetural

```text
lib/features/chat/
  data/repositories/firebase_chat_repository.dart
  domain/repositories/chat_repository.dart
  presentation/pages/chat_page.dart

lib/features/arena/
  data/repositories/firebase_arena_repository.dart
  domain/entities/arena_models.dart
  domain/repositories/arena_repository.dart
  presentation/pages/arena_page.dart
  presentation/pages/duel_room_page.dart

lib/features/store/
  data/repositories/firebase_store_repository.dart
  domain/entities/store_models.dart
  domain/repositories/store_repository.dart
  presentation/pages/discover_workouts_page.dart
  presentation/pages/library_admin_page.dart
  presentation/pages/super_admin_page.dart
  presentation/widgets/template_checkout_sheet.dart
```

A apresentação migrada não conhece `FirebaseFirestore`, `FirebaseFunctions` nem `firebase_auth`.

## 5. Fronteiras

### ChatRepository

Também passa a fornecer a identidade do usuário atual, retirando `FirebaseAuth` de `ChatPage`.

### ArenaRepository

Concentra:

- identidade atual;
- perfis necessários pela Arena;
- friendships;
- challenges;
- ranking;
- notifications;
- posts/comments/reactions;
- Storage da Arena.

### StoreRepository

Concentra:

- usuário/biblioteca/tags;
- catálogo premium;
- aquisição gratuita;
- PIX/cartão e tokenização;
- exercises;
- templates pessoais;
- templates oficiais.

`WorkoutsRepository` continua sendo a fronteira correta para aplicar um template comprado ao plano semanal.

## 6. Migração de dados

Não.

Nenhum documento, coleção ou campo existente precisa ser convertido.

## 7. Segurança e backend

Não há alteração em:

- Firestore Rules;
- Storage Rules;
- Cloud Functions do backend;
- schema de dados;
- dependências Flutter.

As Functions existentes continuam sendo a autoridade para aquisição/pagamento.

## 8. Compatibilidade

Os caminhos antigos em `features/auth/presentation/pages` permanecem como exports:

- `arena_page.dart`;
- `chat_page.dart`;
- `discover_workouts_page.dart`;
- `library_admin_page.dart`;
- `super_admin_page.dart`.

Isso preserva imports e navegação existentes durante a modularização.

## 9. Integridade adicional

Sem alterar os contratos persistidos:

- comentário + incremento de `commentsCount` passam pelo mesmo Firestore batch;
- reação continua transacional;
- identidade User v2 continua usada na busca de atletas;
- gates cruzados de Workouts acompanham a nova localização da Store.

## 10. Testes locais obrigatórios

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings

flutter test \
  test/features/chat/chat_repository_architecture_test.dart \
  test/features/arena/arena_repository_architecture_test.dart \
  test/features/store/store_repository_architecture_test.dart \
  test/features/workouts/workouts_repository_architecture_test.dart \
  test/architecture/presentation_repository_boundary_test.dart

flutter test
```

## 11. Firebase Emulator

Não é obrigatório para este ticket porque Rules, Functions e schema não foram alterados.

## 12. Risco para produção

Moderado, concentrado no frontend e nos data mappings de funcionalidades existentes:

- abertura/envio do Chat;
- amizades e duelos da Arena;
- ranking e mural da Arena;
- Store/biblioteca;
- checkout existente;
- administração de exercícios/templates;
- exports de compatibilidade.

O risco é mitigado por repository boundaries, gates arquiteturais e suíte Flutter completa.

## 13. Rollback

Reverter o merge do OKAN-034.

Não há rollback de banco porque não existe migração.

## 14. Critérios de aceite

- [x] Chat presentation movida para `features/chat`;
- [x] Chat presentation não usa Firebase/Auth diretamente;
- [x] Arena domain/data/presentation criada;
- [x] Arena presentation usa `ArenaRepository`;
- [x] Storage da Arena está atrás do repository;
- [x] Store domain/data/presentation criada;
- [x] Store presentation usa `StoreRepository`;
- [x] pagamento e tokenização não ficam na UI;
- [x] administração de exercises/templates passa por repository;
- [x] Store preserva `WorkoutsRepository` para aplicar o treino;
- [x] paths antigos são exports de compatibilidade;
- [x] exceções OKAN-034 foram removidas do baseline global;
- [x] gates específicos Chat/Arena/Store adicionados;
- [x] gate cruzado Workouts aponta para a nova Store;
- [x] nenhuma migração de dados;
- [x] nenhuma mudança de Rules/Functions/schema/dependências;
- [ ] analyzer final sem erro fatal;
- [ ] gates OKAN-034 verdes;
- [ ] suíte Flutter completa verde;
- [ ] working tree local limpa e sincronizada.

## 15. Próximo ticket

Após a conclusão do OKAN-034, a Fase 6 planejada termina e inicia a Fase 7 com:

- OKAN-035 — CI Flutter.

## 16. Status

Implementação arquitetural concluída na branch `refactor/frontend-okan-034-chat-arena-store`.

Pendente validação local final antes do merge.
