-- Roda uma vez, na criação do volume (ADR 0007). Mesmo desenho da infra compartilhada:
--   aiagentfaculdade_owner = dono do banco, cria o esquema (EnsureCreated / migrations)
--   aiagentfaculdade_app   = runtime da API, só DML (sem DDL)
-- Senhas de desenvolvimento, fixas de propósito: só dados fictícios, só localhost.

CREATE ROLE aiagentfaculdade_owner LOGIN PASSWORD 'aiagentfaculdade_owner_dev';
CREATE ROLE aiagentfaculdade_app   LOGIN PASSWORD 'aiagentfaculdade_app_dev';

CREATE DATABASE aiagentfaculdade OWNER aiagentfaculdade_owner;

\connect aiagentfaculdade

REVOKE ALL ON DATABASE aiagentfaculdade FROM PUBLIC;
GRANT CONNECT ON DATABASE aiagentfaculdade TO aiagentfaculdade_app;
GRANT USAGE ON SCHEMA public TO aiagentfaculdade_app;

-- tudo que o owner criar daqui em diante já nasce acessível (DML) para a role de runtime
ALTER DEFAULT PRIVILEGES FOR ROLE aiagentfaculdade_owner IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO aiagentfaculdade_app;
ALTER DEFAULT PRIVILEGES FOR ROLE aiagentfaculdade_owner IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO aiagentfaculdade_app;
