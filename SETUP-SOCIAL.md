# Ativar contas, diário sincronizado e amizades — Estrela Minha

O frontend agora tem telas de conta, busca por @nome de usuário, pedidos de amizade e mensagens entre amigos. Para essas funções serem reais, configure um projeto Supabase. O repositório estático não contém nem inventa credenciais.

## 1. Criar e configurar o Supabase

1. Crie um projeto em https://supabase.com/.
2. No painel do projeto, abra **SQL Editor** e execute todo o conteúdo de [supabase-schema.sql](./supabase-schema.sql).
3. Abra **Project Settings → API** (ou a página de API Keys) e copie a **Project URL** e a chave pública **anon/publishable**.
4. Edite [supabase-config.js](./supabase-config.js) e preencha as propriedades url e anonKey com os valores do seu projeto. Não coloque aspas extras nos valores.
5. A chave pública anon/publishable pode estar no frontend, desde que as políticas RLS do schema estejam habilitadas. **Nunca use service_role nem uma chave secreta nesse arquivo.**
6. Em **Authentication → URL Configuration**, adicione o endereço real do site à lista de **Site URL / Redirect URLs**. Para recuperação de senha, o Supabase também precisa ter e-mail de autenticação configurado.
7. Publique os commits no GitHub Pages e abra a página publicada. Se a confirmação de e-mail estiver ativada, confirme o e-mail antes de entrar.

## 2. Como os dados são separados

- `user_vault` armazena o diário, humor, temas e demais dados pessoais em uma linha por `user_id`.
- As políticas Row Level Security (RLS) permitem que cada conta leia ou altere somente sua própria linha do diário.
- `profiles` contém somente os campos públicos de perfil usados para encontrar pessoas: nome de usuário e nome de exibição.
- `friendships` guarda pedidos e amizades.
- `messages` guarda mensagens entre duas contas com amizade aceita.
- As políticas RLS restringem leitura e envio de mensagens às pessoas daquela conversa.

O diário não é publicado no perfil e não é enviado a amigos. O nome de usuário é pesquisável por usuários autenticados.

## 3. Limitações e testes

- Sem preencher `supabase-config.js` e executar o SQL, login, criação de conta, sincronização e mensagens não funcionarão; a interface informa que falta configuração.
- O sistema usa Supabase Auth por e-mail e senha. A recuperação de senha depende da configuração de e-mail e das URLs de redirecionamento do projeto.
- Depois de configurar, teste com duas contas diferentes: criar as duas contas, buscar cada nome de usuário, enviar e aceitar um pedido, trocar mensagens, atualizar a página e entrar em outro dispositivo.
- Verifique no painel Supabase que cada usuário só consegue acessar a própria linha em `user_vault` e que as mensagens não podem ser lidas por uma terceira conta.
- O código foi verificado estaticamente, mas a integração não pode ser declarada operacional até serem fornecidas as credenciais do projeto e executados os testes reais acima.
