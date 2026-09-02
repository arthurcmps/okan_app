# Roadmap Técnico do Okan

**Revisado em:** 1º de setembro de 2026  
**Escopo:** OKAN-001 a OKAN-040 e próximos gates  
**Fonte de verdade:** código mergeado, testes e documentos de ticket

## 1. Como interpretar

| Status | Significado |
| --- | --- |
| `planned` | escopo conhecido, sem implementação iniciada |
| `in progress` | implementação parcial ou critério relevante ainda aberto |
| `blocked` | impedimento externo ou decisão obrigatória impede avanço |
| `done` | objetivo principal integrado com evidência; débitos residuais são registrados na nota |

`done` não significa ausência de dívida técnica. Significa que o critério central do ticket foi entregue sem impedir a evolução seguinte. O status deve ser atualizado no mesmo PR que altera materialmente o estado.

## 2. Visão executiva

| Frente | Tickets | Estado |
| --- | --- | --- |
| Segurança de dados e Storage | OKAN-001–007 | base entregue; padronização de upload segue em andamento |
| Pagamentos e entitlement | OKAN-008–013 | entregue no backend canônico |
| Backend único e User v2 | OKAN-014–023 | entregue com compatibilidade observada |
| Migrações e consistência | OKAN-024–029 | maior parte entregue; templates/exercícios ainda têm legado ativo |
| Arquitetura Flutter | OKAN-030–034 | separação por feature e repositories entregue |
| Qualidade e CI | OKAN-035–037 | pipelines e testes de Rules entregues |
| Ambientes e observabilidade | OKAN-038–040 | DEV/STAGING/Crashlytics entregues; hardening listado abaixo |

## 3. Roadmap detalhado

### Segurança, Rules e Storage

| Ticket | Entrega | Status | Evidência/nota |
| --- | --- | --- | --- |
| OKAN-001 | Rotacionar Mercado Pago e secrets | `done` | Secrets retirados do cliente e tratados no backend |
| OKAN-002 | Inventariar collections e operações | `done` | Inventário utilizado pelas Rules v2 e pelo modelo de dados |
| OKAN-003 | Firestore Rules v2 | `done` | deny-by-default, ownership, vínculo e RBAC |
| OKAN-004 | Testes de Rules em emulador | `done` | cenários positivos e negativos no pipeline |
| OKAN-005 | Storage Rules v2 | `done` | paths conhecidos, owner/participante e limite de tamanho |
| OKAN-006 | Padronizar paths de upload | `in progress` | `user_photos` é canônico, mas `profile_photos` legado permanece; MIME também precisa de hardening |
| OKAN-007 | Autorizar dados de saúde e notas privadas | `done` | owner/vínculo e escrita restrita implementados |

### Pagamentos e assinaturas

| Ticket | Entrega | Status | Evidência/nota |
| --- | --- | --- | --- |
| OKAN-008 | Catálogo de produtos server-side | `done` | cliente envia identificador; backend resolve produto/preço |
| OKAN-009 | Checkout somente por `productId` | `done` | preço client-side não é fonte de verdade |
| OKAN-010 | Modelo de pagamentos | `done` | collections e estados backend-owned |
| OKAN-011 | Assinaturas | `done` | status e período corrente controlam premium |
| OKAN-012 | Entitlements server-side | `done` | cliente possui leitura, sem escrita |
| OKAN-013 | Webhook idempotente | `done` | eventos e fulfillment determinísticos evitam duplicidade |

### Backend canônico e User v2

