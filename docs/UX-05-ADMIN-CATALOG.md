# UX-05 — Administração do catálogo de exercícios

## 1. Objetivo

Oferecer ao super admin uma forma explícita, simples e segura de manter o
catálogo global `exercises`, sem ampliar as permissões de professores e sem
alterar Rules, Functions ou contratos usados por templates e treinos.

## 2. Autorização preservada

- super admin: consulta, cria, edita e exclui exercícios;
- professor: consulta o catálogo para montar templates, sem ações de escrita;
- demais usuários autenticados: leitura conforme o contrato atual;
- a interface nunca substitui as Firestore Rules como autoridade;
- não há e-mail privilegiado, gesto oculto ou permissão baseada apenas na tela.

O acesso aparece no perfil como **Administrar Catálogo** quando
`role=super_admin`. Um super admin sem persona professor abre somente o catálogo;
um super admin com persona professor também preserva a aba de templates pessoais.

## 3. Experiência administrativa

- busca por nome ou grupo muscular;
- filtro pelos grupos existentes;
- contador de resultados e limpeza de filtros;
- cards responsivos com nome, grupo e disponibilidade de vídeo;
- ações textuais **Editar** e **Excluir**;
- formulário com nome e grupo obrigatórios;
- link de vídeo opcional, aceitando apenas HTTP ou HTTPS válido;
- bloqueio de nome duplicado, ignorando caixa e espaços repetidos;
- limites de tamanho nos campos;
- feedback de sucesso e erros sanitizados;
- ações bloqueadas durante salvamento ou exclusão;
- estado vazio e estado sem resultado explícitos.

## 4. Exclusão e integridade

Os contratos atuais guardam uma cópia do exercício dentro de templates e
treinos. Excluir `exercises/{exerciseId}` remove apenas a opção do catálogo e não
apaga exercícios já copiados para documentos existentes. A confirmação explica
esse comportamento antes da ação.

Não é possível calcular com segurança a quantidade de usos enquanto documentos
legados identificarem exercícios principalmente pelo nome. Um contador confiável
fica condicionado ao OKAN-024, com ID canônico de exercício e estratégia de
referência definida no modelo de dados.

## 5. Persistência

Collection preservada: `exercises`.

| Campo | Criação | Edição |
|---|---|---|
| `nome` | obrigatório | atualizável |
| `grupo` | obrigatório | atualizável |
| `videoUrl` | opcional | atualizável |
| `criadoEm` | timestamp do servidor | preservado |
| `atualizadoEm` | ausente | timestamp do servidor |

Nenhuma migração é necessária. Registros anteriores sem `atualizadoEm`
continuam válidos.

## 6. Testes automatizados

- professor não recebe controles administrativos;
- super admin recebe acesso explícito e modo somente catálogo;
- busca, filtro, contador e limpeza de filtros;
- edição e exclusão acionam o exercício correto;
- duplicidade é bloqueada antes do repositório;
- falhas não fecham o formulário nem exibem detalhes internos;
- tela estreita com fonte ampliada não gera overflow.

## 7. Validação manual em DEV

Usar exclusivamente `demo-okan-dev`, Emulator Suite, conta sintética e aparelho
Android físico:

1. entrar como super admin sintético;
2. abrir **Perfil → Administrar Catálogo**;
3. buscar e filtrar os oito exercícios de fixture;
4. tentar cadastrar nome duplicado e confirmar o bloqueio;
5. cadastrar exercício com nome, grupo e link opcional;
6. sair e reabrir a tela, confirmando persistência;
7. editar o exercício e confirmar a atualização;
8. cancelar uma exclusão;
9. confirmar a exclusão e verificar que o item sai do catálogo;
10. entrar como professor e confirmar o modo somente leitura;
11. repetir os estados principais com fonte ampliada.

## 8. Gate e rollback

O merge exige Flutter CI verde e validação manual em DEV. Não haverá deploy em
PROD. O rollback é a reversão da PR; não há migração de dados associada.
