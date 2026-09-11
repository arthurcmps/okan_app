# Execução do Plano Visual e de UX

## 1. Finalidade

Este documento acompanha a execução do **Plano Melhoria Visual UX-Okan**, versão 1.0, revisado em 4 de setembro de 2026.

O plano original descreve o estado desejado e os pacotes UX-01 a UX-10. Este documento registra o estado comprovado no código e deve ser atualizado sempre que uma PR mudar a situação de um pacote.

Estados permitidos:

- `planned`: ainda não iniciado de forma controlada;
- `in progress`: há entregas integradas, mas algum critério de aceite permanece pendente;
- `blocked`: existe dependência ou gate não atendido;
- `done`: todos os critérios de pronto foram comprovados.

## 2. Baseline do aplicativo

| Campo | Referência |
|---|---|
| Repositório | `arthurcmps/okan_app` |
| Branch canônica | `main` |
| SHA do baseline | `9b3bbdb1456a1c1cb6a77136f77ab1ed00033647` |
| Data do baseline | 10 de setembro de 2026 |
| Versão declarada | `1.0.1+10` |
| Flutter do CI | `3.47.0`, canal stable |
| Ambiente manual | DEV local, projeto sintético `demo-okan-dev` |
| Última suíte observada | GitHub Actions, execução 126, aprovada na PR 50 |
| Referência de distribuição | build `1.0.1+10`; confirmar o estado da revisão na Play Console antes de promover novas mudanças |

Este SHA foi escolhido depois da correção do fluxo de exercícios em templates e da aprovação da matriz integrada da UX-05. Ele é a referência para comparar as próximas mudanças visuais do aplicativo.

### 2.1 Comandos reproduzíveis

```powershell
git switch main
git pull origin main
git rev-parse HEAD
flutter --version
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

Resultado esperado:

- o SHA local corresponde ao `origin/main` escolhido para o teste;
- `pubspec.lock` não é alterado por `flutter pub get`;
- analyze e testes terminam sem falha;
- nenhum secret ou dado pessoal aparece na saída.

### 2.2 Execução DEV em aparelho Android físico

Com os emuladores Firebase ativos no backend:

```powershell
$okanAdb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

& $okanAdb reverse tcp:9099 tcp:9099
& $okanAdb reverse tcp:8080 tcp:8080
& $okanAdb reverse tcp:5001 tcp:5001
& $okanAdb reverse tcp:9199 tcp:9199

flutter run `
  --flavor dev `
  --dart-define=OKAN_ENV=dev `
  --dart-define=OKAN_EMULATOR_HOST=127.0.0.1
```

O app deve exibir `DEV • LOCAL`. Dados criados neste teste devem existir somente nos emuladores.

## 3. Fluxos críticos do baseline

| Fluxo | Estado no baseline | Evidência atual |
|---|---|---|
| Inicialização em DEV | validado | teste manual em aparelho físico |
| Cadastro e login locais | validado | Auth Emulator e app em DEV |
| Convite de aluno | validado | envio e aceite exercitados manualmente |
| Chat professor/aluno | validado | fluxo exercitado manualmente |
| Criar treino | validado | tela e salvamento exercitados manualmente |
| Gestão visual de alunos | validado | lista, vazio e ação de convite revisados |
| Home por persona | validado | PRs 28 e 29, CI e roteiro manual |
| Onboarding | validado | PR 30, CI e roteiro manual |
| Histórico, chat, avaliações e notificações | validado | PRs 32 a 35, CI e roteiros manuais |
| Login incorreto e recuperação de senha | validado | UX-04 concluída na PR 42 com teste manual em DEV |
| Cadastro de aluno e professor com fonte ampliada | validado | UX-04 concluída na PR 42 com teste manual em DEV |
| Treino: editar, reordenar e excluir exercício | validado | PR 46, Flutter CI 113 e roteiro manual aprovado em DEV |
| Matriz integrada da UX-05 | validado | catálogo, templates, treinos, avaliações, vídeo, fonte 200% e TalkBack aprovados no `main` após a PR 50 |
| Offline | validado | cache, rascunho e reconexão automática aprovados em Android físico com emuladores locais |
| Sessão expirada | validado | gate reativo, mensagem segura, Flutter CI 132 e smoke manual aprovados na PR 52 |

