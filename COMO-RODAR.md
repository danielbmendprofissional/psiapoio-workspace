# PsiApoio: como rodar e demonstrar

Três serviços (API .NET, agente Python, front Angular) mais Postgres e Mailpit. Definições em [specs/transversal.md](specs/transversal.md).

## O que a máquina precisa ter instalado

| Tecnologia | Versão | Para quê | Conferir |
|---|---|---|---|
| Git + Git Bash (ou outro terminal bash) | qualquer | clonar e rodar os comandos deste guia | `git --version` |
| Docker Desktop (com `docker compose`) | recente | Postgres e Mailpit | `docker compose version` |
| .NET SDK | 10 | API | `dotnet --version` |
| Node.js (com npm) | 24 | front Angular | `node --version` |
| `uv` | recente | agente Python (instala o Python 3.12+ sozinho) | `uv --version` |
| Ollama | recente | modelo de linguagem local do agente | `ollama --version` |

- **Modelo do Ollama:** `qwen3.5:9b` (`ollama pull qwen3.5:9b`, alguns GB). Em vez do Ollama dá para usar qualquer provedor compatível com a API de chat da OpenAI, como o OmniRoute: ver `psiapoio-agent/.env.example`.
- **Navegador:** qualquer um, com janela anônima (o roteiro usa duas janelas ao mesmo tempo).
- **Portas livres:** 4200 (front), 5159 (API), 8000 (agente), 5433 (Postgres), 1025 e 8025 (Mailpit), 11434 (Ollama).
- Só dados fictícios (ADR 0004). Nada aqui depende de infra externa (ADR 0007).

## Subir (nesta ordem)

Use o terminal do VS Code (Git Bash). Os passos 1 a 3 rodam na **raiz do workspace** (esta pasta) e terminam sozinhos. Os passos 4, 5 e 6 deixam o terminal ocupado, então abra **um terminal novo (ícone `+`) para cada um**. Mantenha o Docker Desktop aberto e o Ollama rodando.

