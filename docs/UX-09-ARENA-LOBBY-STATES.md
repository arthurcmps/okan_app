# UX-09 — Estados do Saguão da Arena

## Objetivo

Padronizar os estados visuais e a acessibilidade do saguão da Arena sem
alterar amizades, convites, duelos, ranking ou contratos Firebase.

## Escopo

- carregamento de duelos, amigos e convites anunciado para tecnologia
  assistiva;
- erros de conexão seguros e recuperáveis com `Tentar novamente`;
- estados vazios instrutivos para duelos e amigos;
- sessão ausente apresentada explicitamente;
- busca e envio de pedido com progresso anunciado e sem exposição de exceções;
- ações de convite e remoção identificadas para leitores de tela;
- diálogos de saída e remoção roláveis com fonte ampliada;
- busca adaptável a tela pequena e fonte a 200%;
- streams preservados durante troca de abas e mudanças de estado locais.

## Fora do escopo

- regras, coleções, índices ou Security Rules da Arena;
- ranking, mural, posts, comentários e reações dentro da sala do duelo;
- backend, notificações ou Storage;
- implantação em PROD.

## Cobertura automatizada

- carregamento anunciado e estado vazio de duelos;
- erro seguro seguido de nova tentativa;
- estado vazio de amigos com atalho para busca;
- falha de busca sem vazamento de detalhe técnico;
- sessão ausente explícita;
- saguão em `320 × 480` com fonte a 200%.

## Roteiro manual em DEV

1. Abrir a Arena e percorrer `Duelos`, `Meus Amigos`, `Buscar` e `Convites`.
2. Confirmar os estados vazios de duelos, amigos e convites quando aplicável.
3. Buscar um atleta sintético pelo e-mail e enviar um pedido de amizade.
4. Aceitar ou recusar o pedido na outra conta sintética.
5. Abrir e fechar os diálogos de remover amigo e abandonar duelo sem confirmar.
6. Abrir `NOVO DUELO`, selecionar um amigo e fechar sem criar o duelo.
7. Aumentar a fonte do Android para 200% e repetir a navegação pelas quatro
   abas, pela busca e pelos diálogos.
8. Com TalkBack, confirmar os anúncios de busca e os rótulos de aceitar,
   recusar, remover e abandonar.

Usar exclusivamente contas e dados sintéticos. Não criar conteúdo em PROD.
