# Pendências do ai-base

## Abertas

- **Serviço de e-mail na infra** (não bloqueante). O contrato de `docs/agents/infra-local.md` não tem SMTP. O PsiApoio precisa dele para o **Convite** e o aviso de **Alerta** (ADR 0002 e 0006). Em dev a API usa `IEmailSender` com Mailpit local; o pedido de um serviço SMTP no `ai-infra` (chaves `Smtp:*`) segue o fluxo de `docs/agents/melhoria-orquestracao.md`, só com o ok do humano.

## Resolvidas

Última resolvida (2026-10-23): troca do PrimeNG (deixou de ser MIT na versão 22) por **spartan/ui** + Tailwind 4 como default de componentes Angular, seguindo a decisão da Esteira (`ai-pipeline/esteira/docs/adr/0015-spartan-ui-no-lugar-do-primeng.md`). A regra de conferir licença por versão ficou em `docs/design/component-library.md`.
