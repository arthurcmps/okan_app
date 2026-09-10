# UX-09 — Estados de Informações Pessoais

## Objetivo

Padronizar os estados visuais da tela de informações pessoais sem alterar o
contrato Firebase, o schema de usuário ou as regras de autenticação.

## Escopo

- carregamento inicial anunciado para tecnologia assistiva;
- erro de carregamento seguro e recuperável com `Tentar novamente`;
- feedback de salvamento sem expor exceções do Firebase;
- troca de senha com mensagens seguras e proteção contra envio duplicado;
- diálogo de senha rolável em tela pequena e com fonte ampliada;
- seletor de data identificado como ação para leitores de tela;
- injeções limitadas aos testes para validar os estados sem Firebase real.

## Fora do escopo

- backend, Security Rules ou schema;
- alteração dos campos salvos;
- política de senha do Firebase;
- perfil, assinatura, Arena ou outras telas residuais da UX-09;
- qualquer implantação em PROD.

## Cobertura automatizada

- carregamento e conteúdo;
- falha recuperável seguida de retry bem-sucedido;
- falha de salvamento sem vazamento de detalhe técnico;
- diálogo de senha em `320 × 480` e fonte a 200%.

## Roteiro manual em DEV

1. Abrir `Perfil` e `Informações Pessoais`.
2. Confirmar carregamento e preenchimento dos dados existentes.
3. Alterar data e identidade de gênero, salvar e reabrir.
4. Validar senha divergente e senha com menos de seis caracteres.
5. Aumentar a fonte do Android para 200% e abrir o diálogo de senha.
6. Com TalkBack, confirmar o anúncio da ação de selecionar/alterar data.

Usar exclusivamente conta e dados sintéticos.
