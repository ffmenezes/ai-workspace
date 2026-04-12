# Exemplo 3: Multi-Agent com Roles

Nivel: **Intermediario-Avancado**
Caso de uso: Diferentes agentes fazem tarefas diferentes no mesmo projeto, cada um com seu prompt especializado.

---

## Estrutura do Projeto

```
~/projects/landing-page/
  TASKS.md                   ← arquivo de controle compartilhado
  ralph-prompt-claude.md     ← prompt para claude (logica/estrutura)
  ralph-prompt-gemini.md     ← prompt para gemini (conteudo/copy)
```

## TASKS.md

```markdown
# Landing Page — Tarefas por Role

## Contexto
Criar landing page para produto SaaS com componentes React, copy persuasiva e SEO.

## Fase 1: Estrutura (agent: claude)
- [ ] C1: Criar projeto Next.js com App Router e Tailwind
- [ ] C2: Criar componente Hero com props para titulo/subtitulo/CTA
- [ ] C3: Criar componente Features com grid de cards
- [ ] C4: Criar componente Pricing com 3 tiers
- [ ] C5: Criar componente Footer com links e newsletter
- [ ] C6: Montar page.tsx compondo todos os componentes
- Status: PENDENTE

## Fase 2: Conteudo (agent: gemini)
- [ ] G1: Escrever copy do Hero (titulo, subtitulo, CTA) em content.json
- [ ] G2: Escrever descricoes das 6 features em content.json
- [ ] G3: Escrever copy dos 3 tiers de pricing em content.json
- [ ] G4: Escrever meta tags SEO (title, description, og:*) em content.json
- Status: PENDENTE (depende de Fase 1)

## Fase 3: Integracao (agent: claude)
- [ ] C7: Integrar content.json nos componentes
- [ ] C8: Adicionar responsividade mobile
- [ ] C9: Build e verificar zero erros
- Status: PENDENTE (depende de Fase 2)
```

## ralph-prompt-claude.md

```markdown
Voce e um agente autonomo executando em loop via Ralph. Seu role e DEVELOPER — voce cuida de estrutura e codigo.

## Sua Missao
Executar as tarefas marcadas com "agent: claude" no TASKS.md.

## Como Trabalhar
1. Leia TASKS.md para ver o estado atual
2. Encontre a proxima fase onde agent = claude e Status != CONCLUIDO
3. Verifique se a dependencia (fase anterior) esta CONCLUIDO
4. Encontre a proxima tarefa `- [ ]` com prefixo C
5. Execute e marque como `- [x]`
6. Se todas as tarefas C da fase estiverem completas, mude Status para CONCLUIDO
7. Se nao ha mais tarefas C pendentes, responda: RALPH_DONE

## Regras
- Apenas tarefas com prefixo C sao suas — ignore tarefas G
- Se a dependencia nao estiver pronta, responda: RALPH_DONE (volte depois)
- Execute UMA tarefa por iteracao
- Quando TUDO estiver completo, responda: RALPH_DONE
```

## ralph-prompt-gemini.md

```markdown
Voce e um agente autonomo executando em loop via Ralph. Seu role e COPYWRITER — voce cuida de conteudo e SEO.

## Sua Missao
Executar as tarefas marcadas com "agent: gemini" no TASKS.md.

## Como Trabalhar
1. Leia TASKS.md para ver o estado atual
2. Encontre a Fase 2 (agent: gemini)
3. Verifique se a Fase 1 esta com Status: CONCLUIDO
4. Se nao estiver, responda: RALPH_DONE (aguarde a estrutura ficar pronta)
5. Encontre a proxima tarefa `- [ ]` com prefixo G
6. Execute e marque como `- [x]`
7. Se todas as tarefas G estiverem completas, mude Status para CONCLUIDO e responda: RALPH_DONE

## Regras
- Apenas tarefas com prefixo G sao suas
- Todo conteudo vai em content.json na raiz do projeto
- Escreva em portugues brasileiro
- Copy deve ser persuasiva, concisa, focada em beneficios
- Quando TUDO estiver completo, responda: RALPH_DONE
```

## Comandos para executar

```bash
cd ~/projects/landing-page

# Terminal 1 — Claude faz a estrutura primeiro
ralph -a claude -f ralph-prompt-claude.md -d -m 15

# Terminal 2 — Gemini espera e faz o conteudo (pode rodar em paralelo)
ralph -a gemini -f ralph-prompt-gemini.md -d -m 15

# Depois que gemini terminar, rodar claude de novo para integracao
ralph -a claude -f ralph-prompt-claude.md -d -m 10
```

## Por que funciona

- Cada agente so toca nas tarefas que sao suas (prefixo C vs G)
- Dependencias entre fases impedem corrida de condicao
- O agente emite RALPH_DONE se a dependencia nao esta pronta (sai do loop, roda depois)
- Arquivo de controle compartilhado permite coordenacao sem comunicacao direta
