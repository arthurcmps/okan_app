# UX-05 — Consistência visual de avaliações e anamnese

## 1. Objetivo

Concluir uma onda pequena das telas antigas de avaliações, melhorando
responsividade, estados e segurança da interação sem mudar collections,
repositories, permissões ou o formato persistido dos dados.

## 2. Escopo

- formulário de nova avaliação adaptável a largura estreita e fonte ampliada;
- linhas de detalhes capazes de quebrar texto sem overflow;
- ação principal usando o token `primary` e sucesso usando `success`;
- carregamento e erro recuperável da anamnese com tentativa novamente;
- bloqueio contra salvamento duplicado da anamnese;
- remoção da ação de salvar quando a ficha é aberta em modo somente leitura;
- estados de carregamento e erro das anotações privadas;
- bloqueio da edição de anotações enquanto o salvamento está em andamento;
- mensagens seguras, sem exceção, UID, token ou payload técnico.

## 3. Contratos preservados

- `AssessmentsRepository` não foi alterado;
- os paths `medical/anamnese`, `assessments` e `private_notes` permanecem iguais;
- nenhum campo foi adicionado, removido ou renomeado;
- as decisões de leitura e escrita continuam nas Firestore Rules e no repository;
- nenhuma alteração foi feita em Functions, Auth, App Check ou pagamentos.

## 4. Testes automatizados

- erro de carregamento da anamnese é sanitizado e permite nova tentativa;
- modo somente leitura não oferece a ação de salvar;
- toques repetidos não iniciam duas gravações da anamnese;
- tela estreita com fonte em 200% não apresenta overflow;
- pares de campos da avaliação são empilhados quando o espaço é insuficiente;
- detalhes da avaliação quebram texto com segurança;
- erro das anotações privadas é sanitizado e permite nova tentativa;
- anotação fica bloqueada durante o salvamento.

## 5. Validação manual em DEV

Usar exclusivamente `demo-okan-dev`, Emulator Suite, contas sintéticas e
aparelho Android físico:

1. como aluno, abrir **Perfil → Anamnese**;
2. expandir seções, preencher um campo e salvar;
3. tocar rapidamente duas vezes em salvar e confirmar apenas um processamento;
4. fechar e reabrir a ficha, confirmando persistência;
5. como professor vinculado, abrir o aluno e acessar **Anamnese**;
6. confirmar que a ficha do aluno está somente para leitura e não possui botão
   de salvar;
7. editar e salvar uma anotação privada do personal;
8. abrir **Avaliações**, cadastrar peso e altura e salvar;
9. expandir a avaliação salva e conferir os detalhes;
10. repetir os pontos principais com fonte do Android ampliada, verificando que
    campos, textos e botões continuam acessíveis.

Não registrar nas evidências nomes reais, medidas corporais reais, informações
de saúde, e-mail, UID, senha ou token.

## 6. Gate e rollback

O merge exige Flutter CI verde e validação manual em DEV. Não haverá deploy em
PROD. O rollback é a reversão da PR; não há migração de dados associada.
