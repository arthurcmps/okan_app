# UX-05 — Gestão visual de modelos de treino

## 1. Objetivo

Melhorar a leitura e as ações da tela **Meus Modelos**, especialmente em
celulares estreitos e com fonte ampliada, sem alterar persistência, ownership ou
contratos do repositório de treinos.

Esta é uma onda pequena da UX-05. A criação e edição interna dos exercícios
permanece em uma entrega separada.

## 2. Mudanças

- card responsivo com nome, grupo muscular e quantidade de exercícios;
- ações textuais **Editar** e **Excluir**, que podem quebrar linha sem comprimir o
  conteúdo;
- estado de exclusão visível e com ações bloqueadas contra toque duplicado;
- confirmação destrutiva com cor semântica de erro;
- cores locais azul, verde e vermelho substituídas pelo `ColorScheme`;
- ação única **Novo modelo**, disponível inclusive no estado vazio;
- espaço inferior para impedir sobreposição entre o último card e a ação
  flutuante;
- singular e plural corretos para a quantidade de exercícios.

## 3. Contratos preservados

Permanecem inalterados:

- `WorkoutsRepository.watchWorkoutModels`;
- `WorkoutsRepository.deleteWorkoutModel`;
- navegação para `CreateWorkoutPage` com o mesmo `treinoId` e mapa de dados;
- `nome`, `grupoMuscular` e `exercicios` do modelo;
- confirmação antes da exclusão;
- mensagens sanitizadas em caso de falha;
- implementação Firebase fora da camada de apresentação.

Não fazem parte desta onda:

- reordenar ou editar campos de um exercício;
- mudar collections, Rules ou Functions;
- migrar templates/exercícios legados;
- modificar autenticação, pagamentos ou ambientes;
- publicar em PROD ou na Play Store.

## 4. Testes automatizados

`test/features/workouts/workout_model_list_visual_test.dart` cobre:

- conteúdo completo e callbacks de editar/excluir;
- tokens semânticos do card;
- tela 320 × 480 com fonte em 200%;
- singular/plural da quantidade;
- bloqueio e indicador durante exclusão;
- estado vazio instrutivo sem ação duplicada.

## 5. Validação manual em DEV

Usar aparelho físico, flavor `dev`, Firebase Emulator Suite e dados sintéticos:

1. abrir **Meus Modelos** sem registros e localizar **Novo modelo**;
2. criar modelos com nomes curto e longo;
3. confirmar que o último card não fica coberto pelo botão;
4. abrir a edição e voltar sem salvar;
5. cancelar uma exclusão;
6. confirmar uma exclusão e observar o estado de processamento;
7. repetir em fonte padrão e ampliada;
8. confirmar que erros não exibem detalhes técnicos.

## 6. Gate e rollback

O merge exige Flutter CI aprovada e validação manual em DEV. O rollback consiste
em reverter a PR; não há migração, alteração de dados ou mudança de ambiente.
