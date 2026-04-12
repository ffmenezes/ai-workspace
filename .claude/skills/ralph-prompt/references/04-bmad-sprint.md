# Exemplo 4: BMAD Sprint Completo

Nivel: **Avancado**
Caso de uso: Desenvolvimento orientado a epics e stories com ciclo BMAD completo (create → dev → review → retrospective). Baseado no padrao real usado no projeto **fabricadevideos**.

---

## Estrutura do Projeto

```
~/projects/meu-app/
  ralph/
    state.sh                 ← state machine (bash helpers)
    prompts/
      create-story.md        ← prompt: detalhar story a partir do backlog
      dev-story.md           ← prompt: implementar story
      code-review.md         ← prompt: review adversarial
      retrospective.md       ← prompt: retrospectiva de epic
      help.md                ← prompt: diagnostico quando algo trava
  _bmad-output/
    implementation-artifacts/
      sprint-status.yaml     ← fonte de verdade do estado
      *.md                   ← story files gerados
```

## sprint-status.yaml

```yaml
# Sprint Status — Fonte de verdade
# Status validos por story: backlog | ready-for-dev | in-progress | review | done
# Status validos por epic: not-started | in-progress | done

development_status:
  epic-1: in-progress
  1-1-setup-database-schema: done
  1-2-create-api-endpoints: done
  1-3-user-authentication: backlog
  1-4-role-based-access: backlog
  1-5-integration-tests: backlog
  epic-1-retrospective: optional
  epic-2: not-started
  2-1-dashboard-layout: backlog
  2-2-data-visualization: backlog
  2-3-real-time-updates: backlog
  epic-2-retrospective: optional
```

## state.sh (State Machine)

```bash
#!/usr/bin/env bash
# state.sh — helpers para ler sprint-status.yaml e decidir proxima acao.
# Sem side effects. Sourced pelo orquestrador.

STATUS_FILE="${STATUS_FILE:-_bmad-output/implementation-artifacts/sprint-status.yaml}"

# Le pares "key: value" do bloco development_status
_status_pairs() {
  awk '
    /^development_status:/ { in_block=1; next }
    in_block {
      if ($0 ~ /^[^[:space:]#]/) { in_block=0; next }
      if ($0 ~ /^[[:space:]]*#/) next
      if ($0 ~ /^[[:space:]]*$/) next
      sub(/#.*$/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      n = index($0, ":")
      if (n == 0) next
      key = substr($0, 1, n-1)
      val = substr($0, n+1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      print key, val
    }
  ' "$STATUS_FILE"
}

# story_status <story-id> → imprime status ou vazio
story_status() {
  _status_pairs | awk -v k="$1" '$1==k { print $2; exit }'
}

# epic_of <story-id> → imprime "epic-N"
epic_of() {
  local id="$1"
  local n="${id%%-*}"
  printf 'epic-%s\n' "$n"
}

# stories_in_epic <epic-N> → lista story ids do epic
stories_in_epic() {
  local epic="$1"
  local n="${epic#epic-}"
  _status_pairs | awk -v n="$n" '$1 ~ "^"n"-" { print $1 }'
}

# epic_all_done <epic-N> → exit 0 se todas as stories do epic estao done
epic_all_done() {
  local epic="$1"
  local any=0
  while read -r sid; do
    [ -z "$sid" ] && continue
    any=1
    local s; s=$(story_status "$sid")
    [ "$s" = "done" ] || return 1
  done < <(stories_in_epic "$epic")
  [ "$any" = "1" ]
}

# next_action → imprime "<phase> <story-or-epic-id>"
# phases: create-story | dev-story | code-review | retrospective | none
next_action() {
  # 1. Epic in-progress cujas stories estao todas done → retrospective
  while read -r key val; do
    case "$key" in
      epic-*)
        if [ "$val" = "in-progress" ] && epic_all_done "$key"; then
          local retro_key="${key}-retrospective"
          local rs; rs=$(story_status "$retro_key")
          if [ "$rs" != "done" ]; then
            echo "retrospective $key"
            return 0
          fi
        fi
        ;;
    esac
  done < <(_status_pairs)

  # 2. Primeira story nao-done, na ordem do arquivo
  while read -r key val; do
    case "$key" in
      epic-*|*-retrospective) continue ;;
    esac
    case "$val" in
      review)                  echo "code-review $key"; return 0 ;;
      in-progress|ready-for-dev) echo "dev-story $key"; return 0 ;;
      backlog)                 echo "create-story $key"; return 0 ;;
      done)                    continue ;;
    esac
  done < <(_status_pairs)

  echo "none -"
}
```

### Ciclo de Estados por Story

```
backlog → [create-story] → ready-for-dev → [dev-story] → review → [code-review] → done
```

### Ciclo de Estados por Epic

```
not-started → in-progress → (todas stories done) → [retrospective] → done
```

