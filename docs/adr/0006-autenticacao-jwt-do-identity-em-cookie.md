# Autenticação: JWT do ASP.NET Identity entregue em cookie httpOnly, sem Keycloak, Redis nem BFF

Este projeto diverge de `docs/agents/padrao-api.md` (seção "Sessão (BFF / token handler)") e de `docs/agents/infra-local.md` ("Padrão de autenticação"): como o escopo é só Postgres e é um trabalho de faculdade, não há Keycloak, Redis nem BFF. A API .NET autentica com ASP.NET Identity e emite o JWT já previsto no ADR 0003 (`sub` e papel, sem dado clínico).

- **Entrega:** a API devolve o JWT em cookie `httpOnly`, `SameSite=Strict`, `Secure` fora de dev. O `JwtBearer` lê o token do cookie (`OnMessageReceived`). O JavaScript nunca vê o token, então não há `localStorage` nem interceptor de `Authorization`. Front e API ficam na mesma origem (`/api`, proxy do `ng serve` em dev), sem CORS com credenciais.
- **Validade:** 60 minutos, sem refresh. Token expirado → `401`, e o Angular leva ao login. O rascunho da mensagem do paciente fica em memória até o relogin.
- **Front:** `auth.service` chama `GET /api/v1/usuarios/me` no boot e guarda o usuário num signal; `authGuard` e o guard de papel (`Psicólogo`/`Paciente`) leem o signal. Login e logout são chamadas à API que setam e limpam o cookie.
- **Convite:** o **Psicólogo** cadastra o **Paciente**; a API envia por e-mail um link com o token de redefinição de senha do Identity (72 horas, reenviável, copiável na tela do psicólogo). O **Consentimento** é aceito no primeiro login, depois de definida a senha.
- **E-mail:** a API usa uma interface `IEmailSender` com SMTP configurável por chave; em dev vai a um Mailpit local. O serviço não está no contrato de `infra-local.md` e vira pedido ao agent de infra, não bloqueante (`PENDENCIAS.md`).

Decisão de produto registrada junto: a **Tarefa** é marcada como feita pelo próprio **Paciente** no painel "Meus combinados", uma marcação por dia; o agente lê esse estado e o **Resumo diário** o usa.

## Considered Options

- Cookie de sessão do Identity sem JWT: descartado por divergir do ADR 0003.
- JWT em `localStorage` com `Authorization: Bearer`: descartado, expõe a conversa a XSS sem ganho de simplicidade.
- Keycloak + BFF + Redis do padrão do template: descartado pelo escopo (só Postgres).
- Refresh token com rotação: descartado para o MVP; relogar a cada hora basta.

## Consequences

Sem refresh, a sessão cai a cada 60 minutos. Se o projeto sair da faculdade, o ADR deve ser revisto antes de uso com pacientes reais (junto da ressalva do ADR 0002).
