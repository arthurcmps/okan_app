# Modelo de Dados do Okan

**Criticidade:** alta — contrato compartilhado por `okan_app`, `okan_web` e `okan_backend`  
**Revisado em:** 1º de setembro de 2026  
**Fonte de verdade executável:** `okan_backend/firestore.rules`, Functions e testes

## 1. Como ler este documento

- **Obrigatório** significa necessário para um documento novo daquele fluxo; documentos legados podem não possuir o campo.
- **Cliente** indica escrita permitida pelas Rules dentro do domínio.
- **Backend** indica escrita exclusiva via Admin SDK/Function.
- Campos `Timestamp` devem usar horário do servidor quando representam evento persistido.
- IDs de usuário são UIDs do Firebase Auth, salvo indicação contrária.
- O fallback global das Firestore Rules nega qualquer caminho não documentado.

## 2. Mapa de collections

| Collection/path | Estado | Dono lógico | Escrita |
| --- | --- | --- | --- |
| `users/{uid}` | Ativo, User v2 + legado | usuário | cliente limitada / backend privilegiado |
| `users/{uid}/client_state/current` | Ativo | usuário | próprio usuário |
| `users/{uid}/notifications/{id}` | Ativo | usuário destinatário | clientes autenticados; dívida |
| `users/{uid}/medical/anamnese` | Ativo, sensível | aluno | próprio aluno |
| `users/{uid}/assessments/{id}` | Ativo, sensível | aluno | aluno ou professor vinculado |
| `users/{uid}/private_notes/{professorId}` | Ativo, sensível | professor autor | professor vinculado |
| `users/{uid}/entitlements/{id}` | Ativo | usuário beneficiário | backend |
| `invites/{id}` | Ativo | relação professor–aluno | backend |
| `workout_plans/{studentId}` | Ativo | aluno | aluno/professor vinculado |
| `workout_history/{id}` | Ativo | aluno | aluno/professor vinculado |
| `workouts/{id}` | Ativo | professor | professor proprietário |
| `workout_templates/{id}` | Ativo, compatível | professor/plataforma | proprietário ou super admin |
| `exercises/{id}` | Ativo, global | plataforma | super admin |
| `chats/{chatId}/messages/{id}` | Ativo | participantes | participantes |
| `friendships/{id}` | Ativo | dois usuários | participantes conforme estado |
| `challenges/{id}/posts/{id}/comments/{id}` | Ativo | participantes do duelo | participantes conforme regra |
| `tarefas/{id}` | Ativo | usuário | proprietário |
| `academias/{id}/professores/{licenseId}` | Ativo | academia | backend para licenças |
| `beta_feedback/{id}` | Ativo | autor/Okan | autor cria; super admin administra |
| `payments/{providerPaymentId}` | Ativo, financeiro | plataforma | backend |
| `payment_fulfillments/{providerPaymentId}` | Ativo, idempotência | plataforma | backend |
| `subscriptions/{uid}` | Ativo | assinante | backend |
| `webhook_events/{notificationId}` | Ativo, idempotência | plataforma | backend |
| `academy_subscription_attempts/{attemptId}` | Ativo, B2B | academia | backend |
| `academy_subscriptions/{academyId}` | Ativo, B2B | academia | backend |
| `system_metrics/user_v2_compatibility` | Ativo, agregado | plataforma | backend |

## 3. Identidade — `users/{uid}`

O ID do documento é a fonte de verdade. Um campo `uid` divergente nunca deve substituir `document.id`.

| Campo | Tipo | Obrigatório novo v2 | Autoridade | Observação |
| --- | --- | --- | --- | --- |
| `schemaVersion` | int | sim | criação/Backend | valor atual `2` |
| `uid` | string | sim | imutável | deve ser igual ao ID |
| `name` | string | sim | próprio usuário | nome de exibição |
| `email` | string | sim | imutável no documento | deve coincidir com Auth no cadastro |
| `role` | enum string | sim | backend após cadastro | `aluno`, `professor`, `gym_admin`, `super_admin` |
| `memberType` | enum string/null | app: sim; admin: opcional | protegido | persona `aluno` ou `professor` |
| `photoUrl` | string/null | não | próprio usuário | URL do avatar |
| `academyId` | string/null | não | backend | relação administrativa com academia |
| `professorId` | string/null | não | backend de vínculos | professor atual do aluno |
| `createdAt` | Timestamp | sim | criação | data de criação |
| `updatedAt` | Timestamp | recomendado | fluxo autorizado | última atualização |