“Validado” significa que o fluxo foi exercitado sem regressão conhecida na rodada indicada. Não substitui a matriz completa do release nem autoriza promoção automática para PROD.

## 4. Estados de interface que devem ser preservados

Cada nova comparação deve cobrir, quando aplicável:

- inicial;
- carregando;
- conteúdo;
- vazio;
- erro recuperável com tentativa novamente;
- erro bloqueante;
- sem permissão;
- offline;
- ação em processamento;
- sucesso;
- sessão expirada.

Não registrar exceções, UID, e-mail, senha, token, payload ou dado de saúde nas capturas, nomes de arquivo ou logs.

## 5. Situação consolidada

| Item | Estado | Evidência integrada | Pendência para `done` |
|---|---|---|---|
| UX-01 Baseline | done | baseline do app em aparelho físico e do web em STAGING; fluxos essenciais registrados com dados sintéticos | manter a matriz ampliada como regressão contínua em cada PR visual |
| UX-02 Web STAGING | done | PR web 11, Hosting isolado e smoke autenticado em `okan-staging-24829.web.app` | — |
| UX-03 Tokens | done | paleta e cores semânticas no app (PRs 23 e 37); tokens CSS operacionais no web (PRs web 13 e 14); validações manuais em DEV/STAGING | dívida residual direcionada às UX-04, UX-05 e UX-09 e às páginas estáticas do web |
| UX-04 Auth | done | web aprovado em STAGING na PR web 15; app aprovado em DEV no aparelho físico e integrado pela PR 42 | manter login, cadastro, recuperação e verificação de e-mail na regressão contínua |
| UX-05 Telas antigas | done | PRs 23, 25, 26 e 43 a 50; matriz integrada aprovada em Android físico com dados sintéticos, fonte 200% e TalkBack | manter esses fluxos na regressão contínua |
| UX-06 Dashboard | in progress | PRs web 8, 9 e 10; smoke autenticado executado em STAGING após a PR 11 | concluir a arquitetura do menu móvel e repetir a matriz de acessibilidade em celular e desktop |
| UX-07 Home | done | PRs 28 e 29 | manter cobertura nas próximas regressões |
| UX-08 Onboarding | done | PR 30 | manter cobertura nas próximas regressões |
| UX-09 Estados/acessibilidade | in progress | PRs 31 a 35 e 52 a 55; offline, sessão expirada, Informações Pessoais, Perfil e Assinatura aprovados em DEV | concluir o saguão e a sala do duelo da Arena |
| UX-10 Piloto/rollout | blocked | validações internas pontuais | concluir itens selecionados em STAGING, preparar roteiro, participantes, evidências e métricas |

## 6. Evidências por Pull Request

### Aplicativo

