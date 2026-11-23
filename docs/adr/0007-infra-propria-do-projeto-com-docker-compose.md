# Infra própria do projeto (Docker Compose), sem depender do `ai-infra`

Este projeto diverge de `docs/agents/infra-local.md` ("Modelo: infra compartilhada, não por projeto"): a professora precisa rodar o PsiApoio na máquina dela, onde não existe o `ai-infra`. O Postgres e o Mailpit sobem de um `docker-compose.yml` na raiz do workspace.

- **Mesmo desenho, instância própria:** banco `aiagentfaculdade`, role dona `aiagentfaculdade_owner` (cria o esquema) e role de runtime `aiagentfaculdade_app` (só DML), criadas por `docker/postgres/init/01-banco-e-roles.sql` na primeira subida. O código da API não muda: lê as mesmas chaves `ConnectionStrings:Postgres` e `ConnectionStrings:PostgresMigrations`, agora gravadas nos user-secrets por dois comandos do `COMO-RODAR.md` (não mais pelo `infra-config.mjs`).
- **Porta 5433 no host**, para conviver com um Postgres na 5432 (o do `ai-infra`, na máquina do autor).
- **Senhas fixas de desenvolvimento** no `docker-compose.yml` e no SQL de init: o banco só tem dados fictícios (ADR 0004), só escuta em localhost e some com `docker compose down -v`. Continua valendo a regra de não pôr senha em `appsettings*.json`: a connection string vai para os user-secrets.
- **Mailpit** passa a subir no mesmo compose, no lugar do `docker run` avulso.
- **Fora do compose:** Ollama (ou provedor compatível com a OpenAI), que é a máquina de quem roda, e a API, o agente e o front, que rodam do código.
- **Sem observabilidade nem backup do `ai-infra`:** ficam de fora desta instância (`docs/agents/observabilidade-backup.md` não se aplica a ela).

## Consequences

Quem clona o workspace sobe tudo sem o `ai-infra` (`docker compose up -d`). O `ai-infra` continua sendo o padrão para os demais projetos; o contrato de chaves de `infra-local.md` segue valendo, só a origem dos valores muda. Se o projeto sair da faculdade, as senhas de dev e o `EnsureCreated` precisam dar lugar a segredos reais e migrations (já ressalvado nos ADRs 0002 e 0006).
