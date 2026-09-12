# UX-10 — candidato STAGING

## 1. Objetivo

Gerar e validar o primeiro candidato fechado do piloto UX-10 sem publicar em
PROD, sem copiar dados reais e sem incluir configuração Firebase no repositório.

Identificador inicial: **ux10-rc1**.

## 2. Baseline obrigatório

| Componente | Baseline | Situação esperada |
|---|---|---|
| App | okan_app/main após PR 60 | UX-01 a UX-09 encerradas |
| Web | okan_web/main após PR 16 | navegação móvel validada em STAGING |
| Backend | okan_backend/main após PR 22 | getArenaRanking disponível para deploy |
| Versão móvel | 1.0.1+10 | piloto fechado, sem promoção à Play Store |

Registrar o SHA exato de cada repositório antes do primeiro teste.

## 3. Atualizar somente a callable do placar em STAGING

A PR backend 22 foi validada localmente e integrada, mas o piloto exige confirmar
que a callable também está implantada no projeto STAGING.

No okan_backend, com a árvore limpa e sincronizada:

    cd C:\Users\Public\Documents\Projetos\Academia\okan_backend
    git status --short
    git switch main
    git pull --ff-only
    $env:OKAN_STAGING_PROJECT_ID = "okan-staging-24829"
    npm.cmd ci
    npm.cmd run staging:verify
    Push-Location .\functions
    npm.cmd run lint
    npm.cmd test
    Pop-Location
    npm.cmd run staging:firebase -- deploy --only functions:getArenaRanking

O comando deve mostrar exclusivamente okan-staging-24829. Pare se aparecer
outro project ID ou se a árvore contiver alterações não identificadas.

Depois do deploy, confirme no console Firebase STAGING que getArenaRanking
existe em southamerica-east1. Não fazer deploy amplo de Functions e não implantar
pagamentos, assinaturas, push ou triggers automáticos.

## 4. Preparar a configuração local do app

O repositório contém somente um modelo sem API keys:

    cd C:\Users\Public\Documents\Projetos\Academia\okan_app
    Copy-Item .\config\staging.example.json .\config\staging.local.json
    notepad .\config\staging.local.json

Preencha as três API keys usando apenas a configuração do projeto
okan-staging-24829. O arquivo config/staging.local.json está protegido pelo
.gitignore.

Não enviar esse arquivo por chat, não anexá-lo a evidências e não versioná-lo.

Verificação local:

    git check-ignore -v .\config\staging.local.json
    git status --short

O primeiro comando deve apontar para a regra /config/*.local.json, e o arquivo
local não deve aparecer no status.

## 5. Gerar o APK fechado do piloto

Com o app sincronizado no SHA aprovado:

    flutter pub get
    flutter analyze --no-fatal-infos --no-fatal-warnings
    flutter test
    flutter build apk --debug --flavor staging --dart-define=OKAN_ENV=staging --dart-define-from-file=.\config\staging.local.json
    Get-FileHash .\build\app\outputs\flutter-apk\app-staging-debug.apk -Algorithm SHA256
    git rev-parse HEAD

Registrar no controle do piloto:

- identificador ux10-rc1;
- SHA do app;
- versão 1.0.1+10;
- hash SHA-256 do APK;
- data e responsável pela geração;
- resultado do analyzer e da suíte.

Não registrar API keys, token App Check, credenciais, UID ou payload.

## 6. Instalação no aparelho de teste

O flavor STAGING usa atualmente o mesmo application ID de PROD. Por isso, o APK
debug pode não instalar sobre a versão da Play Store por diferença de assinatura.

Use somente um aparelho de teste. Se a versão PROD estiver instalada, confirme
que não existe dado local necessário e desinstale-a pelas configurações do
Android antes de instalar o candidato. A desinstalação apaga os dados locais do
aplicativo.

Instalação do candidato:

    $okanAdb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    & $okanAdb devices
    & $okanAdb install .\build\app\outputs\flutter-apk\app-staging-debug.apk

Se o App Check solicitar um novo debug token, registre-o somente no aplicativo
Android do projeto STAGING e trate o token como credencial operacional.

## 7. Smoke técnico antes dos participantes

Executar com contas e dados sintéticos:

1. confirmar o título Okan [STAGING] e o banner STAGING;
2. criar uma conta e autenticar;
3. abrir Perfil e Home;
4. confirmar leitura e gravação permitidas;
5. confirmar uma negação esperada das Rules;
6. enviar e aceitar convite de amizade;
7. abrir a Arena, localizar o amigo e criar ou abrir um duelo;
8. carregar o placar por getArenaRanking;
9. validar upload em caminho permitido;
10. confirmar que pagamentos externos permanecem indisponíveis;
11. confirmar no console STAGING que nenhuma escrita apareceu em PROD.

Qualquer P0/P1, acesso a PROD ou exposição de dado sensível interrompe o
candidato.

## 8. Web do piloto

A PR web 16 já possui smoke autenticado aprovado em STAGING para gestor e super
admin, em 360 px, teclado e 1366 × 768. Antes da primeira sessão, reabrir o
endereço STAGING e confirmar:

- banner STAGING;
- login com conta sintética;
- quatro destinos principais e painel Mais;
- ausência de pagamento real;
- ausência de rolagem horizontal ou sobreposição.

Não promover o Hosting para PROD.

## 9. Evidência mínima

Preencher Okan_UX10_Piloto.xlsx:

- aba Participantes: confirmar os códigos anônimos;
- aba Resultados: registrar cada tarefa e tempo;
- aba Incidentes: registrar qualquer P0–P3;
- aba Resumo: marcar todas as pré-condições e revisar o gate calculado.

## 10. Rollback

### App

- interromper a distribuição do APK;
- desinstalar o candidato do aparelho de teste;
- reinstalar a versão pública somente pela Play Store;
- corrigir a partir do último SHA estável;
- gerar novo candidato e novo hash.

### Backend

Se getArenaRanking apresentar regressão, interromper o fluxo da Arena no piloto
e corrigir em nova PR. Não substituir por leitura direta do histórico dos amigos
e não alterar PROD.

### Web

Restaurar a versão anterior do canal STAGING e repetir login, RBAC e navegação.

## 11. Gate para iniciar o piloto

O piloto com participantes começa somente quando:

- [ ] getArenaRanking está implantada e validada em STAGING;
- [ ] configuração local está ignorada pelo Git;
- [ ] analyzer e testes estão verdes;
- [ ] APK possui SHA e hash registrados;
- [ ] banner e project ID STAGING foram confirmados;
- [ ] pagamentos externos estão bloqueados;
- [ ] smoke técnico completo passou;
- [ ] participantes mínimos estão confirmados;
- [ ] a planilha de coleta está pronta.

Este roteiro não autoriza publicação em PROD nem rollout na Play Store.
