# Termo de Abertura do Projeto — Okan

**Versão:** 1.0  
**Estado:** ativo  
**Revisado em:** 1º de setembro de 2026  
**Responsável pelo produto:** Arthur Campos

## 1. Visão

Ser o coração digital da relação entre quem treina, quem orienta o treino e quem oferece a estrutura, transformando dados dispersos em acompanhamento contínuo, humano e confiável.

O nome Okan significa “coração” e orienta a proposta do produto: tecnologia para aproximar pessoas, dar continuidade ao cuidado e tornar o progresso visível sem reduzir a experiência a números ou a uma ficha estática.

## 2. Objetivo

Construir e operar uma plataforma segura e sustentável que permita:

- prescrever, executar e acompanhar treinos;
- formalizar o vínculo entre aluno e profissional;
- registrar feedback, histórico, anamnese e avaliações;
- oferecer comunicação, notificações, comunidade e gamificação;
- apoiar a operação B2B de academias, licenças e assinaturas;
- monetizar assinaturas e conteúdos digitais sem confiar no cliente para decisões financeiras.

## 3. Público-alvo

| Segmento | Necessidade principal |
| --- | --- |
| Aluno | Treino claro, acompanhamento, evolução, feedback e motivação |
| Professor/personal | Gestão de alunos, prescrição, avaliações, comunicação e monetização |
| Academia | Administração de profissionais, licenças e cobrança B2B |
| Operação Okan | Catálogo, templates oficiais, feedbacks, segurança e suporte |

## 4. Problema de negócio

O mercado possui soluções isoladas para treino, mensagens, planilhas, cobrança e gestão. A fragmentação dificulta a retenção do aluno, aumenta o trabalho manual do profissional, reduz a visibilidade da academia e cria riscos de privacidade quando dados de saúde circulam por canais inadequados.

O Okan busca concentrar esse ciclo em um produto único, com autorização por domínio e fontes de verdade server-side para privilégios, pagamentos, assinaturas, licenças e entitlements.

## 5. Escopo atual

### Aplicativo

- autenticação por e-mail/senha e Google;
- perfis de aluno e professor;
- onboarding, perfil e dados pessoais;
- ficha semanal, execução, feedback, validade e histórico de treinos;
- catálogo de exercícios e templates;
- vínculo professor–aluno por convite;
- anamnese, avaliações físicas, gráficos e notas privadas;
- chat, notificações e FCM;
- tarefas/metas;
- Arena com amizades, desafios, ranking, mural e comentários;
- loja de templates e assinatura do professor;
- Crashlytics no Android em STAGING/PROD.

### Painel web

- autenticação e RBAC de `gym_admin` e `super_admin`;
- cadastro e administração de academia;
- licenças de professores;
- assinatura B2B;
- catálogo global, templates oficiais e feedbacks.

### Backend

- fonte canônica de Functions, Rules, índices e scripts;
- catálogo e confirmação de pagamentos server-side;
- subscriptions, entitlements e webhook idempotente;
- licenças transacionais;
- cadastro B2B transacional;
- vínculos profissionais transacionais;
- ambientes DEV, STAGING e PROD;
- CI de Functions e Rules.

## 6. Fora de escopo desta base documental

- reescrita total ou migração imediata para monorepo;
- remoção física dos campos legados antes do encerramento formal da compatibilidade;
- cópia de dados de produção para DEV ou STAGING;
- prontuário médico, diagnóstico, prescrição clínica ou decisão automatizada de saúde;
- folha de pagamento, controle de acesso físico à academia ou ERP completo;
- suporte offline completo;
- suporte Crashlytics Apple antes da identidade/configuração Firebase Apple ser validada;
- homologação de pagamentos reais fora de PROD.

## 7. Premissas

- Firebase continuará como plataforma principal no horizonte atual;
- `okan_backend` continuará sendo a fonte canônica de infraestrutura;
- Android é a plataforma móvel prioritária e usa `applicationId=com.sankofa.okan`;
- Mercado Pago continuará como provedor atual de pagamentos;
- dados existentes serão preservados por migrações aditivas e compatibilidade temporária;
- mudanças críticas serão validadas em emuladores e/ou STAGING antes de PROD.

## 8. Restrições

