# UX-09 — Estados de Assinatura e Planos

## Objetivo

Padronizar os estados visuais e a acessibilidade da tela `Assinatura e Planos`
sem alterar produtos, preços, pagamentos ou regras do plano.

## Escopo

- carregamento dos planos anunciado para tecnologia assistiva;
- erro de conexão seguro e recuperável com `Tentar novamente`;
- estado explícito quando os dados da assinatura não estão disponíveis;
- solicitação de cancelamento sem exposição de exceções técnicas;
- progresso do cancelamento anunciado como região dinâmica;
- diálogo de cancelamento rolável com fonte ampliada;
- preço e botões adaptáveis a tela pequena e fonte a 200%.

## Fora do escopo

- Mercado Pago, Cloud Functions, produtos, preços ou payloads;
- checkout real, bloqueado no ambiente DEV;
- alteração imediata do plano pelo aplicativo;
- Arena e demais telas residuais da UX-09;
- implantação em PROD.

## Cobertura automatizada

- carregamento anunciado e conteúdo do plano atual;
- erro seguro seguido de retry bem-sucedido;
- falha de cancelamento sem vazamento de detalhe técnico;
- cards e diálogo em `320 × 480` com fonte a 200%.

## Roteiro manual em DEV

1. Entrar como professor e abrir `Perfil > Assinatura e Planos`.
2. Confirmar a exibição do plano atual, dos benefícios e dos preços.
3. Tocar em `ASSINAR AGORA` e confirmar o bloqueio seguro de pagamentos DEV.
4. Em uma conta premium sintética, abrir e fechar o diálogo de cancelamento sem
   confirmar a solicitação.
5. Aumentar a fonte do Android para 200% e percorrer os dois cards.
6. Confirmar que textos, preços e botões permanecem legíveis e acessíveis por
   rolagem, sem cortes ou overflow.

Usar exclusivamente conta e dados sintéticos. Não testar pagamento real.
