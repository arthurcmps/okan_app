# UX-05 — Limpeza do player de vídeo sem consumidores

## 1. Objetivo

Encerrar a dívida identificada na auditoria de vídeo removendo o
`UniversalVideoPlayer` sem consumidores e as dependências diretas usadas apenas
por ele.

## 2. Evidência da decisão

A busca integral em `lib` e `test` comprovou que:

- `UniversalVideoPlayer` aparece somente na própria declaração;
- `chewie` é importado somente por esse widget;
- `video_player` é importado somente por esse widget;
- a ficha semanal usa a `VideoPlayerPage` canônica e
  `youtube_player_flutter`.

Manter o widget não habilitaria links diretos no produto, pois nenhuma rota ou
ação o instancia. A remoção reduz código morto e dependências sem retirar uma
capacidade acessível ao usuário.

## 3. Escopo

- remover `lib/core/widgets/universal_video_player.dart`;
- remover `chewie` e `video_player` das dependências diretas;
- regenerar `pubspec.lock` com Flutter 3.47;
- preservar `youtube_player_flutter` e a página validada na PR 48.

## 4. Contratos preservados

Esta onda não altera:

- abertura ou reprodução de vídeos do YouTube;
- parâmetros de `VideoPlayerPage`;
- ficha semanal, treinos ou catálogo;
- Firebase Auth, Storage, Firestore ou Functions;
- dados persistidos ou regras de permissão;
- qualquer configuração ou implantação em PROD.

## 5. Validação

O CI deve comprovar:

- `flutter pub get` sem alteração posterior do lockfile versionado;
- análise estática aprovada;
- suíte completa aprovada;
- ausência de referências a `UniversalVideoPlayer`, `chewie` ou
  `package:video_player`.

No aparelho Android em DEV, abrir novamente um vídeo válido do YouTube, testar
pausa e retorno à ficha. Não é necessário repetir o estado inválido, pois seu
código e sua dependência permanecem inalterados.

## 6. Gate e rollback

O merge exige Flutter CI verde e smoke focal em DEV. Não haverá deploy em PROD.
O rollback é a reversão da PR; não há migração de dados.
