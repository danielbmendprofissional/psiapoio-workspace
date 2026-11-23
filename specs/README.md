# PsiApoio: mapa de escopo

Trabalho de faculdade: MVP do agente com .NET (API), Angular (front) e Python (serviço do agente), só Postgres. Vocabulário em [CONTEXT.md](../CONTEXT.md); modelo de dados, formulários, contrato com o agente e regras pequenas em [transversal.md](transversal.md); decisões em [docs/adr/](../docs/adr/).

## Dentro do MVP

- Agente conversacional com escopo fechado, memória no Postgres, limite diário de mensagens (ADR 0001, 0003)
- Classificação de risco por mensagem, resposta fixa em `risco`, **Alerta** no painel e e-mail sem conteúdo (ADR 0002)
- Cadastro do paciente, formulário clínico (psicólogo), convite por e-mail, **Consentimento**, formulário pessoal (paciente), aprovação do **Perfil do agente**
- **Resumo diário** e **Pauta** sob demanda, com cache
- Painel do psicólogo (lista por alerta, cadastro, detalhe do paciente, aprovação do perfil); paciente (chat, consentimento, formulário)
- Login por e-mail e senha, JWT com papéis `Psicólogo` e `Paciente`, acesso restrito aos próprios dados
- Conjunto de cerca de 30 mensagens fictícias rotuladas para medir a classificação de risco (ADR 0004)

## Fatias

Status na primeira coluna (`feito` ou `—`); quem a atualiza é o `/fatia`, ao reconciliar com o git. Repositórios: `front` = `psiapoio-frontend`, `api` = `psiapoio-api`, `agent` = `psiapoio-agent`. Protótipos aprovados (psicólogo A, paciente B) ficam na branch `prototype/descartavel` do front e viraram as telas reais. Autenticação e e-mail: ADR 0006.

| Status | # | Fatia | Repositório | Quem executa | Depende de | Toca em |
|---|---|---|---|---|---|---|
| feito | D0 | Fundação de design: tokens, helm ajustado, `DESIGN.md`, `PRODUCT.md` (ADR 0005) | front | você + agente | — | `front:styles`, `front:shared/ui` |
| feito | F0 | Casca do app: header fixo com perfil e "Sair", menu lateral por papel (Paciente: Conversa, Meus combinados; Psicólogo: Pacientes, Cadastrar paciente), rotas por papel | front | agente | D0 | `front:layout`, `front:app.routes` |
| feito | A1 | Login e sessão: ASP.NET Identity, JWT em cookie httpOnly de 60 min, `/usuarios/me`, guards por papel (ADR 0003, 0006) | api + front | agente | F0 | `api:Auth`, `front:core/auth` |
| feito | B1 | Cadastro do **Paciente** e **Convite** por e-mail (link de senha de 72 h, reenvio, link copiável; `IEmailSender` com Mailpit em dev) | api + front | agente | A1 | `api:Pacientes`, `api:Email`, `front:features/pacientes` |
| feito | B2 | Formulário clínico: abordagem, temas, **Tarefas**, **Gatilhos** | api + front | agente | B1 | `api:Acompanhamentos`, `front:features/acompanhamento` |
| feito | B3 | Formulário pessoal, **Consentimento** no primeiro login e aprovação do **Perfil do agente** | api + front | agente | B2 | `api:Perfil`, `front:features/perfil` |
| feito | C1 | Serviço do agente: interface de provedor LLM, escopo fechado, memória recebida da API (ADR 0001, 0003) | agent | agente | — | `agent:providers`, `agent:agente` |
| feito | C2 | Classificação de risco e conjunto de cerca de 30 mensagens rotuladas (ADR 0002, 0004) | agent | agente | C1 | `agent:risco`, `agent:eval` |
| feito | C3 | Conversa: mensagens, limite diário, **Registro de humor**, resposta fixa de risco, marcação diária de **Tarefa** pelo paciente | api | agente | B3, C2 | `api:Conversas`, `api:Tarefas` |
| feito | C4 | Tela de conversa do paciente (protótipo B): chat, Meus combinados com marcação, humor, consentimento, limite do dia | front | agente | C3, F0 | `front:features/conversa`, `front:features/combinados` |
| feito | D1 | **Alerta** (atenção/risco) e e-mail sem conteúdo clínico (ADR 0002) | api | agente | C3 | `api:Alertas`, `api:Email` |
| feito | D2 | Painel do psicólogo (protótipo A): lista por alerta, transcrição com risco/atenção destacados, Alerta, aprovação do perfil | api + front | agente | D1, F0 | `api:Painel`, `front:features/painel` |
| feito | D3 | **Resumo diário** e **Pauta** sob demanda, com cache | api + agent + front | agente | D2 | `api:Resumos`, `agent:resumo`, `front:features/painel` |

Paralelismo: C1 e C2 não dependem do front nem da API e rodam junto com F0–B3 (o "Toca em" não cruza).

## Adiado (por decisão, fora do MVP)

| Item | Motivo |
|---|---|
| Pagamento e pacotes de preço | Fora do foco da faculdade; só desenhado |
| Google Agenda, prontuário eletrônico, WhatsApp | Integrações; foco no agente |
| Multi-clínica e gestão avançada de carteira | Fora do foco |
| App móvel | Web basta para a demo |
| Conformidade LGPD completa (DPIA, política de retenção) | Fase de produto; o MVP usa só dados fictícios |
| Criptografia de coluna das mensagens | Fase 2; MVP tem HTTPS, hash de senha e controle de acesso |
| RAG e pgvector para gatilhos | Fase 2; no MVP a lista de gatilhos vai no prompt |
| Notificação além do e-mail, lembrete proativo fora do app | O lembrete é a saudação ao abrir o chat |
| Obsidian e graphify | Só como visualização para a apresentação, com dados fictícios |
| Encaminhamento a serviço de emergência | Decisão do autor; rever antes de pacientes reais (ADR 0002) |
| Tela "Meu perfil" e item "Alertas" no menu | O Alerta já aparece na lista de pacientes; perfil só no onboarding (B3) |
| Keycloak, Redis e BFF do template | Escopo só Postgres (ADR 0006) |

## Processo

Modo manual: sem GitLab nem orquestração de subagentes. Cada fatia segue o mesmo ciclo, dentro do Claude Code: ler a fatia aqui e o [transversal](transversal.md) → escrever os testes → implementar → rodar testes e build → commit na branch `feature/<fatia>-...` do repositório. Sem merge request: o merge em `main` é feito pelo autor ao final. A ordem de execução pelo prazo da entrega está no fim do [transversal](transversal.md).
