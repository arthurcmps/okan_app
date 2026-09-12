# UX-10 - Piloto e rollout controlado

## 1. Objetivo

Validar com pessoas representativas se as melhorias visuais e de experiência do
Okan permitem concluir os fluxos críticos com clareza, acessibilidade e sem
regressões P0/P1 antes de qualquer ampliação em PROD.

Esta etapa não adiciona funcionalidades e não autoriza publicação automática.

## 2. Escopo

Incluído:

- aplicativo Flutter para aluno e professor;
- painel web para gestor e super admin;
- celular Android e navegador desktop;
- login, cadastro, Home, treino, alunos, Arena e dashboard;
- compreensão dos estados de carregamento, vazio, erro e processamento;
- coleta de métricas, observações e satisfação;
- triagem de incidentes e decisão de avançar, corrigir ou interromper.

Fora do escopo:

- pagamentos reais;
- dados pessoais, médicos ou financeiros reais;
- alteração de regras, permissões, schema ou preços durante a sessão;
- correção direta em PROD;
- ensinar o fluxo antes da primeira tentativa;
- registrar credenciais, UID, tokens ou payloads nas evidências.

## 3. Pré-condições obrigatórias

O piloto só começa quando todas as respostas forem `sim`:

- [ ] `okan_app/main` contém o fechamento das UX-01 a UX-09;
- [ ] `okan_web/main` contém a PR 16;
- [ ] backend contém a callable segura do placar da Arena;
- [ ] CI do candidato está verde;
- [ ] não existe regressão P0/P1 conhecida;
- [ ] build móvel do piloto aponta somente para STAGING;
- [ ] painel web aponta somente para `okan-staging-24829`;
- [ ] banner de STAGING está visível no painel;
- [ ] pagamentos externos estão bloqueados;
- [ ] rollback do app e do web está disponível;
- [ ] contas e dados sintéticos foram preparados;
- [ ] participantes receberam orientação de privacidade, sem instrução do fluxo.

Qualquer resposta `não` interrompe o início do piloto.

## 4. Referências candidatas

| Componente | Referência inicial | Condição |
|---|---|---|
| App | `okan_app/main` após PR 59 | gerar candidato de STAGING e registrar SHA/versionCode |
| Web | `okan_web/main` após PR 16 | publicar somente no Hosting STAGING |
| Backend | `okan_backend/main` após PR 22 | validar callable e ambientes antes do piloto |
| Dados | contas sintéticas | nunca copiar dados de PROD |

Os SHAs finais, URLs temporárias e identificadores do build devem ser
registrados sem incluir segredos.

## 5. Participantes

Grupo mínimo:

- 3 a 5 alunos;
- 2 a 3 professores, incluindo o professor parceiro;
- 1 gestor ou responsável de academia;
- Arthur como observador técnico.

Identificadores nas evidências:

- alunos: `A01`, `A02`, ...;
- professores: `P01`, `P02`, ...;
- gestor: `G01`;
- observador: `OBS01`.

Não registrar nome, e-mail, telefone, academia real ou dado de saúde.

## 6. Formato da sessão

- duração sugerida: 30 a 45 minutos;
- uma pessoa por vez;
- aparelho do participante quando possível;
- observador não explica o caminho antes da tentativa;
- se houver bloqueio, registrar o ponto antes de ajudar;
- repetir somente quando necessário para confirmar uma hipótese;
- encerrar imediatamente em caso de P0 ou risco de dado real.

## 7. Matriz mínima

| Plataforma | Condição | Perfis |
|---|---|---|
| Android pequeno | 360 x 800 ou equivalente | aluno e professor |
| Android comum | 390 x 844 ou aparelho físico equivalente | aluno e professor |
| Fonte ampliada | 130% e 200% em fluxos selecionados | aluno e professor |
| Web notebook | 1366 x 768 | gestor e super admin |
| Web mobile | até 360 px | gestor e super admin |
| Teclado | Tab, Shift+Tab, Enter, Espaço e Escape | painel web |