`role` é RBAC; `memberType` é a persona funcional. Exemplo válido: `role=super_admin` e `memberType=aluno`.

Campos de resumo ainda lidos/escritos no documento raiz:

| Campo | Tipo | Situação |
| --- | --- | --- |
| `peso`, `altura`, `bodyFatPercentage`, `imc` | number/string conforme legado | resumo físico atual; professor vinculado pode alterar conjunto limitado |
| `fcmTokens` | array<string> | operacional; usado pelo push legado |
| `purchased_templates` | array<string> | compatibilidade; backend atualiza junto do entitlement |
| `check_*` | bool | tags legadas usadas pela Store |

### Exemplo válido

```json
{
  "schemaVersion": 2,
  "uid": "uid_aluno_123",
  "name": "Pessoa Exemplo",
  "email": "pessoa@example.com",
  "role": "aluno",
  "memberType": "aluno",
  "photoUrl": null,
  "academyId": null,
  "professorId": "uid_professor_456",
  "createdAt": "<server timestamp>",
  "updatedAt": "<server timestamp>"
}
```

## 4. Estado do cliente — `users/{uid}/client_state/current`

| Campo | Tipo | Obrigatório | Regra |
| --- | --- | --- | --- |
| `schemaVersion` | int | sim | exatamente 2 |
| `appVersion` | string | sim | não vazio |
| `buildNumber` | int | sim | mínimo 9 |
| `platform` | enum string | sim | android, ios, web, macos, windows, linux ou unknown |
| `firstSeenAt` | Timestamp | sim | igual a `request.time` na criação e imutável |
| `lastSeenAt` | Timestamp | sim | igual a `request.time` em cada escrita |

Ownership: somente o próprio usuário lê/cria/atualiza; exclusão é negada.

## 5. Dados privados e de saúde

### 5.1 Anamnese — `users/{studentId}/medical/anamnese`

Documento flexível mantido por compatibilidade. Campos ativos:

- objetivos: `check_<objetivo>` (bool), `esporte_especifico`, `prazo_resultados`;
- histórico: `nivel_atividade`, `historico_musculacao`, `outros_esportes`;
- triagem: `lesao` e detalhe, `check_<dor>`, `cardiaco`, `tonturas`, `cirurgia` e detalhe, `medicamento` e detalhe, `liberacao_medica`;
- estilo de vida: `sono`, `alimentacao`, `estresse`, `fumante_alcool`;
- logística/preferências: `freq_semanal`, `tempo_treino`, `horario_treino`, `gosta_fazer`, `detesta_fazer`.

Tipos são majoritariamente string, bool e arrays/flags de seleção. Nenhum campo isolado é obrigatório pelas Rules. O aluno é dono e único escritor; o professor vinculado tem leitura.

### 5.2 Avaliações — `users/{studentId}/assessments/{assessmentId}`

| Grupo | Campos | Tipo |
| --- | --- | --- |
| Medidas básicas | `weight`, `height`, `neck`, `shoulders`, `chest`, `waist`, `abdomen`, `hips` | number |
| Membros | `armRightRelaxed`, `armLeftRelaxed`, `armRightContracted`, `armLeftContracted`, `forearmRight`, `forearmLeft`, `thighRight`, `thighLeft`, `calfRight`, `calfLeft` | number |
| Composição | `bodyFatPercentage`, `fatMassKg`, `muscleMassKg`, `visceralFat`, `bodyWaterPercentage`, `boneMass` | number |
| Metabolismo | `basalMetabolism`, `metabolicAge`, `imc` | number |
| Classificação | `generalRating` | string |
| Evento | `date` | Timestamp |

`weight` e `height` são obrigatórios na UI atual; `date` é gravado pelo servidor. Aluno e professor vinculado podem ler/escrever/excluir. A criação atual usa batch para criar avaliação e atualizar o resumo físico em `users/{studentId}`.

### 5.3 Nota privada — `users/{studentId}/private_notes/{professorId}`

| Campo | Tipo | Obrigatório |
| --- | --- | --- |
| `personalId` | string | sim; deve ser igual ao ID e ao usuário autenticado |
| `text` | string | sim |
| `updatedAt` | Timestamp | sim |

Somente o professor atualmente vinculado lê e grava. O aluno não lê.

### 5.4 Paths v2 ainda não ativados

Existem models para `users/{uid}/profile/private` e `users/{uid}/fitness/current`, mas o app atual não possui repository/escrita nesses paths e as Rules não os liberam. Eles são **destino de normalização**, não contrato ativo:

