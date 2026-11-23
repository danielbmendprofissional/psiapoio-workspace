# PsiApoio: como rodar e demonstrar

Três serviços (API .NET, agente Python, front Angular) mais Postgres e Mailpit. Definições em [specs/transversal.md](specs/transversal.md).

## Pré-requisitos

.NET 10, Node 24, `uv` (Python), Docker. Ollama com o modelo `qwen3.5:9b` (ou um provedor compatível com a API da OpenAI, como o OmniRoute: ver `psiapoio-agent/.env.example`). Só dados fictícios (ADR 0004).

## Subir (nesta ordem)

1. **Postgres:** infra compartilhada já no ar; banco `aiagentfaculdade`. Gravar a connection string nos user-secrets da API (uma vez):
   `node <ai-infra>/configs/infra/infra-config.mjs secrets aiagentfaculdade --csproj=psiapoio-api/src/PsiApoio.Api/PsiApoio.Api.csproj`
2. **Mailpit** (e-mails de convite e de alerta): `docker run -d --name psiapoio-mailpit -p 1025:1025 -p 8025:8025 axllent/mailpit` (caixa em http://localhost:8025).
3. **Agente:** `cd psiapoio-agent && cp .env.example .env` (ajuste `LLM_MODEL` e `AGENT_API_KEY`), depois `uv run uvicorn psiapoio_agent.main:app --app-dir src --port 8000`.
4. **API:** `cd psiapoio-api && dotnet user-secrets set "Agent:ApiKey" "<a mesma AGENT_API_KEY>" --project src/PsiApoio.Api && dotnet run --project src/PsiApoio.Api --launch-profile http` (porta 5159; em Development cria as tabelas e o psicólogo de dev sozinha).
5. **Front:** `cd psiapoio-frontend && npm install && npm start` (http://localhost:4200, com proxy `/api` → 5159). Se a porta 4200 estiver ocupada: `npx ng serve --port 4300`.

**Antes de gravar o vídeo:** aqueça o modelo mandando uma mensagem qualquer (a primeira chamada ao Ollama leva dezenas de segundos; a API espera até 90 s).

## Contas de desenvolvimento

| Papel | E-mail | Senha |
|---|---|---|
| Psicólogo | `psicologo@psiapoio.dev` | `Psi12345` |
| Paciente | criado no cadastro (passo 2 do roteiro) | definida pelo convite |

## Roteiro da demonstração

1. Entrar como psicólogo → lista de pacientes vazia.
2. **Cadastrar paciente** (nome e e-mail fictícios). A tela mostra o link do convite; o e-mail chega no Mailpit.
3. Abrir o link, criar a senha, entrar como paciente → **Consentimento** → formulário pessoal.
4. Como psicólogo: abrir o paciente → aba **Acompanhamento** → preencher o formulário clínico (abordagem, tarefas, gatilhos) → salvar → **Aprovar Perfil do agente**.
5. Como paciente: **Conversa**. Mandar uma mensagem do dia a dia, marcar uma tarefa em "Meus combinados", perguntar algo clínico ("você acha que eu tenho depressão?") para ver o escopo fechado.
6. Mandar uma mensagem de risco (ex.: "às vezes penso que seria melhor eu não existir"). O paciente recebe a **resposta fixa**.
7. Como psicólogo: o paciente sobe para o topo da lista com **Risco**; a aba **Conversa e alertas** destaca a mensagem; o e-mail de alerta no Mailpit não traz conteúdo clínico.
8. Aba **Resumo e pauta**: gerar o **Resumo diário** e a **Pauta**.
9. Mostrar a avaliação de risco: `cd psiapoio-agent && uv run python eval/run_eval.py --model qwen3.5:9b` (recall de risco e erros graves; limitação declarada no ADR 0002). Última medição (2 passadas das 32 mensagens, 2026-11-09): **recall de risco 22/22** nos dois modelos; acurácia geral 58/64 com `qwen3.5:9b` e 60/64 com `qwen3.5:4b`.

## Testes

```bash
cd psiapoio-api && dotnet test          # 19 testes de integração (fluxo, isolamento, risco, limite)
cd psiapoio-agent && uv run pytest      # 15 testes (provedor falso, sem rede)
cd psiapoio-frontend && npx ng test --watch=false   # guards e tratamento de erro
```

## Limitações conhecidas (declare na apresentação)

- A detecção de risco por LLM não é infalível (ADR 0002); mensagem sem classificação aparece como "Não classificada", nunca como "sem risco".
- Sem encaminhamento a serviço de emergência, por decisão do autor.
- Sessão de 60 minutos sem refresh (ADR 0006). O esquema do banco é criado por `EnsureCreated` em Development; em produção seriam migrations.
- Modelo local pequeno: respostas às vezes imperfeitas; a primeira mensagem após ocioso é lenta.