## 8. Roteiro comum

Executar conforme o papel do participante:

1. entrar com credencial sintética;
2. interpretar uma mensagem de login incorreto;
3. localizar recuperação de senha;
4. identificar a ação principal da primeira tela;
5. reconhecer carregamento, vazio ou erro quando apresentado;
6. concluir a tarefa principal sem ajuda;
7. sair e confirmar retorno à entrada.

A recuperação pode usar uma caixa de teste controlada. Não utilizar e-mail
pessoal do participante.

## 9. Roteiro do aluno

1. cadastrar ou acessar uma conta sintética;
2. identificar em até cinco segundos a ação principal da Home;
3. localizar o treino do dia;
4. abrir e consultar o treino;
5. navegar pelo histórico;
6. enviar ou aceitar um convite de amizade;
7. localizar o amigo na Arena;
8. criar ou abrir um duelo;
9. consultar o placar e retornar ao saguão;
10. abrir notificações e seguir uma ação disponível.

## 10. Roteiro do professor

1. cadastrar ou acessar uma conta sintética;
2. identificar em até cinco segundos a ação principal da Home;
3. localizar Meus Alunos;
4. convidar ou localizar um aluno sintético;
5. criar um treino com pelo menos três exercícios;
6. reordenar, excluir somente o exercício intermediário e salvar;
7. reabrir e editar o treino;
8. criar ou editar um template;
9. abrir avaliação/anamnese e conferir conteúdo longo;
10. validar vídeo e retorno à ficha quando houver link sintético.

## 11. Roteiro do gestor e super admin

### Gestor

1. entrar no painel STAGING;
2. confirmar somente Minha Academia, Assinatura e Mais no mobile;
3. localizar dados sintéticos da academia;
4. localizar professores e licenças;
5. abrir e fechar os modais necessários;
6. confirmar que pagamentos reais permanecem indisponíveis;
7. sair pelo painel Mais.

### Super admin

1. entrar no painel STAGING em até 360 px;
2. navegar por Início, Academias, Professores e Loja;
3. usar Feedback Beta e Sair pelo painel Mais;
4. repetir com teclado;
5. repetir em 1366 x 768;
6. confirmar ausência de opções indevidas, rolagem horizontal e sobreposição.

## 12. Métricas e metas

| Métrica | Meta |
|---|---|
| Fluxos críticos concluídos sem ajuda | pelo menos 90% |
| Identificação da ação principal da Home | até 5 segundos |
| Participantes que compreendem erro e próxima ação | pelo menos 80% |
| Satisfação visual após a tarefa | média mínima 4/5 |
| Regressões críticas P0/P1 | zero |
| Incidentes com dados de PROD em STAGING | zero |

Cálculo de conclusão sem ajuda:

`tarefas concluídas sem ajuda / tarefas válidas executadas x 100`

Tarefas interrompidas por falha do ambiente devem ser registradas separadamente
e não apagadas do relatório.

## 13. Registro por tarefa

| Campo | Preenchimento |
|---|---|
| Participante | código anônimo |
| Papel | aluno, professor, gestor ou super admin |
| Dispositivo | classe e dimensão, sem identificador pessoal |
| Tarefa | código ou descrição curta |
| Resultado | concluiu sem ajuda, com ajuda, não concluiu ou ambiente bloqueou |
| Tempo | segundos ou minutos |
| Dúvida observada | resumo sem dado pessoal |
| Severidade | P0, P1, P2 ou P3 |
| Evidência | captura sanitizada ou anotação |
| Próxima ação | avançar, corrigir, investigar ou interromper |

## 14. Perguntas pós-tarefa

1. O que você esperava que acontecesse?
2. O que ficou mais fácil de entender?
3. Em que momento você ficou em dúvida?
4. A mensagem de erro explicou o que fazer?
5. O visual parece fazer parte do mesmo produto no app e no painel?
6. De 1 a 5, qual sua satisfação visual?
7. Qual seria a primeira melhoria que você pediria?

