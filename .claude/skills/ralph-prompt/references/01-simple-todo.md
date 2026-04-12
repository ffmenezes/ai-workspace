# Exemplo 1: TODO Simples

Nivel: **Basico**
Caso de uso: Tarefas lineares e independentes, sem dependencias complexas.

---

## Estrutura do Projeto

```
~/projects/meu-projeto/
  TODO.md              ← arquivo de controle
  ralph-prompt.md      ← prompt para ralph -f
```

## TODO.md

```markdown
# TODO — Setup inicial do projeto

## Contexto
Criar a estrutura basica de um projeto Node.js com TypeScript, linter e testes.

## Tarefas
- [ ] Inicializar package.json com `npm init -y`
- [ ] Instalar TypeScript e configurar tsconfig.json
- [ ] Instalar ESLint com preset typescript
- [ ] Criar estrutura de pastas: src/, tests/, dist/
- [ ] Criar src/index.ts com hello world
- [ ] Criar tests/index.test.ts com teste basico
- [ ] Configurar scripts no package.json: build, test, lint
- [ ] Rodar todos os scripts e verificar que passam

## Regras
- Usar ESM (type: module)
- Target ES2022
- Strict mode habilitado no tsconfig
```

## ralph-prompt.md

```markdown
Voce e um agente autonomo executando em loop via Ralph.

## Sua Missao
Completar todas as tarefas do TODO.md para setup inicial do projeto.

## Como Trabalhar
1. Leia o arquivo TODO.md para ver o estado atual
2. Encontre a proxima tarefa com `- [ ]` (nao concluida)
3. Execute essa tarefa completamente
4. Marque como `- [x]` no TODO.md
5. Se TODAS as tarefas estiverem `- [x]`, responda exatamente: RALPH_DONE

## Regras
- Execute APENAS UMA tarefa por iteracao
- Sempre leia TODO.md no inicio — voce nao tem memoria entre loops
- Siga a ordem das tarefas de cima para baixo
- Se um comando falhar, tente resolver e documente o erro no TODO.md
- Quando TUDO estiver completo, responda: RALPH_DONE
```

## Comando para executar

```bash
cd ~/projects/meu-projeto
ralph -a claude -f ralph-prompt.md -d -m 20
```

## Por que funciona

- Cada tarefa e atomica (1 comando ou 1 arquivo)
- A ordem e natural (dependencias implicitas: npm init antes de instalar pacotes)
- O agente le TODO.md a cada loop e sabe exatamente onde parou
- Sem estado externo — tudo no markdown
