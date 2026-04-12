# Exemplo 5: Caso Real — fabricadevideos

Nivel: **Avancado (producao)**
Caso de uso: Sprint BMAD real executado em 09/04/2026, com orquestracao automatica, multiplas fases, e logs de execucao.

---

## O que e o fabricadevideos

Projeto real que usou o Ralph com ciclo BMAD completo para desenvolver features de forma autonoma.

## Estrutura Real

```
~/projects/fabricadevideos/
  ralph/
    state.sh                          ← state machine em bash
    prompts/
      create-story.md                 ← detalha story a partir do backlog
      dev-story.md                    ← implementa story
      code-review.md                  ← review adversarial
      retrospective.md                ← retrospectiva por epic
      help.md                         ← diagnostico de problemas
    logs/
      iter-20260409-HHMMSS-PHASE.log  ← log de cada iteracao
  _bmad-output/
    implementation-artifacts/
      sprint-status.yaml              ← fonte de verdade
      1-3-user-authentication-*.md    ← story files gerados
      epic-1-retro-2026-04-09.md      ← retrospectiva
```

## Prompts Reais Usados

### create-story.md
```
You are operating on the fabricadevideos project. Invoke the BMAD skill
`bmad-create-story` to create the next story file for: {{STORY_ID}}.

Constraints:
- Use the existing sprint status at
  _bmad-output/implementation-artifacts/sprint-status.yaml as the source of truth.
- After the skill completes, ensure sprint-status.yaml reflects the new status
  (`ready-for-dev`) for {{STORY_ID}}.
- NON-INTERACTIVE MODE: never ask the user questions. If a BMAD skill prompts
  for input, pick the most sensible default and continue. If multiple options
  are offered, choose the one the skill marks as recommended; otherwise choose
  the safest, most conservative option. Document the choice in the output.
- If you cannot proceed even after picking defaults, print a single line
  starting with "BLOCKED:" explaining why and stop.
```

### dev-story.md
```
You are operating on the fabricadevideos project. Invoke the BMAD skill
`bmad-dev-story` to implement story {{STORY_ID}}.

Constraints:
- Read the story file under _bmad-output/implementation-artifacts/ matching
  {{STORY_ID}} and follow it.
- Implement code, run the project's tests, and update the story file as
  the skill instructs.
- When done, the skill should set status to `review` in
  _bmad-output/implementation-artifacts/sprint-status.yaml.
- NON-INTERACTIVE MODE: never ask the user questions. [...]
- If you cannot proceed [...] print "BLOCKED:" [...]
```

### code-review.md
```
You are operating on the fabricadevideos project. Invoke the BMAD skill
`bmad-code-review` against story {{STORY_ID}}.

Constraints:
- Run the adversarial review layers as the skill defines.
- Apply any required fixes that the review surfaces as blockers.
- When the story passes, the skill should set its status to `done`
  in sprint-status.yaml.
- NON-INTERACTIVE MODE: [...]
- If you cannot proceed [...] print "BLOCKED:" [...]
```

### retrospective.md
```
You are operating on the fabricadevideos project. All stories of {{EPIC_ID}}
are `done`. Invoke the BMAD skill `bmad-retrospective` for {{EPIC_ID}}.

Constraints:
- Produce the retrospective artifact as the skill defines.
- When complete, set `{{EPIC_ID}}-retrospective: done` and
  `{{EPIC_ID}}: done` in sprint-status.yaml.
- Do not run any other BMAD skill in this turn.
- NON-INTERACTIVE MODE: [...]
```

### help.md
```
You are operating on the fabricadevideos project. The Ralph loop hit a problem.

Context:
- Target: {{STORY_ID}}
- Failed phase: {{PHASE}}
- Last log tail:
{{LOG_TAIL}}

Invoke the BMAD skill `bmad-help` to analyze current sprint state and
recommend the next concrete action. If safe and obvious, perform it.
Otherwise print "BLOCKED:" and stop.
```

## state.sh — Logica de Decisao

A funcao `next_action()` implementa a prioridade:

1. **Retrospective**: se um epic esta `in-progress` mas todas as stories estao `done`
2. **Code Review**: primeira story com status `review`
3. **Dev Story**: primeira story com `in-progress` ou `ready-for-dev`
4. **Create Story**: primeira story com `backlog`
5. **None**: nada a fazer

Isso garante que reviews e retrospectivas tem prioridade sobre novo desenvolvimento.

## Resultado Real da Execucao (09/04/2026)

Timeline de 48 iteracoes ao longo de ~14 horas:

```
03:38  code-review     (inicio)
03:39  help            (diagnostico)
03:40  code-review     (retry)
04:08  create-story    → story 1-3 criada (user-authentication)
04:12  dev-story       → implementacao de 1-3
04:42  help            (timeout do qwen - diagnostico)
04:43  dev-story       → retry com claude
06:37  code-review     → review de 1-3
06:55  create-story    → story 1-4 criada
07:01  dev-story       → implementacao de 1-4
07:19  code-review     → review de 1-4
...
08:16  retrospective   → epic-1 retrospectiva gerada
...
(ciclo continua para epic-2)
...
16:48  code-review     (ultima iteracao do dia)
```

### Metricas observadas

- **48 iteracoes** em ~14 horas
- **Ciclo medio por story**: create(~20min) + dev(~30min) + review(~20min) = ~70min
- **1 timeout** (qwen agent) → help prompt diagnosticou e retomou com claude
- **1 retrospectiva** gerada automaticamente quando epic-1 completou
- **Zero intervencao humana** apos o start

## Licoes Aprendidas

1. **Timeouts acontecem** — o prompt `help.md` e essencial como fallback
2. **NON-INTERACTIVE e critico** — sem isso o agente trava esperando input
3. **BLOCKED: como protocolo** — da ao orquestrador um sinal claro para parar
4. **Logs com timestamp** — permitem reconstruir a timeline e debugar
5. **Story files como artefatos** — cada story gera um .md que documenta o que foi feito
6. **Retrospectiva automatica** — captura aprendizados enquanto o contexto esta fresco

## Padroes Extraidos para Reutilizacao

| Padrao | Descricao |
|--------|-----------|
| `{{PLACEHOLDER}}` | Substituicao de variaveis nos prompts pelo orquestrador |
| `NON-INTERACTIVE MODE` | Bloco padrao em todo prompt para evitar travamento |
| `BLOCKED:` | Protocolo de escape para intervencao humana |
| `sprint-status.yaml` | Fonte de verdade unica em formato simples (YAML flat) |
| `state.sh` + `next_action()` | Decisao automatica da proxima fase |
| Prompts por fase | Separacao clara de responsabilidades (create/dev/review/retro) |
| Logs timestamped | Rastreabilidade completa da execucao |