| Ticket | Entrega | Status | Evidência/nota |
| --- | --- | --- | --- |
| OKAN-014 | Escolher backend canônico temporário | `done` | decisão sucedida pelo repositório dedicado |
| OKAN-015 | Criar `okan_backend` | `done` | repositório privado é fonte canônica |
| OKAN-016 | Mover Cloud Functions | `done` | app/web não são mais fonte operacional de Functions |
| OKAN-017 | Mover Rules e índices | `done` | arquivos canônicos no backend |
| OKAN-018 | Remover duplicações | `done` | compatibilidade centralizada; manter auditoria para evitar reintrodução |
| OKAN-019 | Definir User v2 | `done` | `schemaVersion`, `role` e `memberType` normalizados |
| OKAN-020 | Modelos compatíveis | `done` | leitura canônica com fallback legado controlado |
| OKAN-021 | Script de migração | `done` | execução idempotente/reexecutável prevista |
| OKAN-022 | Migrar usuários | `done` | base canônica ativada com observação de escritas legadas |
| OKAN-023 | Normalizar papéis | `done` | roles comuns/admin separados de persona mobile |

### Migrações, licenças e fluxos sociais

| Ticket | Entrega | Status | Evidência/nota |
| --- | --- | --- | --- |
| OKAN-024 | Migrar templates/exercícios | `in progress` | collections e campos legados ainda participam do runtime; concluir antes de removê-los |
| OKAN-025 | Licenças de academia transacionais | `done` | grant/revoke idempotentes e limitados ao total |
| OKAN-026 | ID determinístico de chat | `done` | contrato reduz duplicidade por par de usuários |
| OKAN-027 | Migração/fallback de chat | `done` | compatibilidade preservada durante transição |
| OKAN-028 | Convites e vínculo profissional | `done` | convite determinístico, estados e desvinculação server-side |
| OKAN-029 | Mitigar XSS no painel web | `done` | renderização administrativa endurecida; manter CSP/dependências em revisão |

### Arquitetura Flutter

| Ticket | Entrega | Status | Evidência/nota |
| --- | --- | --- | --- |
| OKAN-030 | Repository Pattern | `done` | contratos de domínio e implementações Firebase por feature |
| OKAN-031 | Separar Workouts | `done` | domínio/dados/apresentação isolados |
| OKAN-032 | Separar Students | `done` | vínculo e consultas encapsulados |
| OKAN-033 | Separar Assessments/Anamnese | `done` | acesso clínico/avaliações por repositories |
| OKAN-034 | Separar Chat/Arena/Store | `done` | features migradas; acessos legados restantes seguem baseline controlado |

### CI e qualidade

| Ticket | Entrega | Status | Evidência/nota |
| --- | --- | --- | --- |
| OKAN-035 | Flutter CI | `done` | Flutter 3.47.0/Dart 3.13.0, análise e suíte automatizada |
| OKAN-036 | Functions CI | `done` | Node 24 e testes automatizados; vulnerabilidades de dependência permanecem backlog explícito |
| OKAN-037 | Firebase Rules CI | `done` | Node 24, Java 21 e Firebase CLI fixado com emuladores |

### Ambientes e observabilidade

| Ticket | Entrega | Status | Evidência/nota |
| --- | --- | --- | --- |
| OKAN-038 | Ambiente DEV | `done` | Emulator Suite e serviços externos bloqueados |
| OKAN-039 | Ambiente STAGING | `done` | projeto isolado, configuração explícita e fail-closed; painel web staging ainda é dívida |
| OKAN-040 | Crashlytics e logs | `done` | merge `889f52f`; Android STAGING/PROD, handlers fatal/não fatal e chaves mínimas |

## 4. Estado atual dos repositórios

| Repositório | Papel | Marco observado |
| --- | --- | --- |
| `okan_app` | Flutter e documentação mestre | `main` inclui OKAN-040 |
| `okan_web` | painel administrativo estático | `main` inclui OKAN-029; configuração ainda PROD-only |
| `okan_backend` | Functions, Rules, índices e integrações | backend canônico privado; `compatibility_index.js` isola STAGING |

## 5. Próximos gates recomendados

Estes itens são sequência técnica recomendada, ainda sem número de ticket para não inventar compromisso de planejamento:

| Prioridade | Gate | Resultado esperado |
| ---: | --- | --- |
| P0 | Exigir App Check nas Functions elegíveis | `enforceAppCheck` testado por ambiente, rollout e rollback definidos |
| P0 | Criar configuração STAGING do painel web | build/hosting target fail-closed sem configuração PROD hardcoded |
| P0 | Restringir leitura de `users` | `public_profiles` mínimo e consulta sem exposição de perfil completo |
| P0 | Mover criação de notificações críticas ao backend | eliminar falsificação/spam client-side |
| P1 | Concluir OKAN-006 | migrar `profile_photos`, validar MIME e remover path legado |
| P1 | Concluir OKAN-024 | aposentar contratos/collections legados de templates e exercícios |
| P1 | Tratar baseline de vulnerabilidades npm | atualizar dependências com testes de regressão |
| P1 | Formalizar contrato de API | documentar todas as Callables/HTTP/triggers e versionamento |
| P1 | Criar Runbook e Release | incidentes, deploy, rollback e responsabilidades |
| P1 | Consolidar privacidade/LGPD | retenção, exportação, exclusão e bases legais |
| P2 | Completar CI/CD de deploy | promoção STAGING→PROD com approvals e evidência |
| P2 | Migrar autorização administrativa para Claims | reduzir dependência de role consultada em Firestore |

## 6. Dívidas que impedem uma falsa sensação de conclusão

- App Check ativado no cliente não equivale a enforcement das Callables.
- O painel web não possui ambiente STAGING consolidado.
- `users` e `workouts` ainda têm leitura autenticada ampla por compatibilidade.
- `notifications` permite create client-side por qualquer autenticado.
- Storage limita tamanho, mas não valida MIME.
- índices versionados contêm entrada de `historico` legada e precisam ser reconciliados com queries atuais de `workout_history`.
- `users/{uid}/profile/private` e `fitness/current` são modelo-alvo, não paths ativos autorizados.
- Crashlytics está validado no escopo Android; demais plataformas permanecem fail-closed até integração explícita.

## 7. Critério para atualizar o roadmap

Um ticket só muda para `done` quando houver:

1. implementação no repositório canônico;
2. testes relevantes verdes;
3. critério negativo quando a mudança é de segurança;
4. compatibilidade/migração descrita;
5. ambiente validado sem fallback;
6. documento de ticket preservado;
7. documento mestre atualizado quando o estado atual mudou.

Quando existir diferença entre intenção do ticket e runtime, o runtime prevalece e a lacuna deve aparecer como `in progress` ou dívida explícita.

## 8. Documentação existente e planejada

### Mestres consolidados

- [README principal](../README.md)
- [Termo de Abertura](PROJECT-CHARTER.md)
- [Arquitetura](ARCHITECTURE.md)
- [Modelo de Dados](DATA-MODEL.md)
- [Regras de Negócio](BUSINESS-RULES.md)
- [Segurança](SECURITY.md)
- [Ambientes](ENVIRONMENTS.md)
- este Roadmap

### Próxima onda documental

| Documento | Gatilho |
| --- | --- |
| `OBSERVABILITY.md` | consolidação pós-OKAN-040, com operação real do Crashlytics/logs |
| `PRODUCT-SPEC.md` | validação de planos, personas e critérios de aceite com Produto |
| `APP-ARCHITECTURE.md` | aprofundamento do padrão por feature e baseline legado |
| `BACKEND-ARCHITECTURE.md` | inventário definitivo de exports/deploys por ambiente |
| `API-CONTRACT.md` | versionamento e contratos por Function |
| `TESTING.md` | metas de cobertura e matriz E2E |
| `CI-CD.md` / `RELEASE.md` | quando deploy automatizado for aprovado |
| `RUNBOOK.md` | antes de ampliar operação em PROD |
| `PRIVACY-DATA-GOVERNANCE.md` | antes de formalizar exportação/exclusão e retenção |
| `docs/adr/*` | uma ADR por decisão arquitetural estável |
| `CHANGELOG.md` | a partir do próximo release versionado |

Documentos de ticket existentes não devem ser sobrescritos: eles preservam contexto histórico. Documentos mestres representam o estado atual e devem apontar divergências conhecidas.
