# PsiApoio: definições transversais

Vale para todas as fatias do [mapa](README.md). Quando uma spec de fatia divergir daqui, este documento ganha, ou é corrigido aqui primeiro. Vocabulário em [CONTEXT.md](../CONTEXT.md).

## 1. Modelo de dados

Dono: a API .NET (EF Core + Npgsql, migrations com `ConnectionStrings:PostgresMigrations`, runtime com `ConnectionStrings:Postgres`). Banco `aiagentfaculdade`, no Postgres do `docker-compose.yml` do projeto (ADR 0007). Ids `uuid`, datas `timestamptz` em UTC, "dia" como `date` (regra na seção 4).

```
AspNetUsers (Identity)       Id, Email, PasswordHash...   papel: Psicologo | Paciente (AspNetRoles)

Pacientes                    Id, UsuarioId (único), PsicologoId -> AspNetUsers, Nome, Email,
                             Status: convidado | ativo | removido,
                             ConviteEnviadoEm, CriadoEm
Acompanhamentos              Id, PacienteId (único, 1:1), Abordagem, Observacoes,
                             FormPessoal jsonb, PerfilStatus: rascunho | pendente | aprovado | reprovado,
                             PerfilMotivoReprovacao, PerfilAprovadoEm,
                             ConsentimentoEm, Memoria text, MemoriaAtualizadaEm
Temas                        Id, AcompanhamentoId, Texto, Ordem
Tarefas                      Id, AcompanhamentoId, Descricao, Frequencia: diaria | semanal | sob_demanda, Ativa
TarefaMarcacoes              Id, TarefaId, Dia (date)            único (TarefaId, Dia)
Gatilhos                     Id, AcompanhamentoId, Texto, Nivel: atencao | risco

Mensagens                    Id, AcompanhamentoId, Papel: paciente | agente, Texto, CriadaEm,
                             Risco: nenhum | atencao | risco | null (null = não classificada),
                             MotivoRisco, ForaDoEscopo, TemaPauta, Fixa (resposta fixa/padrão da API)
RegistrosHumor               Id, AcompanhamentoId, MensagemId, Dia (date), Valor (1..5)
Alertas                      Id, AcompanhamentoId, MensagemId, Nivel: atencao | risco,
                             Lido, CriadoEm, EmailEnviadoEm
Resumos                      Id, AcompanhamentoId, Dia (date), Texto, GeradoEm   único (AcompanhamentoId, Dia)
Pautas                       Id, AcompanhamentoId, Texto, GeradoEm, DesdeDia (date)
ConvitesEnviados             (opcional) usa o token do Identity; só registrar ConviteEnviadoEm em Pacientes
```

Notas:

- **Psicólogo** é um usuário Identity com papel `Psicologo`, sem tabela própria no MVP. Seed de dev: 1 psicólogo (`psicologo@psiapoio.dev`) criado no startup em Development.
- Um paciente pertence a um psicólogo: toda query de paciente filtra por `PsicologoId = sub do JWT`; toda query do paciente filtra por `UsuarioId = sub`.
- Mensagem com `Risco = null` é "não classificada" e **nunca** conta como `nenhum`: aparece no painel marcada como "não classificada".
- `Resumos` e `Pautas` são o cache da D3: regenerar só a pedido (botão "Atualizar").
- Registro de humor é derivado do campo `humor` devolvido pelo agente; no máximo um por mensagem.

## 2. Formulários

Sem fonte clínica externa: são o conjunto mínimo abaixo, escolhido para alimentar o prompt do agente. Cada campo vira texto no `perfil_agente` (seção 3.3).

### 2.1 Clínico (psicólogo, B2)