- perfil: `birthDate`, `gender`, `updatedAt`;
- fitness: `weightKg`, `heightCm`, `objective`, `weeklyFrequency`, `updatedAt`.

## 6. Relacionamento profissional

### 6.1 Convites — `invites/{inviteId}`

ID determinístico: `professional_<sha256(professorId:studentId)[0..40]>`.

| Campo | Tipo | Obrigatório | Observação |
| --- | --- | --- | --- |
| `schemaVersion` | int | sim | atual 1 |
| `fromPersonalId` | string | sim | identificador do professor |
| `personalId` | string | sim | campo de domínio mantido |
| `personalName` | string | sim | snapshot de exibição |
| `toStudentEmail` | string | sim | e-mail normalizado |
| `studentUid` | string | sim | aluno destinatário |
| `status` | enum | sim | pending, accepted, rejected ou canceled |
| `sentAt` | Timestamp | sim | servidor |
| `respondedAt` | Timestamp/null | sim | null enquanto pending |
| `updatedAt` | Timestamp | sim | servidor |

Todas as mutações são backend-only. Professor e aluno envolvidos podem ler.

### 6.2 Vínculo ativo

O vínculo canônico é `users/{studentUid}.professorId`. `users.personalId` é fallback legado e não deve ser recriado em novos aceites. Campos `personalId` dentro de `invites`, `workouts`, `workout_templates` e `private_notes` pertencem aos seus domínios e não são o mesmo legado.

## 7. Treinos

### 7.1 Exercício embutido

| Campo | Tipo | Obrigatório |
| --- | --- | --- |
| `id`, `nome`, `series`, `repeticoes` | string | sim |
| `concluido`, `solicitarAlteracao` | bool | sim |
| `carga` | string | sim |
| `videoUrl` | string/null | não |
| `observacao` | string | não |

### 7.2 Ficha semanal — `workout_plans/{studentId}`

| Campo | Tipo | Obrigatório |
| --- | --- | --- |
| `segunda` … `domingo` | array<WorkoutExercise> | conforme dias prescritos |
| `feedback_segunda` … `feedback_domingo` | string | não |
| `validade` | Timestamp | não |
| `avisadoVencimento` | bool | não; default false |

O ID é o UID do aluno. Aluno e professor vinculado leem/escrevem; somente o professor vinculado exclui o documento.

### 7.3 Histórico — `workout_history/{historyId}`

| Campo | Tipo | Obrigatório |
| --- | --- | --- |
| `studentId` | string | sim |
| `diaDaSemana` | string | sim |
| `dataRealizacao` | Timestamp | sim |
| `exercicios` | array<WorkoutExercise> | sim |
| `feedback` | string | não |

### 7.4 Modelos privados — `workouts/{workoutId}`

Campos: `nome` (string), `grupoMuscular` (string), `exercicios` (array), `personalId` (string), `criadoEm` e `atualizadoEm` (Timestamp). Professor cria/altera/exclui somente os próprios; leitura autenticada ampla é compatibilidade atual.

### 7.5 Templates — `workout_templates/{templateId}`

| Campo | Tipo | Situação |
| --- | --- | --- |
| `personalId` | string | proprietário; `SYSTEM_ADMIN` identifica oficial |
| `nome` | string | obrigatório |
| `fichas` | map<string, array<Exercise>> | formato atual de múltiplas fichas |
| `exercicios` | array<Exercise> | legado e cópia compatível da Ficha A |
| `tags` | array<string> | recomendação |
| `preco` | number | preço server-side para oficial |
| `isPremium` | bool | catálogo pago |
| `timestamp` | Timestamp | criação |

Super admin administra qualquer template; professor administra apenas os próprios. Não remover `exercicios` até migração própria.

### 7.6 Catálogo — `exercises/{exerciseId}`

`nome` (string, obrigatório), `grupo` (string), `videoUrl` (string), `criadoEm` (Timestamp). Leitura autenticada; escrita exclusiva de super admin.

## 8. Comunicação

### 8.1 Chat — `chats/{chatId}`

ID determinístico: UIDs ordenados lexicograficamente e concatenados.

| Campo | Tipo | Obrigatório |
| --- | --- | --- |
| `users` | array<string> | sim; exatamente dois participantes |
| `lastMessage` | string | sim após primeira mensagem |
| `lastTime` | Timestamp | sim após primeira mensagem |

`chats/{chatId}/messages/{messageId}`: `senderId` (string), `text` (string), `timestamp` (Timestamp).

Há compatibilidade temporária que permite criar a primeira mensagem antes do documento pai. Não usar esse comportamento em novas implementações.

