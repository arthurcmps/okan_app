# UX-05 — Avatar compartilhado

## 1. Objetivo

Concluir uma primeira onda pequena da auditoria de widgets compartilhados,
alinhando o avatar usado por Home, Chat, Arena, alunos e perfil à identidade
Cyber-Sankofa e à semântica de acessibilidade do aplicativo.

## 2. Escopo

- substituir azul e cinza locais por cores do `ColorScheme`;
- normalizar espaços do nome e da URL antes de renderizar;
- manter a inicial como fallback quando não há foto ou o carregamento falha;
- descrever avatar estático como imagem para tecnologias assistivas;
- descrever avatar interativo como ação de abrir perfil;
- oferecer tooltip para a ação interativa;
- preservar tamanho, foto, fallback e callback existentes.

## 3. Contratos preservados

Esta onda não altera:

- assinatura pública de `UserAvatar`;
- callbacks ou destinos de navegação;
- carregamento da foto com `CachedNetworkImage`;
- Firebase Auth, Storage, Firestore ou Functions;
- dados persistidos;
- regras de permissão;
- qualquer configuração ou implantação em PROD.

## 4. Cobertura automatizada

Os testes comprovam:

- inicial normalizada quando o nome possui espaços;
- uso das cores semânticas do tema;
- descrição acessível do avatar estático;
- descrição, tooltip e execução do avatar interativo;
- fallback seguro para nome vazio.

## 5. Validação manual em DEV

Usar somente contas e dados sintéticos no projeto `demo-okan-dev`.

1. Abrir a Home e confirmar que o avatar mantém foto ou inicial.
2. Tocar no avatar da Home e confirmar a abertura do perfil.
3. Abrir Chat, Meus Alunos e Arena e confirmar que os avatares não deformam.
4. Conferir um nome sem foto e confirmar inicial legível.
5. Aumentar a fonte do Android para 200% e confirmar que os avatares e listas
   mantêm alinhamento.
6. Com TalkBack, focar o avatar interativo da Home e confirmar o anúncio da ação
   de abrir perfil.

Não registrar nome real, foto real, e-mail, UID, senha ou token nas evidências.

## 6. Gate e rollback

O merge exige Flutter CI verde e validação manual focal em DEV. Não haverá
deploy em PROD. O rollback é a reversão da PR; não há migração de dados.