Não transformar a sessão em demonstração ou defesa da solução.

## 15. Severidade e resposta

| Nível | Critério | Resposta |
|---|---|---|
| P0 | impede login, segurança ou ação principal; risco de PROD | interromper piloto e iniciar rollback |
| P1 | função importante inacessível para dispositivo ou papel | bloquear rollout e corrigir |
| P2 | legibilidade ou feedback prejudicado com alternativa | corrigir antes da próxima rodada |
| P3 | acabamento sem perda de compreensão | registrar no backlog |

Divergência de opinião estética sem prejuízo de uso não deve ser classificada
automaticamente como P1/P2.

## 16. Regras de interrupção

Interromper imediatamente quando:

- o app ou painel apontar para PROD;
- pagamento externo puder ser iniciado;
- surgir credencial, token, UID ou dado sensível na interface/log;
- login ou ação principal ficar indisponível;
- o papel visualizar uma seção não autorizada;
- ocorrer perda ou escrita incorreta de dados;
- uma regressão impedir a continuação segura.

## 17. Correções encontradas

Cada correção deve:

1. receber ticket próprio;
2. ter severidade e passos reproduzíveis;
3. usar uma branch pequena;
4. preservar os contratos já validados;
5. receber teste automatizado quando aplicável;
6. passar novamente pelo ambiente seguro;
7. repetir somente as tarefas impactadas e a regressão essencial;
8. não ser corrigida diretamente em PROD.

## 18. Rollback

### Web

- registrar SHA e versão do Hosting antes do piloto;
- restaurar a versão anterior do canal se houver regressão;
- confirmar login, navegação, papéis e operação afetada.

### App

- interromper o rollout ou distribuição do candidato;
- manter a versão anterior disponível;
- corrigir a partir do último SHA estável;
- incrementar `versionCode` para um novo artefato;
- repetir CI e smoke antes de redistribuir.

Um AAB publicado não pode ser substituído pelo mesmo `versionCode`.

## 19. Decisão após a rodada

### Avançar

Somente quando:

- todas as metas mínimas forem alcançadas;
- não houver P0/P1;
- incidentes P2 selecionados estiverem corrigidos ou aceitos formalmente;
- evidências estiverem sanitizadas;
- responsáveis aprovarem o resultado.

### Corrigir e repetir

Quando houver P1, meta essencial abaixo do limite ou dúvida reproduzível em
fluxo crítico.

### Interromper

Quando houver risco de segurança, contato com PROD, perda de dados ou ausência
de rollback confiável.

## 20. Rollout gradual proposto

1. concluir o piloto fechado;
2. corrigir bloqueadores e repetir a regressão;
3. gerar artefato final com novo `versionCode`;
4. iniciar exposição mínima permitida pelo canal;
5. observar erros e feedback antes de ampliar;
6. pausar imediatamente diante de P0/P1;
7. ampliar por etapas somente com os gates verdes;
8. registrar revisão pós-release e aprendizados.

Os percentuais e intervalos serão definidos antes do rollout conforme o canal
disponível e o tamanho real da audiência. Este roteiro não autoriza publicação.

## 21. Checklist de encerramento da UX-10

- [ ] participantes mínimos concluíram as tarefas;
- [ ] matriz de celular e desktop foi exercitada;
- [ ] metas foram calculadas;
- [ ] feedback qualitativo foi consolidado;
- [ ] nenhum dado real apareceu nas evidências;
- [ ] zero incidente com PROD;
- [ ] zero P0/P1 aberto;
- [ ] correções necessárias foram integradas e revalidadas;
- [ ] decisão de rollout foi registrada;
- [ ] rollout gradual, se autorizado, foi acompanhado;
- [ ] revisão pós-release foi registrada.

A UX-10 só pode mudar para `done` após todos os itens aplicáveis serem
comprovados.
