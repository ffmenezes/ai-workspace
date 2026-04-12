# Ralph Prompt — Referencias

Exemplos praticos graduados por complexidade. Use como base ao criar prompts com `/ralph-prompt`.

| # | Arquivo | Nivel | Descricao |
|---|---------|-------|-----------|
| 1 | [01-simple-todo.md](01-simple-todo.md) | Basico | TODO.md linear com tarefas independentes |
| 2 | [02-pipeline-sequencial.md](02-pipeline-sequencial.md) | Intermediario | Etapas com dependencias e pre-requisitos |
| 3 | [03-multi-agent.md](03-multi-agent.md) | Intermediario+ | Multiplos agentes com roles diferentes no mesmo projeto |
| 4 | [04-bmad-sprint.md](04-bmad-sprint.md) | Avancado | Sprint BMAD completo com state machine e orquestrador |
| 5 | [05-bmad-fabricadevideos.md](05-bmad-fabricadevideos.md) | Producao | Caso real do fabricadevideos (48 iteracoes, 14h autonomo) |

## Quando usar cada nivel

- **Basico**: "preciso fazer X, Y e Z nesse projeto" — tarefas claras, sem dependencias
- **Intermediario**: "preciso migrar/refatorar em etapas" — ordem importa, validacao entre fases
- **Intermediario+**: "preciso de claude pro codigo e gemini pro conteudo" — divisao de trabalho
- **Avancado**: "preciso de um sprint completo com create/dev/review/retro" — ciclo BMAD
- **Producao**: referencia real para entender como o BMAD funciona em execucao prolongada