### 8.2 Notificações — `users/{uid}/notifications/{id}`

Campos comuns: `type`, `title`, `body`, `senderName?`, `actionId?`, `studentId?` (string), `isRead` (bool), `timestamp` (Timestamp).

Tipos observados: `invite`, `message`, `workout`, `workout_update`, `arena`, `assessment`. O dono lê/atualiza/exclui. A criação por qualquer autenticado é dívida de segurança.

## 9. Arena

### 9.1 Amizades — `friendships/{id}`

`requesterId`, `requesterName`, `requesterPhoto?`, `receiverId`, `receiverName`, `receiverPhoto?`, `status` (`pending|accepted`) e `timestamp`.

### 9.2 Desafios — `challenges/{id}`

| Campo | Tipo | Obrigatório |
| --- | --- | --- |
| `creatorId` | string | sim |
| `metric` | enum | weight, bodyFatPercentage, constancy ou volume |
| `durationDays` | int | sim |
| `startDate` | Timestamp | sim |
| `participantIds` | array<string> | sim |
| `participants` | map<uid, participant> | sim |
| `imagensApagadas` | bool | sim |

Participante: `name`, `photoUrl?`, `status` (`pending|accepted`) e `startValue?`.

Posts em `challenges/{id}/posts/{postId}`: `authorId`, `authorName`, `authorPhoto?`, `text`, `imageUrl?`, `timestamp`, `reactions` (map<emoji,array<uid>>), `commentsCount`.

Comentários: `authorId`, `authorName`, `authorPhoto?`, `text`, `timestamp`.

## 10. Tarefas e feedback

### `tarefas/{id}`

`titulo` (string), `concluida` (bool), `userId` (string), `dataCriacao` (Timestamp), `dataConclusao` (Timestamp/null). Campo legado de leitura: `data`.

### `beta_feedback/{id}`

`userId` (string), `timestamp` (Timestamp), `nota` (int 1–5), `confuso`, `bugs`, `gostou` (string) e `status` (string, inicial `novo`).

## 11. Academias

### 11.1 `academias/{academyId}`

| Campo | Tipo | Obrigatório | Autoridade |
| --- | --- | --- | --- |
| `nome`, `emailGestor`, `ownerUid` | string | sim | cadastro/backend |
| `cnpj`, `telefoneResponsavel`, `cep`, `endereco`, `bairro`, `uf` | string | conforme cadastro | gym admin altera dados cadastrais |
| `licencasTotais`, `licencasUsadas` | int >= 0 | sim | backend |
| `dataCadastro` | Timestamp | sim | backend |
| `cancelamentoAgendado` | bool | não | gym admin só pode false → true |
| campos financeiros legados | variados | compatibilidade | backend |

Ownership exige simultaneamente `academias.ownerUid == auth.uid` e `users/{uid}.academyId == academyId` (com fallback temporário `academiaId`).

### 11.2 Licenças — `academias/{academyId}/professores/{licenseId}`

ID determinístico derivado do e-mail normalizado. Campos: `schemaVersion` (int), `email` (string), `status` (inicial `Pendente`) e `dataVinculo` (Timestamp). Escrita exclusiva do backend.

## 12. Pagamentos, assinaturas e entitlements

### 12.1 `payments/{providerPaymentId}`

Campos obrigatórios: `schemaVersion`, `provider=mercadopago`, `providerPaymentId`, `userId`, `productId`, `productKind`, `displayName`, `entitlement`, `amount`, `currency`, `paymentMethodType`, `installments`, `status`, `createdAt`, `updatedAt`.

Opcionais: `sourceId`, `billingPeriod`, `providerPaymentMethodId`, `statusDetail`, `fulfillmentStatus`, `fulfilledAt`. Nunca armazenar número de cartão, CVV, token de cartão ou CPF.

### 12.2 `payment_fulfillments/{providerPaymentId}`

`schemaVersion`, `provider`, `providerPaymentId`, `userId`, `productId`, `entitlementId`, `status=fulfilled`, `fulfilledAt`. Marcador determinístico que garante concessão única.

### 12.3 `subscriptions/{uid}`

| Campo | Tipo |
| --- | --- |
| `schemaVersion`, `userId` | int, string |
| `productId`, `productKind`, `displayName`, `billingPeriod`, `currency` | string |
| `provider`, `providerSubscriptionId?`, `latestPaymentId?` | string/null |
| `status` | pending, active, past_due, canceled ou expired |
| `currentPeriodStart`, `currentPeriodEnd` | Timestamp/null |
| `cancelAtPeriodEnd` | bool |
| `cancellationRequestedAt`, `canceledAt` | Timestamp/null |
| `createdAt`, `updatedAt` | Timestamp |