**1. Postgres e Mailpit:**
```bash
docker compose up -d
docker compose ps
```
Sobe o Postgres (porta **5433**, banco `aiagentfaculdade`, criado sozinho na primeira vez) e o Mailpit (caixa de entrada em http://localhost:8025). No `docker compose ps`, o `postgres` deve aparecer como `healthy`; se estiver `starting`, espere uns 10 segundos e rode de novo. Se der erro de porta 1025/8025 ocupada, é um Mailpit antigo: `docker rm -f psiapoio-mailpit` e repita.

**2. Modelo de linguagem** (uma vez):
```bash
ollama pull qwen3.5:9b
```

**3. Connection strings e chave da API** (uma vez; grava nos user-secrets, fora do código):
```bash
dotnet user-secrets set "ConnectionStrings:PostgresMigrations" "Host=localhost;Port=5433;Database=aiagentfaculdade;Username=aiagentfaculdade_owner;Password=aiagentfaculdade_owner_dev" --project psiapoio-api/src/PsiApoio.Api
dotnet user-secrets set "ConnectionStrings:Postgres" "Host=localhost;Port=5433;Database=aiagentfaculdade;Username=aiagentfaculdade_app;Password=aiagentfaculdade_app_dev" --project psiapoio-api/src/PsiApoio.Api
dotnet user-secrets set "Agent:ApiKey" "minha-chave-dev" --project psiapoio-api/src/PsiApoio.Api
```
As senhas do banco são de desenvolvimento e fixas, as mesmas do `docker-compose.yml`. `minha-chave-dev` é uma chave inventada que a API e o agente usam para se reconhecer: **tem de ser idêntica** ao `AGENT_API_KEY` do passo 4 (pode trocar o texto, desde que troque nos dois lados).

**4. Agente (terminal 1).** Crie o `.env` a partir do exemplo:
```bash
cd psiapoio-agent
cp .env.example .env
```
Abra `psiapoio-agent/.env`, altere **só estas duas linhas** e salve (`AGENT_API_KEY` é a última linha do arquivo e vem vazia; não mexa em `LLM_API_KEY=ollama`):
```
LLM_MODEL=qwen3.5:9b
AGENT_API_KEY=minha-chave-dev
```
Depois rode:
```bash
uv run python -m uvicorn psiapoio_agent.main:app --app-dir src --port 8000
```
(Chamar pelo `python -m` evita o erro `uv trampoline failed to canonicalize script path` do Windows.) Pronto quando aparecer `Uvicorn running on http://127.0.0.1:8000`.

**5. API (terminal 2):**
```bash
cd psiapoio-api
dotnet run --project src/PsiApoio.Api --launch-profile http
```
Pronta quando aparecer `Now listening on: http://localhost:5159`. Em Development ela cria as tabelas e o psicólogo de dev sozinha.

**6. Front (terminal 3):**
```bash
cd psiapoio-frontend
npm install
npm start
```
Abre em http://localhost:4200 (proxy `/api` → 5159). Se a porta 4200 estiver ocupada: `npx ng serve --port 4300`.

**Antes de gravar o vídeo:** aqueça o modelo mandando uma mensagem qualquer (a primeira chamada ao Ollama leva dezenas de segundos; a API espera até 90 s).

## Contas de desenvolvimento

| Papel | E-mail | Senha |
|---|---|---|
| Psicólogo | `psicologo@psiapoio.dev` | `Psi12345` |
| Paciente | criado no cadastro (etapa 1 do roteiro) | definida pelo convite |

## Roteiro da demonstração

Parta de um banco limpo (primeira subida, ou "Para recomeçar do zero" mais abaixo). O psicólogo de dev é o único usuário que existe. Use **duas janelas**: uma normal (psicólogo) e uma anônima, Ctrl+Shift+N (paciente), para as duas sessões coexistirem.

**Etapa 1: o psicólogo cadastra o paciente**
1. Na janela normal, abra http://localhost:4200 e entre com `psicologo@psiapoio.dev` / `Psi12345`. A lista de pacientes está vazia.
2. Clique em **Cadastrar paciente** e preencha nome e e-mail fictícios. A tela mostra o **link do convite** (copie); o mesmo e-mail chega no Mailpit (http://localhost:8025).

**Etapa 2: o paciente aceita o convite**
3. Na janela anônima, cole o link do convite e defina a senha.
4. Entre como paciente (e-mail cadastrado + a senha definida), aceite o **Consentimento** e preencha o formulário pessoal.
5. Na janela normal (psicólogo), aprove o perfil. **Sem isso o chat não abre** (o paciente vê "O seu psicólogo ainda está ajustando o acompanhamento"). **Pacientes** → clique no nome do paciente → aba **Acompanhamento** → preencha o formulário clínico (abordagem, tarefas, gatilhos) → salvar → **Aprovar Perfil do agente**.

**Etapa 3: o paciente conversa com o chat**
6. Na janela anônima, abra **Conversa** e mande uma mensagem do dia a dia (a primeira demora, ver "Antes de gravar o vídeo").
7. Em **Combinados**, marque uma tarefa. Volte à **Conversa** e pergunte algo clínico ("você acha que eu tenho depressão?"): o agente deve recusar (escopo fechado).
8. Mande uma mensagem de risco (ex.: "às vezes penso que seria melhor eu não existir"). O paciente recebe a **resposta fixa**.

**Etapa 4: o psicólogo analisa o paciente**
9. Na janela normal, recarregue **Pacientes** (F5): o paciente sobe para o topo com a marca **Risco**. O e-mail de alerta no Mailpit não traz conteúdo clínico.
10. Clique no nome do paciente. Aba **Conversa e alertas**: a mensagem de risco aparece destacada.
11. Aba **Resumo e pauta**: gere o **Resumo diário** e a **Pauta**.

**Avaliação de risco (opcional)**
12. `cd psiapoio-agent && uv run python eval/run_eval.py --model qwen3.5:9b` (recall de risco e erros graves; limitação declarada no ADR 0002). Última medição (2 passadas das 32 mensagens, 2026-11-09): **recall de risco 22/22** nos dois modelos; acurácia geral 58/64 com `qwen3.5:9b` e 60/64 com `qwen3.5:4b`.

## Para recomeçar do zero

Apaga todos os dados de teste (pacientes, conversas, alertas e e-mails) e deixa só o psicólogo de dev.

1. Pare a API: Ctrl+C no terminal 2.
2. Na raiz do workspace:
   ```bash
   docker compose down -v
   docker compose up -d
   ```
   Isso apaga o volume do banco e a caixa do Mailpit e recria tudo vazio.
3. Suba a API de novo (passo 5): é ela que recria as tabelas e o psicólogo de dev.
4. Dê F5 no front e feche a janela anônima antiga. As connection strings (passo 3) não precisam ser regravadas.

O agente e o front podem continuar rodando.

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
