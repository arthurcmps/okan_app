# UX-05 — Regressão da criação e edição de treinos

## 1. Objetivo

Fechar a validação funcional da tela de criação e edição de treinos sem alterar
o modelo persistido, as regras do Firestore ou o contrato entre aplicativo e
backend.

Esta onda cobre os riscos observados na interface antiga:

- ausência de orientação quando o treino ainda não possui exercícios;
- carregamento indefinido quando a biblioteca falha;
- possibilidade de enviar o salvamento mais de uma vez;
- chaves instáveis durante a reordenação;
- exposição de detalhes técnicos em mensagens de erro;
- ações concorrentes enquanto um salvamento está em andamento.

## 2. Escopo da mudança

Arquivos funcionais:

- `lib/features/workouts/presentation/pages/create_workout_page.dart`;
- `test/features/workouts/create_workout_page_visual_test.dart`.

Comportamentos adicionados ou reforçados:

- estado vazio com orientação para adicionar o primeiro exercício;
- estados de carregamento, vazio e erro recuperável na biblioteca;
- botão **Tentar novamente** após falha ao carregar o catálogo;
- bloqueio de campos, inclusão, remoção, reordenação e novo envio durante o
  salvamento;
- indicador visual enquanto o salvamento está em andamento;
- identificadores estáveis para os exercícios durante a reordenação;
- nome e grupo muscular normalizados com `trim()` antes do envio;
- mensagem segura e compreensível quando o salvamento falha.

## 3. Contratos preservados

Esta implementação não altera:

- nomes de coleções ou documentos do Firestore;
- campos persistidos em `workouts`;
- assinatura de `WorkoutsRepository.saveWorkoutModel`;
- regras do Firestore ou Storage;
- Cloud Functions;
- autenticação, App Check ou configuração de ambientes;
- dados já cadastrados.

O parâmetro opcional `personalId` da página existe apenas como ponto de
injeção determinística para testes. No uso normal, o identificador continua
vindo do usuário autenticado no Firebase Auth.

## 4. Cobertura automatizada

Os testes de widget comprovam:

1. uso das cores semânticas sem alterar os dados do treino;
2. remoção somente do exercício selecionado e exibição do estado vazio;
3. erro seguro da biblioteca e nova assinatura do stream após tentar novamente;
4. inclusão de exercício com séries e repetições;
5. bloqueio de envio duplicado durante salvamento;
6. reordenação, remoção e preservação do ID ao editar;
7. preservação da tela e ocultação de detalhes técnicos quando o salvamento
   falha.

## 5. Roteiro manual em DEV

Usar somente contas e dados sintéticos no projeto `demo-okan-dev`.

### 5.1 Criar treino

1. Entrar com uma conta de professor.
2. Abrir a gestão de treinos e tocar em **Novo treino**.
3. Confirmar a mensagem de treino vazio.
4. Tentar salvar sem nome e confirmar a validação obrigatória.
5. Informar nome e grupo muscular.
6. Adicionar três exercícios da biblioteca.
7. Configurar séries, repetições e uma observação sintética.
8. Reordenar os exercícios arrastando o primeiro para a última posição.
9. Excluir o exercício do meio e confirmar que somente ele desaparece.
10. Salvar e aguardar a confirmação.
11. Reabrir o treino e confirmar nome, grupo, exercícios, ordem e observação.

### 5.2 Editar treino

1. Alterar o nome ou grupo muscular do treino criado.
2. Reordenar os exercícios restantes.
3. Excluir somente um exercício.
4. Salvar, sair e reabrir.
5. Confirmar que o mesmo treino foi atualizado e que nenhum exercício diferente
   foi removido.

### 5.3 Proteção durante o salvamento

1. Tocar em salvar e observar o indicador de processamento.
2. Confirmar que campos e ações ficam indisponíveis até a conclusão.
3. Confirmar que não surgem treinos duplicados.

## 6. Critérios de aprovação

A onda pode ser integrada somente quando:

- `flutter analyze` e toda a suíte `flutter test` estiverem aprovados no CI;
- o roteiro de criação e edição passar em aparelho físico no ambiente DEV;
- não houver documento duplicado após toque repetido em salvar;
- nenhuma exceção, UID, e-mail, token ou payload aparecer para o usuário;
- não houver mudança não planejada no backend ou no Firestore;
- nenhuma implantação em PROD for realizada.

## 7. Rollback

Como a mudança é restrita à apresentação e aos testes, o rollback consiste em
reverter a PR desta onda. Não há migração de dados nem operação de restauração
no Firebase.