### 12.4 `users/{uid}/entitlements/{entitlementId}`

`schemaVersion`, `entitlementId`, `userId`, `entitlementType`, `productId`, `productKind`, `sourceId?`, `status` (`active|expired`), `validFrom?`, `validUntil?`, `acquisitionType` (`payment|free`), `providerPaymentId?`, `grantedAt`, `updatedAt`.

IDs atuais: `personal_premium` ou `workout_template_<templateId>`.

### 12.5 Webhooks — `webhook_events/{notificationId}`

`schemaVersion`, `provider`, `notificationId`, `resourceType`, `providerResourceId`, `providerPaymentId?`, `requestId?`, `outcome`, `processedAt`.

## 13. Assinatura B2B

### `academy_subscription_attempts/{attemptId}`

`schemaVersion`, `attemptId`, `provider`, `userId`, `academyId`, `licenseQuantity`, `monthlyAmount`, `currency`, `billingDay`, `status`, `providerPlanId?`, `providerSubscriptionId?`, `createdAt`, `updatedAt`.

### `academy_subscriptions/{academyId}`

Campos estáveis: `schemaVersion`, `provider`, `academyId`, `ownerUid`, `attemptId`, `status`, `licenseQuantity`, `monthlyAmount`, `currency`, `billingDay`, `providerPlanId?`, `providerSubscriptionId?`, `providerStatus?`, `createdAt`, `updatedAt`.

Campos de reconciliação podem incluir `reconciledAt`, `billingStatus`, IDs/status/detail da cobrança, tentativa, data de débito, última modificação do provedor e última cobrança aprovada. São backend-only.

## 14. Métricas internas

`system_metrics/user_v2_compatibility` contém somente agregados: contadores e timestamps de escritas legadas, `watchSchemaVersion`, `watchStartedAt` e `lastClientStateHeartbeatAt`. É proibido persistir UID, e-mail, nome ou IDs de relacionamento nessa métrica.

## 15. Índices

O arquivo canônico possui dois índices para a collection `historico` com `usuarioId` e `data`. O código atual usa `workout_history`, `studentId` e `dataRealizacao`; portanto esses índices são classificados como **legados/a auditar**, não como prova do contrato atual.

Queries compostas de `invites`, `friendships`, `challenges`, `workout_templates` e histórico devem ser validadas no Emulator e no projeto de destino. Novo índice deve entrar em `okan_backend/firestore.indexes.json` no mesmo PR da query.

## 16. Campos legados e depreciados

| Legado | Canônico/destino | Regra de transição |
| --- | --- | --- |
| `tipo` | `role` + `memberType` | apenas leitura/fallback |
| `role=personal` | `role=professor` | normalização |
| `users.personalId` | `users.professorId` | fallback até sunset |
| `nome` | `name` | fallback |
| `academiaId` | `academyId` | fallback |
| `peso/weight` | `fitness.weightKg` | destino; conflitos não são resolvidos silenciosamente |
| `altura` | `fitness.heightCm` | destino |
| `objetivo/objectives` | `fitness.objective` | destino |
| `dataNascimento/birthDate` raiz | `profile/private.birthDate` | destino |
| `purchased_templates` | entitlement | backend mantém compatibilidade |
| `profile_photos` | `user_photos` atual | remover somente após migração de objetos/clientes |
| template `exercicios` | `fichas` | compatibilidade de Ficha A |

Sunset exige build v2 distribuído, watcher ativo, ao menos 30 dias sem novas escritas de identidade legada, revisão da Play Console e aprovação manual.

## 17. Contratos entre app, web e backend

| Contrato | App | Web | Backend |
| --- | --- | --- | --- |
| User v2 | normaliza e escreve identidade comum | normaliza para RBAC/métricas | migra, protege e monitora |
| Vínculo aluno/professor | solicita Callable | não é autoridade | transação e limite de plano |
| Academia/licenças | consulta quando aplicável | solicita Callables | ownership, capacidade e transação |
| Template | consome/aplica | administra oficiais | resolve preço e entitlement |
| Pagamento | envia `productId` | inicia B2B autenticado | preço, provedor, webhook e benefício |
| Dados de saúde | UI por repository | sem acesso automático | Rules de proprietário/vínculo |

Alterar nome, tipo, obrigatoriedade ou ownership de qualquer campo exige atualização coordenada dos três contratos, testes e plano de rollout.