| Campo | Tipo | Obrigatório | Observação |
|---|---|---|---|
| Abordagem | enum: `TCC`, `ACT`, `Psicanalise`, `Humanista`, `Sistemica`, `Outra` | sim | só contexto de tom; o agente não aplica técnica da abordagem |
| Temas-foco | lista de texto curto (0–8) | não | ex.: "ansiedade no trabalho", "sono" |
| Orientações ao agente | texto longo (até 600 caracteres) | não | tom desejado, o que evitar, ex.: "não insistir em tarefas se estiver cansado" |
| Tarefas | lista (0–10): descrição (até 200) + frequência (`diaria`, `semanal`, `sob_demanda`) | não | o agente só sugere exercícios que estejam aqui |
| Gatilhos | lista (0–15): texto (até 80) + nível (`atencao` ou `risco`) | não | vão no prompt do classificador |

### 2.2 Pessoal (paciente, B3, no onboarding depois do **Consentimento**)

| Campo | Tipo | Obrigatório |
|---|---|---|
| Como prefere ser chamado | texto curto | sim |
| Rotina (acorda, trabalho/estudo, dorme) | texto curto | não |
| O que costuma ajudar quando está mal | texto curto | não |
| O que prefere que o agente evite falar | texto curto | não |
| Tom preferido | enum: `acolhedor`, `direto` | sim |

Guardado em `Acompanhamentos.FormPessoal` (jsonb). Ao enviar, `PerfilStatus` vai a `pendente` (se o clínico já está preenchido); o psicólogo aprova ou reprova.

### 2.3 Ciclo do **Perfil do agente**

`rascunho` (clínico incompleto ou pessoal ainda não enviado) → `pendente` (os dois preenchidos) → `aprovado` | `reprovado`.
Editar o clínico ou o pessoal de um perfil `aprovado` o devolve a `pendente`. **O agente só responde com `aprovado`.**

## 3. Contrato API .NET ↔ serviço do agente

Fonte de verdade: `psiapoio-agent/src/psiapoio_agent/schemas.py` (já implementado e testado). Cabeçalho `X-Api-Key` em toda chamada (`Agent:ApiKey` na API, `AGENT_API_KEY` no agente). Valores de nível no JSON: `nenhum`, `atencao`, `risco` (sem acento; a UI exibe "atenção").

### 3.1 `POST /v1/respond`

```json
{
  "perfil_agente": "texto montado pela API (seção 3.3)",
  "tarefas": ["Caminhada de 20 min (diária)"],
  "gatilhos": [{"texto": "prova", "nivel": "atencao"}],
  "memoria": "texto corrido, até 1500 caracteres",
  "mensagens_recentes": [{"papel": "paciente", "texto": "..."}, {"papel": "agente", "texto": "..."}],
  "mensagem": "texto novo do paciente"
}
```

Resposta (qualquer campo `null` = aquela parte falhou, a API decide):

```json
{
  "resposta": "texto ao paciente | null",
  "fora_do_escopo": false,
  "tema_para_pauta": "tema curto | null",
  "humor": 3,
  "risco": "nenhum | atencao | risco | null",
  "motivo_risco": "frase curta"
}
```

Regras da API (ADR 0002):

- `risco = "risco"`: **descarta** `resposta` e grava/envia a **mensagem fixa de risco** (seção 4.4); cria **Alerta** nível `risco`.
- `risco = "atencao"`: usa `resposta`; cria **Alerta** nível `atencao`.
- `risco = null`: usa `resposta`, grava a mensagem com `Risco = null`; não cria Alerta, mas o painel mostra "não classificada".
- `resposta = null`: grava a **mensagem padrão de falha** (seção 4.4) com `Fixa = true`.
- `mensagens_recentes`: as últimas 10 mensagens da conversa, mais antigas primeiro, sem a nova.
- Timeout da API para o agente: 90 s (cobre a primeira chamada com o modelo local frio). Estourou = trata como `resposta = null` e `risco = null`.

### 3.2 `POST /v1/memory/update` (segundo plano, depois da resposta)

