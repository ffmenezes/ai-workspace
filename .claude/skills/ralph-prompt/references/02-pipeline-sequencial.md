# Exemplo 2: Pipeline Sequencial

Nivel: **Intermediario**
Caso de uso: Etapas com dependencias explicitas — cada fase so comeca quando a anterior termina.

---

## Estrutura do Projeto

```
~/projects/api-migrar/
  PIPELINE.md          ← arquivo de controle
  ralph-prompt.md      ← prompt para ralph -f
```

## PIPELINE.md

```markdown
# Pipeline — Migracao de API Express para Fastify

## Objetivo
Migrar endpoints REST de Express para Fastify mantendo compatibilidade com os clientes existentes.

## Etapas

### Etapa 1: Scaffold Fastify (pre-req: nenhum)
- [ ] 1.1: Instalar fastify, @fastify/cors, @fastify/swagger
- [ ] 1.2: Criar src/server.ts com config basica do Fastify
- [ ] 1.3: Portar middleware de CORS para plugin Fastify
- [ ] 1.4: Verificar que o servidor sobe sem erros
- Status: PENDENTE

### Etapa 2: Migrar Rotas (pre-req: Etapa 1)
- [ ] 2.1: Migrar GET /api/users para Fastify route
- [ ] 2.2: Migrar POST /api/users com validacao JSON Schema
- [ ] 2.3: Migrar PUT /api/users/:id
- [ ] 2.4: Migrar DELETE /api/users/:id
- [ ] 2.5: Testar todas as rotas com curl/httpie
- Status: PENDENTE

### Etapa 3: Migrar Middleware (pre-req: Etapa 2)
- [ ] 3.1: Portar auth middleware para Fastify preHandler hook
- [ ] 3.2: Portar rate limiting para @fastify/rate-limit
- [ ] 3.3: Portar error handler para setErrorHandler
- [ ] 3.4: Testar fluxo completo autenticado
- Status: PENDENTE

### Etapa 4: Cleanup (pre-req: Etapa 3)
- [ ] 4.1: Remover dependencias do Express do package.json
- [ ] 4.2: Atualizar imports em todos os arquivos
- [ ] 4.3: Atualizar README com nova stack
- [ ] 4.4: Rodar build e verificar zero erros
- Status: PENDENTE

## Regras
- So inicie uma etapa quando a anterior tiver Status: CONCLUIDO
- Ao completar todas as tarefas de uma etapa, mude Status para CONCLUIDO
- Se encontrar um bloqueio, documente em "Notas" abaixo da etapa
- Quando Etapa 4 estiver CONCLUIDO, emitir RALPH_DONE
```

## ralph-prompt.md

```markdown
Voce e um agente autonomo executando em loop via Ralph.

## Sua Missao
Executar a migracao de Express para Fastify seguindo o PIPELINE.md.

## Como Trabalhar
1. Leia PIPELINE.md para ver o estado atual
2. Encontre a etapa ativa (Status: PENDENTE cujo pre-requisito ja esta CONCLUIDO)
3. Dentro da etapa ativa, encontre a proxima tarefa `- [ ]`
4. Execute essa tarefa
5. Marque como `- [x]` no PIPELINE.md
6. Se todas as tarefas da etapa estiverem `- [x]`, mude o Status para CONCLUIDO
7. Se a ultima etapa estiver CONCLUIDO, responda: RALPH_DONE

## Regras
- Execute APENAS UMA tarefa por iteracao
- NUNCA pule etapas — respeite os pre-requisitos
- Sempre leia PIPELINE.md no inicio de cada iteracao
- Se algo falhar, adicione uma nota na etapa e tente resolver
- Quando TUDO estiver completo, responda: RALPH_DONE

## Contexto Tecnico
- Projeto Node.js com TypeScript
- Express 4.x → Fastify 5.x
- Manter mesmos endpoints e contratos de resposta
```

## Comando para executar

```bash
cd ~/projects/api-migrar
ralph -a claude -f ralph-prompt.md -d -m 25
```

## Por que funciona

- Dependencias explicitas impedem o agente de pular etapas
- O campo Status serve como state machine simples no proprio markdown
- Cada tarefa e granular o suficiente para uma iteracao
- O agente valida pre-requisitos antes de avancar
