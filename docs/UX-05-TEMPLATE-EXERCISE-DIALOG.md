# UX-05 — Ciclo de vida ao adicionar exercício ao template

## 1. Falha encontrada

Na regressão integrada da UX-05, adicionar um exercício do catálogo ao criar um
template de professor podia disparar a asserção `_dependents.isEmpty` durante a
desativação de widgets herdados.

## 2. Causa

O fluxo fechava o `showModalBottomSheet` do catálogo e abria o `showDialog` de
séries e repetições no mesmo callback. Ao concluir o diálogo, controladores de
texto externos eram descartados pelo `whenComplete` durante o ciclo de remoção
da rota.

## 3. Correção

- o catálogo retorna o exercício selecionado como resultado da rota;
- o diálogo abre somente depois que o fechamento do catálogo termina;
- o diálogo retorna uma configuração imutável;
- séries e repetições usam estado local de formulário, sem controladores
  temporários nem descarte manual;
- `mounted` é verificado depois de cada espera assíncrona;
- adições consecutivas são cobertas por teste de widget.

## 4. Contratos preservados

- o catálogo e a seleção de exercícios permanecem iguais;
- os valores iniciais continuam sendo 3 séries e 12 repetições;
- o exercício continua recebendo nome e URL do catálogo;
- nenhuma alteração em repositório, Firebase, permissões ou dados persistidos;
- nenhuma implantação em PROD.

## 5. Validação manual em DEV

1. Entrar com professor sintético e abrir a criação de template.
2. Adicionar um exercício, mantendo 3 séries e 12 repetições.
3. Adicionar um segundo exercício imediatamente.
4. Alterar séries e repetições do segundo e confirmar os valores na lista.
5. Remover um exercício, salvar e reabrir o template.
6. Confirmar ausência da asserção e de tela vermelha em todo o fluxo.

## 6. Gate e rollback

O merge exige Flutter CI verde e validação manual no fluxo reproduzido. O
rollback é a reversão da PR; não há migração de dados nem alteração em PROD.