## Prompts

### create-story.md

```markdown
Voce esta operando no projeto. Invoque a skill BMAD `bmad-create-story` para criar
o arquivo de story para: {{STORY_ID}}.

Constraints:
- Use sprint-status.yaml como fonte de verdade.
- Apos completar, atualize o status para `ready-for-dev` no sprint-status.yaml.
- NON-INTERACTIVE MODE: nunca pergunte ao usuario. Se a skill pedir input,
  escolha o default mais sensato e continue. Documente a escolha no output.
- Se nao puder prosseguir, imprima "BLOCKED:" explicando o motivo e pare.
```

### dev-story.md

```markdown
Voce esta operando no projeto. Invoque a skill BMAD `bmad-dev-story` para
implementar a story {{STORY_ID}}.

Constraints:
- Leia o arquivo da story em _bmad-output/implementation-artifacts/ e siga-o.
- Implemente o codigo, rode testes, e atualize o arquivo da story.
- Quando terminar, atualize o status para `review` no sprint-status.yaml.
- NON-INTERACTIVE MODE: nunca pergunte ao usuario. Escolha defaults senatos.
- Se nao puder prosseguir, imprima "BLOCKED:" e pare.
```

### code-review.md

```markdown
Voce esta operando no projeto. Invoque a skill BMAD `bmad-code-review`
contra a story {{STORY_ID}}.

Constraints:
- Execute as camadas de review adversarial como a skill define.
- Aplique fixes para qualquer blocker que o review identificar.
- Quando a story passar, atualize o status para `done` no sprint-status.yaml.
- NON-INTERACTIVE MODE: nunca pergunte ao usuario. Documente escolhas no output.
- Se nao puder prosseguir, imprima "BLOCKED:" e pare.
```

### retrospective.md

```markdown
Voce esta operando no projeto. Todas as stories de {{EPIC_ID}} estao `done`.
Invoque a skill BMAD `bmad-retrospective` para {{EPIC_ID}}.

Constraints:
- Produza o artefato de retrospectiva como a skill define.
- Quando completo, atualize `{{EPIC_ID}}-retrospective: done` e
  `{{EPIC_ID}}: done` no sprint-status.yaml.
- Nao execute nenhuma outra skill BMAD neste turno.
- NON-INTERACTIVE MODE: escolha defaults sensatos. Documente no output.
- Se nao puder prosseguir, imprima "BLOCKED:" e pare.
```

### help.md

```markdown
Voce esta operando no projeto. O Ralph loop encontrou um problema.

Contexto:
- Target: {{STORY_ID}}
- Fase falha: {{PHASE}}
- Tail do ultimo log:
{{LOG_TAIL}}

Analise o estado atual do sprint e recomende a proxima acao concreta.
Se a recomendacao for segura e obvia (re-run, fix pequeno, rodar skill especifica),
execute-a. Caso contrario, imprima "BLOCKED:" descrevendo o que um humano deve fazer.
```

## Orquestrador (ralph.sh simplificado)

```bash
#!/usr/bin/env bash
# Orquestrador BMAD — chama ralph com o prompt certo baseado no state.sh
source ralph/state.sh

ACTION=$(next_action)
PHASE=$(echo "$ACTION" | cut -d' ' -f1)
TARGET=$(echo "$ACTION" | cut -d' ' -f2)

case "$PHASE" in
  none)
    echo "Todas as tarefas concluidas!"
    exit 0
    ;;
  create-story|dev-story|code-review|retrospective)
    # Substituir placeholders no prompt
    PROMPT_FILE="ralph/prompts/${PHASE}.md"
    PROMPT=$(cat "$PROMPT_FILE" | sed "s/{{STORY_ID}}/$TARGET/g; s/{{EPIC_ID}}/$TARGET/g")
    
    echo "Executando: $PHASE para $TARGET"
    ralph -a claude -p "$PROMPT" -d -m 5
    ;;
esac
```

## Comando para executar

```bash
cd ~/projects/meu-app

# Loop externo que roda o orquestrador ate nao ter mais acoes
while true; do
  ACTION=$(source ralph/state.sh && next_action)
  [ "$(echo $ACTION | cut -d' ' -f1)" = "none" ] && break
  bash ralph-orchestrator.sh
done
```

## Por que funciona

- **sprint-status.yaml** e a unica fonte de verdade — todos os prompts leem e atualizam ele
- **state.sh** encapsula a logica de transicao como funcoes puras (sem side effects)
- **next_action()** decide automaticamente qual fase executar baseado no estado atual
- Cada prompt e **idempotente** — pode rodar multiplas vezes sem quebrar
- O modo **NON-INTERACTIVE** garante que o agente nunca trava esperando input
- **BLOCKED:** e o escape hatch — sinaliza quando intervencao humana e necessaria
- O ciclo `create → dev → review → retro` garante qualidade sem pular etapas