- equipe enxuta, com Arthur acumulando visão de produto, validação e desenvolvimento;
- base já publicada e presença possível de clientes legados;
- painel web sem bundler e atualmente ligado diretamente a PROD;
- dívida legada de lint e de campos históricos;
- dependência de serviços externos e credenciais administradas fora do repositório;
- dados de saúde elevam o nível de cuidado exigido por segurança e LGPD.

## 9. Riscos principais

| Risco | Probabilidade | Impacto | Tratamento atual |
| --- | --- | --- | --- |
| Vazamento de dados de saúde/PII | Média | Crítico | Rules por domínio, notas privadas e logs sem PII |
| Cliente adulterar privilégios/pagamentos | Média | Crítico | Campos server-owned, Functions e catálogo server-side |
| Regressão por cliente legado | Média | Alto | User v2 com fallback e janela de compatibilidade medida |
| Deploy no projeto Firebase errado | Média | Crítico | IDs fixos, guards e STAGING fail-closed |
| Cobrança/licença inconsistente | Média | Alto | transações, idempotência e reconciliação |
| App Check não bloquear chamadas privilegiadas | Média | Alto | ativação no cliente; enforcement das Callables ainda é dívida explícita |
| Leitura ampla da coleção `users` | Alta | Alto | migração futura para projeção pública mínima |
| Dependência excessiva de uma pessoa | Alta | Alto | documentação mestre, tickets, CI e runbooks futuros |

## 10. Critérios de sucesso

### Produto

- aluno conclui a jornada de cadastro, vínculo, treino, feedback e evolução;
- professor gerencia alunos vinculados sem acessar terceiros;
- academia contrata capacidade e administra licenças sem ultrapassar o limite;
- pagamentos aprovados concedem benefícios uma única vez.

### Engenharia

- uma única fonte de Functions e Rules;
- CI verde para Flutter, Functions e Rules;
- ambientes separados e sem fallback silencioso;
- nenhuma credencial privada em Git;
- nenhuma escrita client-side de role, assinatura, entitlement ou contadores de licença;
- incidentes críticos observáveis e investigáveis sem registrar PII.

### Negócio

- conversão para o plano pago do professor;
- adesão de academias ao licenciamento B2B;
- venda/aquisição de templates oficiais;
- retenção e frequência de uso das jornadas de treino.

Metas numéricas devem ser definidas quando analytics de produto e baseline de operação estiverem disponíveis; não são inventadas neste documento.

## 11. Stakeholders

| Stakeholder | Papel |
| --- | --- |
| Arthur Campos | Product Owner, responsável técnico e aprovador funcional |
| Alunos | Usuários finais e titulares de dados pessoais/saúde |
| Professores/personais | Prestadores do acompanhamento e criadores de treinos |
| Academias/gym admins | Clientes B2B e administradores de licenças |
| Super admins Okan | Operação de catálogo, academias e suporte |
| Google/Firebase | Plataforma de identidade, dados, execução e observabilidade |
| Mercado Pago | Processamento de pagamentos e assinaturas |
| Google Play/Apple | Distribuição e integridade dos aplicativos |

## 12. Modelo de monetização

| Oferta | Cliente | Estado atual |
| --- | --- | --- |
| Plano Base | Professor | Gratuito, limitado a 3 alunos ativos + convites pendentes |
| Mestre Sankofa | Professor | R$ 49,90/mês, alunos ilimitados enquanto ativo |
| Licenças de academia | Academia | R$ 45,00 por licença/mês; quantidade e valor calculados no backend |
| Templates oficiais | Aluno | Preço definido no template oficial e resolvido pelo backend |
| Templates gratuitos | Aluno | Entitlement gratuito apenas quando o preço server-side é zero |

Preços são contratos atuais de código, não autorização para alteração comercial sem ticket e revisão. O cliente nunca é fonte de verdade do preço.

## 13. Governança

- mudanças de visão, escopo ou monetização exigem decisão do Product Owner;
- mudanças arquiteturais duráveis devem gerar ADR;
- tickets preservam o histórico; documentos mestres refletem o estado atual;
- mudança de schema, regra de negócio, ambiente ou autorização deve atualizar o respectivo documento mestre no mesmo PR.
