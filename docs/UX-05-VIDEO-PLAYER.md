# UX-05 — Página compartilhada de vídeo

## 1. Objetivo

Continuar a auditoria de widgets compartilhados consolidando a página de vídeo
usada pelos treinos em `core`, com estado inválido acessível e sem alterar o
contrato de navegação.

## 2. Escopo

- usar uma única `VideoPlayerPage` compartilhada;
- remover a cópia indevidamente localizada dentro da feature de autenticação;
- normalizar URL e nome do exercício antes da renderização;
- manter reprodução automática, repetição e controles existentes para links do
  YouTube válidos;
- apresentar estado explícito para link vazio, inválido ou não suportado;
- anunciar esse estado como região viva para tecnologias assistivas;
- proteger títulos longos ou vazios na barra superior;
- usar a cor primária do tema no progresso do vídeo.

O `UniversalVideoPlayer`, que também aceita links diretos, não possui consumidor
no código atual e permanece fora desta onda. Sua remoção ou ativação exige uma
decisão funcional separada.

## 3. Contratos preservados

Esta onda não altera:

- parâmetros públicos `videoUrl` e `exerciseName`;
- destino acionado pelo botão de vídeo da ficha semanal;
- autoplay, repetição ou controles do YouTube;
- Firebase Auth, Storage, Firestore ou Functions;
- dados persistidos ou regras de permissão;
- qualquer configuração ou implantação em PROD.

## 4. Cobertura automatizada

Os testes comprovam:

- extração do ID em URL válida com espaços externos;
- rejeição segura de URL vazia ou não suportada;
- mensagem, ícone e anúncio acessível do estado inválido;
- normalização do nome do exercício;
- fallback seguro quando o nome está vazio.

## 5. Validação manual em DEV

Usar somente contas e dados sintéticos no projeto `demo-okan-dev`.

1. Abrir uma ficha que possua exercício com link válido do YouTube.
2. Tocar em `Vídeo` e confirmar título, abertura e reprodução.
3. Pausar, reproduzir, avançar e voltar usando os controles disponíveis.
4. Voltar para a ficha e confirmar que dia e exercícios permanecem intactos.
5. Abrir um exercício sintético com link inválido e confirmar o estado de erro.
6. Aumentar a fonte do Android para 200% e confirmar que título e erro não
   transbordam.
7. Com TalkBack, confirmar o anúncio do erro para um link inválido.

Não registrar URL privada, nome real, e-mail, UID, senha ou token nas evidências.

## 6. Gate e rollback

O merge exige Flutter CI verde e validação manual focal em DEV. Não haverá
deploy em PROD. O rollback é a reversão da PR; não há migração de dados.
