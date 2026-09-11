# UX-09 — Sala do duelo

## Objetivo

Concluir os estados visuais, a acessibilidade e a proteção das ações da sala do
duelo sem alterar contratos do Firebase, regras de negócio ou dados.

## Escopo desta onda

- manter os `Future` e `Stream` da tela estáveis durante rebuilds;
- distinguir carregamento, vazio, erro recuperável e sessão encerrada;
- permitir nova tentativa no placar, mural e comentários;
- não exibir exceções, tokens ou detalhes internos nas mensagens ao usuário;
- bloquear publicação, provocação, reação e comentário duplicados enquanto a
  primeira solicitação estiver em andamento;
- aplicar o token semântico `AppColors.competition` às ações da Arena;
- garantir alvos de toque e rótulos semânticos para reações e botões de ícone;
- preservar a composição em tela pequena e com fonte a 200%.

## Fora do escopo

- mudanças no modelo de duelo, ranking ou amizade;
- alterações em Cloud Functions, regras do Firestore ou Storage;
- migração de dados;
- publicação em STAGING ou PROD;
- arquitetura do menu móvel do painel web, pertencente à UX-06.

## Cobertura automatizada

Arquivo: `test/features/arena/duel_room_states_test.dart`.

1. carregamento e vazio instrutivo do placar;
2. erro seguro e nova tentativa do placar;
3. erro seguro e nova tentativa do mural;
4. bloqueio de publicação de texto duplicada;
5. semântica, alvo mínimo e bloqueio de reação duplicada;
6. erro seguro e nova tentativa dos comentários;
7. tela pequena com fonte a 200%;
8. sessão indisponível.

## Roteiro manual em DEV

Use somente contas e conteúdo sintéticos.

1. Abra um duelo ativo e alterne repetidamente entre **Placar** e
   **Mural 'Tá Pago'**.
2. Confirme que placar, nomes, progresso e provocação continuam visíveis.
3. Toque rapidamente duas vezes em **Provocar** e confirme apenas uma ação.
4. No mural vazio, publique um texto e confirme bloqueio temporário do botão,
   sucesso e limpeza do campo.
5. Em uma publicação, adicione/remova reação e abra os comentários.
6. Envie um comentário e confirme bloqueio temporário e sucesso.
7. Volte ao saguão e reabra o mesmo duelo; não deve haver tela vermelha nem
   erro de stream já escutado.
8. Repita placar, mural e comentários com a fonte do Android em 200%.
9. Com TalkBack, confirme os anúncios de carregamento, erro, nova tentativa,
   publicação de foto/texto, provocação, reação e comentário.

## Critérios para integração

- análise estática e suíte completa aprovadas no CI;
- roteiro manual acima aprovado em Android físico no ambiente DEV;
- nenhuma regressão em amizades, convites ou abertura da Arena;
- nenhuma alteração ou implantação em PROD.

## Rollback

Reverter somente o commit desta onda. Como não há mudança de schema, regras ou
dados, o rollback é restrito à tela e aos testes da sala do duelo.