```json
{ "memoria": "memória atual", "mensagens": [{"papel": "paciente", "texto": "..."}, {"papel": "agente", "texto": "..."}] }
```
→ `{ "memoria": "memória atualizada (até 1500 caracteres)" }`. A API grava em `Acompanhamentos.Memoria`. Falha (`502`) = ignora e tenta na próxima mensagem. Roda a cada 6 mensagens do paciente, não a cada mensagem.

### 3.3 Montagem do `perfil_agente`

Texto simples, em português, gerado pela API a partir dos formulários aprovados:

```
Abordagem do psicólogo: {Abordagem}
Temas-foco: {t1}; {t2}
Orientações do psicólogo: {Observacoes}
O paciente prefere ser chamado de: {ComoPrefereSerChamado}
Rotina: {Rotina}
O que ajuda quando está mal: {Ajuda}
Evitar: {Evitar}
Tom preferido: {acolhedor|direto}
```
`tarefas` = descrição + frequência de cada **Tarefa** ativa; marcações de hoje entram na memória enviada como linha extra ("Hoje marcou como feita: X").

### 3.4 D3: resumo e pauta (endpoints novos no agente)

`POST /v1/summary` → corpo: `{ "perfil_agente", "memoria", "dia": "2026-11-21", "mensagens": [{"papel","texto"}], "humores": [3, 2], "tarefas": [{"descricao","feita":true}] }` → `{ "texto": "..." }`. Texto curto, sem interpretação clínica ("anotação, não laudo").
`POST /v1/agenda` → corpo: `{ "perfil_agente", "resumos": ["texto do dia 1", "..."], "temas_para_pauta": ["..."] }` → `{ "texto": "...", "itens": ["..."] }`.

## 4. Regras pequenas

### 4.1 "Dia" e fuso
Todo "dia" (limite de mensagens, marcação de **Tarefa**, **Resumo diário**, humor do dia) é calculado em `America/Sao_Paulo` (00:00–23:59). O servidor guarda UTC e converte na hora de decidir o dia. O **Resumo diário** cobre o dia anterior.

### 4.2 Limite diário
20 mensagens do **Paciente** por dia. A 21ª recebe `429` com `{ "codigo": "limite_diario", "restantes": 0 }`; a tela mostra "Você chegou ao limite de hoje. Amanhã a gente continua." Mensagens do agente não contam. Valor em `Conversa:LimiteDiario` (config).

### 4.3 Paciente removido, perfil reprovado, perfil não aprovado
- **Removido**: o psicólogo "remove" o paciente → `Status = removido` (soft delete, dados mantidos no MVP). Sai da lista, login bloqueado (`403`). Não há exclusão física no MVP.
- **Reprovado**: o psicólogo informa um motivo opcional; o agente continua desligado; o paciente vê "Seu psicólogo está ajustando seu acompanhamento. Em breve você poderá conversar." O psicólogo edita e o perfil volta a `pendente`.
- **Sem perfil aprovado** (`rascunho`, `pendente`, `reprovado`): `POST` de mensagem devolve `409 { "codigo": "perfil_nao_aprovado" }` e a mesma tela de espera.
- **Sem consentimento**: `POST` de mensagem devolve `409 { "codigo": "sem_consentimento" }`; a tela exige o aceite antes do chat.

### 4.4 Textos fixos (gerados pela API, nunca pelo LLM)
- **Risco** (ADR 0002): "Obrigado por me contar. O que você escreveu é importante, e eu avisei o seu psicólogo agora. Se puder, fale também com alguém de confiança que esteja perto de você."
- **Falha do agente**: "Não consegui responder agora. Sua mensagem ficou registrada e o seu psicólogo pode vê-la. Tente de novo daqui a pouco."
- **Saudação ao abrir o chat** (lembrete): gerada pela API, sem LLM: "Oi, {nome}! Hoje você combinou: {tarefas ativas do dia}. Como você está?" (omite a parte das tarefas se não houver).

