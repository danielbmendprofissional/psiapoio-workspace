# psiapoio-workspace

Workspace do **PsiApoio**: especificações, decisões (ADRs), glossário e o processo de desenvolvimento. O código mora em repositórios próprios. Parte do projeto [PsiApoio](https://github.com/danielbmendprofissional/psiapoio).

| Repositório | Papel |
|---|---|
| [psiapoio](https://github.com/danielbmendprofissional/psiapoio) | Vitrine e visão geral |
| **psiapoio-workspace** (este) | Specs, ADRs, glossário, processo |
| [psiapoio-api](https://github.com/danielbmendprofissional/psiapoio-api) | API .NET |
| [psiapoio-frontend](https://github.com/danielbmendprofissional/psiapoio-frontend) | Front Angular |
| [psiapoio-agent](https://github.com/danielbmendprofissional/psiapoio-agent) | Serviço Python do agente |

## O que é o PsiApoio

Um agente de IA acompanha o paciente entre as sessões de psicologia, sob configuração e supervisão do psicólogo. É um companheiro de **escopo fechado**, não um terapeuta: reforça tarefas combinadas, registra humor e acolhe. O psicólogo lê toda a conversa, recebe **Alertas** quando uma mensagem é classificada como `atenção` ou `risco`, e ganha **Resumo diário** e **Pauta** para a sessão.

## Conteúdo

| Caminho | O que é |
|---|---|
| [CONTEXT.md](CONTEXT.md) | Glossário do domínio (Psicólogo, Paciente, Acompanhamento, Perfil do agente, Tarefa, Gatilho, Alerta...) |
| [docs/adr/](docs/adr/) | Decisões: agente de escopo fechado (0001), reação a risco (0002), API dona do Postgres (0003), LLM atrás de interface (0004), direção de design (0005), autenticação por JWT em cookie (0006) |
| [specs/README.md](specs/README.md) | Mapa de escopo e as 13 fatias (todas feitas) |
| [specs/transversal.md](specs/transversal.md) | Modelo de dados, formulários, contrato API↔agente, regras pequenas, ambiente |
| [COMO-RODAR.md](COMO-RODAR.md) | Passo a passo para subir tudo e roteiro de demonstração |
| `docs/`, `.claude/` | Processo e regras do template de trabalho assistido por IA (discovery → spec → TDD → review) |

## Arquitetura

```
Angular (front) --HTTP /api--> API .NET --SQL--> PostgreSQL
                                  |
                                  +--HTTP + X-Api-Key--> Serviço Python --> LLM (Ollama / OmniRoute)
```

A API é a única que fala com o banco e a única que chama o agente; o Python é sem estado.

## Rodar

Ver [COMO-RODAR.md](COMO-RODAR.md). Resumo: Postgres e Mailpit, depois o agente (porta 8000), a API (5159) e o front (4200). Clone os três repositórios de código dentro desta pasta, com os nomes `psiapoio-api`, `psiapoio-frontend` e `psiapoio-agent` (eles são ignorados por este repositório).

## Limitações declaradas

A detecção de risco por LLM não é infalível (ADR 0002); não há encaminhamento a serviço de emergência (decisão do autor); a sessão dura 60 minutos sem refresh; só dados fictícios. Não use com pacientes reais.

## Origem do processo

A estrutura de processo (`docs/`, `.claude/`, `CLAUDE.md`) vem do template `ai-base`. O projeto adotou só parte dele: sem issue tracker nem orquestração de subagentes (ver "Processo" em [specs/README.md](specs/README.md)).
