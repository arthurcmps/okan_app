# UX-04 — Autenticação no aplicativo Flutter

## 1. Objetivo

Melhorar a clareza, a responsividade e a acessibilidade das telas de login,
cadastro e verificação de e-mail sem alterar contratos do Firebase Auth, do
Firestore ou do modelo canônico User v2.

## 2. Escopo

- estrutura rolável e com largura máxima para celular e tablet;
- suporte a teclado aberto e texto ampliado;
- preenchimento automático e ações de teclado apropriadas;
- controles acessíveis para mostrar e ocultar senhas;
- controles independentes para senha e confirmação no cadastro;
- feedback de erro/sucesso visível e anunciado por tecnologias assistivas;
- seleção de perfil acessível e adaptável à largura disponível;
- mensagens de erro sem exposição de exceções internas;
- proteção contra `setState` após descarte na verificação periódica de e-mail.

## 3. Contratos preservados

Permanecem inalterados:

- `AuthService.loginUsuario` para e-mail e senha;
- `AuthService.entrarComGoogle` para autenticação Google;
- `FirebaseAuth.sendPasswordResetEmail` para recuperação;
- criação de conta por `createUserWithEmailAndPassword`;
- escrita de `users/{uid}` com `schemaVersion`, `role` e `memberType`;
- campos temporários de compatibilidade do aluno;
- envio e consulta da verificação de e-mail;
- rotas de sucesso para `HomePage` e `VerifyEmailPage`;
- projetos Firebase e comportamento DEV/STAGING/PROD.

Não fazem parte desta mudança:

- alterar Rules, App Check, Functions, papéis ou permissões;
- alterar o acesso de Super Admin;
- modificar o contrato User v2;
- publicar uma nova versão na Play Store;
- implantar ou corrigir diretamente em PROD.

## 4. Testes automatizados

O arquivo `test/features/auth/auth_ui_visual_test.dart` cobre:

- independência dos controles de visibilidade de senha;
- semântica de região viva para mensagens;
- rolagem sem overflow em tela pequena com fonte em 200%;
- presença dos contratos sensíveis nas páginas originais.

Antes do merge, executar:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

## 5. Validação manual em DEV

Usar somente emuladores Firebase e dados sintéticos.

### Login

- testar e-mail inválido, senha curta e credenciais incorretas;
- confirmar mostrar/ocultar senha;
- confirmar login por e-mail e Google;
- cancelar o login Google e confirmar que isso não vira erro visual;
- abrir recuperação de senha e validar endereço inválido;
- confirmar que teclado aberto não cobre a ação principal.

### Cadastro

- testar separadamente os perfis Aluno e Personal;
- mostrar a senha sem revelar a confirmação e vice-versa;
- testar senhas divergentes;
- confirmar criação do User v2 sem mudança nos campos canônicos;
- verificar layout em 360 × 800, 390 × 844 e fonte 200%;
- confirmar acesso ao botão de cadastro com o teclado aberto.

### Verificação de e-mail

- confirmar estado de espera;
- reenviar e-mail;
- sair e voltar ao login;
- confirmar que falhas recuperáveis não exibem exceção técnica.

## 6. Gate e rollback

O merge depende de CI aprovada e validação manual em DEV. O rollback consiste em
reverter a PR; não há migração de dados, alteração de Rules ou efeito em
pagamentos.

## 7. Resultado da validação

A UX-04 do aplicativo foi aprovada em DEV em 9 de setembro de 2026:

- execução em aparelho Android físico com flavor `dev`;
- banner `DEV • LOCAL` e Firebase Emulator Suite preservados;
- login válido e inválido exercitados;
- recuperação de senha revisada;
- cadastro de Aluno e Personal revisado com dados sintéticos;
- controles de senha e confirmação exercitados separadamente;
- tela de verificação e reenvio de e-mail revisada;
- comportamento com teclado e fonte ampliada aprovado;
- Flutter CI aprovada;
- nenhuma mudança ou implantação realizada em PROD.

O fluxo de Super Admin não integra o escopo desta etapa e continua sujeito a
validação dedicada de autorização.