### 4.5 Prompt de escopo fechado
Está implementado em `psiapoio-agent/src/psiapoio_agent/agent.py` (`RESPONDEDOR_SISTEMA`, `CLASSIFICADOR_SISTEMA`) e é validado pelos testes e pela avaliação rotulada. É a fonte única: não duplicar o texto em spec.

### 4.6 Convite e senha
Token de redefinição do Identity com 72 h (`DataProtectionTokenProviderOptions.TokenLifespan`). Senha: mínimo 8 caracteres, com letra e dígito (relaxado em relação ao padrão por ser projeto acadêmico).

### 4.7 Erros e paginação
Erros em `application/problem+json` com um campo extra `codigo` (ex.: `limite_diario`). Listas paginadas por `?pagina=1&tamanho=20` com `{ itens, total }`. Rotas sob `/api/v1`.

## 5. Avaliação de risco (C2)

`psiapoio-agent/eval/mensagens_rotuladas.json` já tem 32 mensagens fictícias rotuladas (`nenhum`/`atencao`/`risco`), com `run_eval.py` (acurácia, matriz de confusão, **recall de risco**, latência). Os rótulos foram revisados em 2026-11-22 (nenhuma mudança: os casos ambíguos #16 e #27 já seguem a regra do nível mais alto). Meta para a apresentação: recall de `risco` = 100% no conjunto, e declarar a limitação (ADR 0002).

## 6. Ambiente local

| Peça | Como sobe | Config |
|---|---|---|
| Postgres | `docker compose up -d` na raiz do workspace (infra própria, ADR 0007); porta `5433`, banco `aiagentfaculdade` | user-secrets da API (`ConnectionStrings:Postgres`, `...PostgresMigrations`), comandos no `COMO-RODAR.md` |
| Mailpit | `docker compose up -d` (mesmo compose) | `Smtp:Host=localhost`, `Smtp:Port=1025`; caixa em http://localhost:8025 |
| Agente (Python) | `cd psiapoio-agent && cp .env.example .env && uv run uvicorn psiapoio_agent.main:app --app-dir src --port 8000` | `.env`: Ollama `qwen3.5:9b` (já baixado) ou OmniRoute; `AGENT_API_KEY` |
| API (.NET) | `dotnet run --project psiapoio-api/src/PsiApoio.Api` (porta `5159` em `launchSettings.json`) | `Agent:BaseUrl`, `Agent:ApiKey`, `Smtp:*` |
| Front (Angular) | `cd psiapoio-frontend && npm start` | proxy `/api` → `http://localhost:5159` (`proxy.conf.json`) |

Ordem: Postgres e Mailpit → agente → API (aplica migrations ao subir em Development) → front.

## 7. Estado dos repositórios

- `psiapoio-agent`: com histórico, serviço pronto (C1 e C2 de código).
- `psiapoio-api`: esqueleto com histórico; ganha as fatias A1 em diante.
- `psiapoio-frontend`: sem commit. Primeiro commit na `main` = fundação (D0: tokens, `DESIGN.md`, `PRODUCT.md`, `shared/ui`, página de amostra). Os protótipos (`src/app/prototype/`) ficam na branch `prototype/descartavel`, fora da `main`; viram as telas reais nas fatias C4 e D2.
- Cada repositório tem a branch de feature `feature/<fatia>-...`; sem GitLab neste trabalho (ver "Processo" no mapa).

## 8. Ordem de execução pelo prazo

Caminho crítico para a demo em vídeo: **D0 → F0 → A1 → B1 → B2 → B3 → C3 → C4 → D1 → D2**. C1 e C2 já estão feitos. **D3 (Resumo e Pauta) é a primeira a cortar** se faltar tempo: a demo funciona sem ela e o ADR 0002 (risco) não depende dela. Cada fatia só é "feita" com testes passando e build verde; no fim, um roteiro de demo (paciente conversa → mensagem de risco → Alerta no painel e e-mail no Mailpit) valida o conjunto.