- [PR 23 - tema da criação/edição de treino](https://github.com/arthurcmps/okan_app/pull/23)
- [PR 25 - biblioteca ativa de templates](https://github.com/arthurcmps/okan_app/pull/25)
- [PR 26 - gestão visual de alunos](https://github.com/arthurcmps/okan_app/pull/26)
- [PRs 28 e 29 - hierarquia e ações da home](https://github.com/arthurcmps/okan_app/pull/29)
- [PR 30 - onboarding responsivo](https://github.com/arthurcmps/okan_app/pull/30)
- [PR 31 - estados de modelos/templates](https://github.com/arthurcmps/okan_app/pull/31)
- [PR 32 - estados do histórico](https://github.com/arthurcmps/okan_app/pull/32)
- [PR 33 - estados e envio do chat](https://github.com/arthurcmps/okan_app/pull/33)
- [PR 34 - estados e salvamento das avaliações](https://github.com/arthurcmps/okan_app/pull/34)
- [PR 35 - estados e ações das notificações](https://github.com/arthurcmps/okan_app/pull/35)
- [PR 37 - cores semânticas do produto](https://github.com/arthurcmps/okan_app/pull/37)
- [PR 42 - experiência de login, cadastro e verificação de e-mail](https://github.com/arthurcmps/okan_app/pull/42)
- [PR 43 - gestão visual de modelos de treino](https://github.com/arthurcmps/okan_app/pull/43)
- [PR 44 - administração segura do catálogo global](https://github.com/arthurcmps/okan_app/pull/44)
- [PR 45 - consistência de avaliações, anamnese e anotação privada](https://github.com/arthurcmps/okan_app/pull/45)
- [PR 46 - regressão da criação e edição de treinos](https://github.com/arthurcmps/okan_app/pull/46)
- [PR 47 - avatar compartilhado e acessível](https://github.com/arthurcmps/okan_app/pull/47)
- [PR 48 - página compartilhada de vídeo](https://github.com/arthurcmps/okan_app/pull/48)
- [PR 49 - remoção do player de vídeo sem consumidores](https://github.com/arthurcmps/okan_app/pull/49)
- [PR 50 - ciclo de vida ao adicionar exercício ao template](https://github.com/arthurcmps/okan_app/pull/50)
- [PR 52 - offline e gate reativo de sessão](https://github.com/arthurcmps/okan_app/pull/52)
- [PR 53 - estados de Informações Pessoais](https://github.com/arthurcmps/okan_app/pull/53)
- [PR 54 - estados de Meu Perfil](https://github.com/arthurcmps/okan_app/pull/54)
- [PR 55 - estados de Assinatura e Planos](https://github.com/arthurcmps/okan_app/pull/55)

### Painel web

- [PR 8 - navegação e controles acessíveis](https://github.com/arthurcmps/okan_web/pull/8)
- [PR 9 - tabelas responsivas e detalhes do professor](https://github.com/arthurcmps/okan_web/pull/9)
- [PR 10 - controles de ícone acessíveis](https://github.com/arthurcmps/okan_web/pull/10)
- [PR 11 - ambiente STAGING isolado e fail-closed](https://github.com/arthurcmps/okan_web/pull/11)
- [PR 13 - tokens visuais canônicos do painel](https://github.com/arthurcmps/okan_web/pull/13)
- [PR 14 - cores operacionais HTML/JavaScript convertidas para tokens](https://github.com/arthurcmps/okan_web/pull/14)
- [PR 15 - experiência de login e cadastro das academias](https://github.com/arthurcmps/okan_web/pull/15)

## 7. Encerramento da UX-02

A UX-02 foi validada em 8 de setembro de 2026 e está concluída no escopo do plano visual:

- merge da [PR web 11](https://github.com/arthurcmps/okan_web/pull/11), SHA `687fadddf78a27b39f2bb3dfdea66a005736be95`;
- Hosting isolado em `https://okan-staging-24829.web.app`;
- banner `STAGING • DADOS SINTÉTICOS` visível;
- App Check com reCAPTCHA Enterprise sem novos erros 400/403 no roteiro final;
- cadastro de academia, login, sessão, dashboard e logout validados com dados sintéticos;
- pagamentos externos bloqueados;
- 50 testes automatizados aprovados;
- nenhuma alteração ou implantação realizada em PROD.

A configuração dos secrets do workflow manual de STAGING no GitHub Actions, quando ainda pendente, é melhoria operacional de CI/CD. O caminho manual validado continua explícito e fail-closed e, por isso, essa automação não bloqueia o encerramento funcional da UX-02.

## 8. Encerramento da UX-03

A UX-03 foi concluída em 9 de setembro de 2026 no escopo central do plano visual:

- o Flutter utiliza a paleta Cyber-Sankofa e tokens semânticos protegidos por teste;
- o painel web utiliza a mesma paleta canônica em CSS, HTML e JavaScript operacionais;
- contraste e legibilidade no tema escuro foram cobertos por testes e validações manuais;
- IDs, rotas, handlers, contratos Firebase, backend e pagamentos permaneceram inalterados;
- a segunda onda web foi validada autenticada em STAGING antes do merge da PR 14;
- nenhuma implantação em PROD foi realizada nesta etapa.

Cores locais ainda existentes no app devem ser tratadas dentro da tela responsável nas UX-04, UX-05 ou UX-09, distinguindo cores estruturais como transparência/contraste de cores de ação do produto. As páginas web `privacidade.html` e `404.html` permanecem como dívida estática isolada. Esses itens não desfazem a adoção da paleta canônica e não bloqueiam a próxima fase.

## 9. Encerramento da UX-01

A UX-01 foi concluída em 9 de setembro de 2026 com evidências sanitizadas e dados exclusivamente sintéticos:

- no painel web STAGING: login, cadastro, Minha Academia e assinatura com pagamentos bloqueados;
- no app em aparelho físico: login, cadastro e escolha de persona, Home de aluno, Home de professor, Meus Alunos, criação/edição de treino e estado vazio/erro;
- ausência de credenciais, dados médicos, tokens ou identificadores internos nas evidências;
- comportamento funcional preservado nos fluxos utilizados como baseline;
- nenhuma implantação ou correção direta em PROD.

As capturas ficam sob guarda dos responsáveis do projeto e não são versionadas com credenciais ou dados pessoais. A matriz ampliada por resolução, fonte e teclado permanece como regressão contínua das próximas PRs visuais, sem invalidar o baseline essencial concluído.

## 10. Encerramento da UX-05

A UX-05 foi concluída em 10 de setembro de 2026 com código e validação integrados:

- gestão de modelos e catálogo revisada nas PRs 43 e 44;
- avaliações, anamnese e anotação privada revisadas na PR 45;
- criação e edição de treinos cobertas pela PR 46;
- avatar compartilhado e acessível integrado na PR 47;
- página de vídeo consolidada e dependências mortas removidas nas PRs 48 e 49;
- ciclo de vida catálogo/diálogo de template corrigido e validado na PR 50;
- matriz final aprovada em Android físico com dados sintéticos, incluindo criação,
  edição, remoção, persistência, vídeo, fonte em 200% e TalkBack;
- nenhuma implantação ou alteração direta realizada em PROD.

Offline e sessão expirada permanecem fora deste encerramento e pertencem à
UX-09.

## 11. Próxima ordem segura

1. concluir a auditoria das telas residuais da UX-09;
2. concluir a arquitetura móvel da UX-06 e repetir a matriz mínima em STAGING;
3. iniciar UX-10 somente com os gates anteriores registrados.

A UX-02 removeu o bloqueio de ambiente para o dashboard. Toda próxima mudança estrutural do web ainda deve passar por build, verificação, deploy explícito e smoke autenticado no projeto STAGING antes de qualquer promoção para PROD.

## 12. Matriz de regressão visual da UX-01

O baseline essencial está concluído. Nas próximas PRs visuais, selecionar as linhas pertinentes desta matriz e comparar o mesmo estado antes/depois usando somente dados sintéticos.

| Plataforma | Dimensão/condição | Telas mínimas |
|---|---|---|
| Android pequeno | 360 × 800 | login, cadastro, home, treino, alunos, estado vazio/erro |
| Android comum | 390 × 844 | mesmos fluxos do cenário principal |
| Tablet retrato | 768 × 1024 | login, home e criação/edição de treino |
| Fonte ampliada | 130% e 200% | login, cadastro, home e formulário crítico |
| Teclado aberto | formulário mobile | último campo e CTA continuam acessíveis |

Não incluir credenciais, endereços de e-mail reais, nomes reais, dados médicos ou identificadores internos.

## 13. Rollback documental

Este arquivo não altera execução, dados ou configuração. Se alguma referência estiver incorreta, corrigir o registro em nova PR preservando o histórico; não reescrever evidências de forma silenciosa.
