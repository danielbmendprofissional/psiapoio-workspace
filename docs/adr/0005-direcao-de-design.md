# Direção de design: calma, espaçosa, tema claro, status nunca só por cor

O frontend segue `docs/agents/padrao-frontend.md` sem divergência de stack (Angular zoneless, spartan/ui, Tailwind 4, Signals). A direção visual é decisão deste projeto:

- **Tom:** calmo e espaçoso, tema claro. O painel do **Psicólogo** é um pouco mais denso (perfil `dashboard`); o chat do **Paciente** é mais arejado (perfil `app-component`).
- **Cor de marca:** verde-azulado (teal, matiz 195 em OKLCH), escolhido na página de amostra contra índigo e musgo. Fica fora da paleta de marca o vermelho e o âmbar, reservados a `risco` e `atenção`. Cor só com significado.
- **Tipografia:** Figtree nos títulos e Source Sans 3 no corpo (sans humanista, corpo de 16 px e entrelinha 1,6), escolhida explicitamente contra Atkinson Hyperlegible Next e Albert Sans + Mulish.
- **Status:** ícone + rótulo + cor, nunca só cor. Níveis `nenhum`/`atenção`/`risco` (ADR 0002) e perfil pendente/aprovado. `risco` também destaca a linha na lista do **Alerta**.
- **Evitar:** gradiente roxo/azul e glassmorphism; emoji como ícone e ilustração de "robô simpático"; cards aninhados com sombra pesada; linguagem clínica fria na UI (Resumo diário não é laudo, **Acompanhamento** não é caso/prontuário, conforme `CONTEXT.md`).

A fonte de verdade viva do design passa a ser o `DESIGN.md` do `psiapoio-frontend`; `docs/design/tokens.md` é só o seed.

## Considered Options

- Denso e profissional (estilo dashboard de dados): descartado, frio para o paciente.
- Tema escuro por padrão: descartado, pior para leitura longa de transcrições.
