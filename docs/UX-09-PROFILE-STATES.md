# UX-09 — Estados de Meu Perfil

## Objetivo

Padronizar os estados visuais e a acessibilidade da tela `Meu Perfil` sem
alterar navegação, contratos Firebase, papéis ou personas.

## Escopo

- carregamento do perfil anunciado para tecnologia assistiva;
- erro de conexão seguro e recuperável com `Tentar novamente`;
- estado explícito quando o documento de perfil não está disponível;
- falhas de foto e data sem exposição de exceções técnicas;
- ação de alterar foto identificada como botão para leitores de tela;
- progresso do upload anunciado como região dinâmica;
- aviso de data ausente identificado como ação;
- cobertura em tela pequena e fonte ampliada.

## Fora do escopo

- backend, Security Rules ou schema de usuário;
- mudança de permissões, papéis ou personas;
- redesign das abas Anamnese e Medidas;
- Assinatura, Arena e demais telas residuais da UX-09;
- implantação em PROD.

## Cobertura automatizada

- carregamento anunciado e conteúdo carregado;
- erro seguro seguido de retry bem-sucedido;
- falha de upload sem vazamento de detalhe técnico;
- layout em `320 × 480` com fonte a 200%.

## Roteiro manual em DEV

1. Abrir `Meu Perfil` e confirmar nome, e-mail, idade, avatar e opções.
2. Abrir `Informações Pessoais` e voltar ao perfil.
3. Alterar a foto pela galeria e confirmar o progresso e a atualização.
4. Cancelar a escolha de foto e confirmar que a tela permanece estável.
5. Aumentar a fonte do Android para 200% e percorrer toda a aba `Conta`.
6. Com TalkBack, confirmar que a câmera anuncia `Alterar foto do perfil` como
   botão.
7. Em conta sem nascimento, confirmar que o aviso anuncia a ação de adicionar
   a data.

Usar exclusivamente conta, imagem e dados sintéticos.
