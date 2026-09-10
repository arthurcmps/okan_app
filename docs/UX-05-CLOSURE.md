# Encerramento da UX-05 — Telas antigas

## Resultado

A UX-05 está concluída no baseline `9b3bbdb`, após a integração da PR 50 e a
aprovação da matriz final em aparelho Android físico.

## Evidências consolidadas

- PR 23: tema da criação e edição de treino;
- PR 25: biblioteca ativa de templates;
- PR 26: gestão visual de alunos;
- PRs 43 e 44: modelos e catálogo global;
- PR 45: avaliações, anamnese e anotação privada;
- PR 46: regressão de criação e edição de treinos;
- PR 47: avatar compartilhado e acessível;
- PRs 48 e 49: player compartilhado e limpeza de dependências;
- PR 50: estabilidade ao adicionar exercícios ao template;
- Flutter CI 126 aprovado;
- matriz integrada aprovada no ambiente DEV local.

## Matriz manual aprovada

- catálogo administrativo: criação, edição e exclusão;
- template de professor: adições consecutivas, valores personalizados, remoção,
  salvamento e reabertura;
- treino: criação, reordenação, exclusão seletiva, edição e proteção contra
  salvamento duplicado;
- avaliação e anamnese: conteúdo longo, rolagem da anotação privada, edição e
  salvamento;
- ficha semanal: reprodução de vídeo e retorno sem perda de estado;
- fonte do Android em 200% nas telas selecionadas;
- TalkBack no avatar e nas ações principais.

Todos os testes utilizaram contas e dados sintéticos. Nenhuma alteração ou
implantação foi realizada em PROD.

## Escopo seguinte

Offline e sessão expirada não fazem parte da UX-05. Esses estados seguem como
lacunas explícitas da UX-09.
