# AI Workspace — Deploy Guide

Setup containerizado de Claude Code + Gemini CLI + Qwen Code + Cursor CLI + OpenCode CLI
no Docker Swarm, com persistência em volumes e acesso via Termius.

---

## TL;DR

```bash
# 1. Na VPS: descompactar, buildar, deploy
cd ~/ai-workspace
docker build -t ai-workspace:latest .
# Deploy via Portainer (Stacks → Add Stack → colar aiworkspace.yaml)

# 2. Instalar atalhos no host
curl -fsSL https://raw.githubusercontent.com/ffmenezes/ai-workspace/main/setup-host-aliases.sh | bash && source ~/.bashrc

# 3. Entrar e autenticar (uma vez só)
ai-enter
claude /login                   # segue a URL no browser
export GEMINI_API_KEY="key"     # https://aistudio.google.com/apikey
echo 'export GEMINI_API_KEY="key"' >> ~/.bashrc
qwen                            # Qwen OAuth gratuito (1000 req/dia)
ssh-keygen -t ed25519 -C "ai-workspace"   # adicionar pub key no GitHub
exit

# 4. Usar
ai-dev meu-projeto                         # padrão: TODOS os agents (= --all)
ai-dev meu-projeto --claude                # só Claude
ai-dev meu-projeto --claude --gemini       # Claude + Gemini
ai-dev meu-projeto --qwen --cursor         # Qwen + Cursor (sem Claude)
ai-dev meu-projeto --rc                    # padrão + Remote Control no Claude
ai-dev meu-projeto --danger                # padrão + skip-permissions/yolo
ai-dev-danger meu-projeto                  # atalho pra --danger (todos)
ai-help                                    # lista todos os comandos

# Dentro do tmux:
# Ctrl+B 1/2/3...  → alternar windows
# Ctrl+B d          → sair sem matar

# Quick tunnel pra acessar localhost de qualquer device:
cfd http://localhost:3000
```

---

## Por que esse modelo?

### Continuidade real entre devices

Você começa um refactor no desktop, sai pra almoçar, e continua do celular
exatamente de onde parou. Não é sync de arquivos — é a **mesma sessão** rodando
na VPS. Terminal, contexto do Claude, histórico do Gemini, tudo intacto.

### Múltiplos AI agents no mesmo projeto, sob demanda

Claude Code, Gemini CLI e Qwen Code disponíveis no mesmo diretório.
Usa `--all` pra abrir os três, ou só o que precisar. Cada um numa window tmux,
sem competir por recursos quando não está em uso.

### Segurança por isolamento

O container é descartável. Se um agent executar um `rm -rf /` em modo danger,
o dano fica contido. Sua VPS, seus outros serviços (n8n, Chatwoot, bancos) não
são afetados. Recursos de CPU e RAM são limitados pelo Swarm.

### Preview instantâneo de qualquer lugar

`npm run dev` + `cfd http://localhost:3000` = URL pública em 5 segundos.
Mostra pro cliente no celular, testa no tablet, compartilha com colega.
Sem deploy, sem domínio, sem config. Morreu quando fechou.

### Acesso à infra interna

O container roda na `network_swarm_public` — mesma rede do Postgres, Redis,
n8n. MCPs dos agents podem se conectar ao banco, ao cache, às filas.
Seu AI agent tem acesso ao mesmo ecossistema que seus serviços de produção.

### Sessões que sobrevivem a tudo

Desconectou o SSH? Caiu a internet? Fechou o Termius sem querer? O tmux
continua rodando. Os agents continuam executando.
Você reconecta e tá tudo lá.

### Zero setup por projeto

Um comando (`ai-dev nome`) cria o workspace completo. Múltiplos projetos rodam
em paralelo como sessões tmux independentes.

### Reprodutível e portável

Tudo é código: Dockerfile, stack YAML, scripts. Perdeu a VPS? Sobe outra,
builda a imagem, restaura os volumes do backup. Quer dar acesso pra outra
pessoa? Cria outro container com volumes separados.

---

## Arquitetura

```
VPS (Debian 12)
├── Docker Swarm
│   ├── Traefik, Portainer, n8n...     ← seus serviços
│   └── ai-workspace (container)        ← Claude + Gemini + Qwen + Cursor + OpenCode
│       ├── /home/dev/projects  → vol   ← repos, código
│       ├── /home/dev/.config   → vol   ← auth tokens, settings
│       ├── /home/dev/.claude   → vol   ← skills, CLAUDE.md
│       ├── /home/dev/.gemini   → vol   ← sessions, memory
│       └── /home/dev/.ssh      → vol   ← chaves SSH
│
└── Host
    └── ai-enter / ai-dev / ai-dev-danger     ← atalhos pra entrar no container
```

### Por que `node:22-bookworm-slim`?

| Critério | Decisão |
|----------|---------|
| **Node.js** | Gemini CLI e Qwen Code requerem Node.js 20+. A base já inclui Node 22 LTS + npm. |
| **glibc vs musl** | Claude Code e uv distribuem binários nativos linkados contra glibc. Alpine (musl) causa crash. |
| **Debian 12 (Bookworm)** | Mesma distro do host da VPS. Sem surpresas de compatibilidade. |
| **Slim** | Sem docs, man pages e compiladores desnecessários (~200MB vs ~1.1GB na variante full). |

---

## Stack incluída

| Ferramenta | Instalação | Função |
|------------|------------|--------|
| Claude Code | Native installer (`curl`) | AI coding agent (Anthropic) |
| Gemini CLI | `npm install -g @google/gemini-cli` | AI coding agent (Google) |
| Qwen Code | `npm install -g @qwen-code/qwen-code` | AI coding agent (Alibaba, free tier) |
| Cursor CLI | Native installer (`curl`) | AI coding agent (Anysphere) |
| OpenCode CLI | `npm install -g opencode-ai` | AI coding agent (sst, open source, multi-provider) |
| Lightpanda | Binário único (`curl`) | Headless browser leve (MCPs, scraping simples) |
| Playwright + Chromium | `npm install -g` + `--with-deps` | Browser completo (E2E, scraping avançado, anti-bot) |
| cloudflared | Binário único (`curl`) | Quick tunnel pra expor localhost |
| tmux | apt | Multiplexador de terminal |
| Go | Binário oficial (`curl`) | Runtime Go 1.24 |
| Rust | rustup (`curl`) | Toolchain Rust (cargo, rustc) |
| uv | `curl` | Gerenciador Python moderno |
| Python 3 | apt | Runtime pra MCPs e scripts |
| bat | `.deb` | cat com syntax highlighting |
| eza | Binário (`curl`) | ls moderno com ícones |
| fd | apt | find mais rápido |
| ripgrep | apt | Busca rápida (usado pelos agents) |
| Starship | `curl` | Prompt informativo |
| git | apt | Controle de versão |

---

## Passo 1: Subir os arquivos pra VPS

```bash
mkdir -p ~/ai-workspace
scp -r ./* sua-vps:~/ai-workspace/
```

---

## Passo 2: Criar volumes externos

```bash
docker volume create aiworkspace_projects
docker volume create aiworkspace_config
docker volume create aiworkspace_claude
docker volume create aiworkspace_gemini
docker volume create aiworkspace_qwen
docker volume create aiworkspace_cursor
docker volume create aiworkspace_opencode
docker volume create aiworkspace_ssh
```

---

## Passo 3: Obter a imagem

Você tem duas opções:

### Opção A — Pull do GitHub Container Registry (recomendado)

A imagem é buildada automaticamente via GitHub Actions e publicada no `ghcr.io`.

```bash
# Pull da última versão
docker pull ghcr.io/ffmenezes/ai-workspace:latest
```

> ⚠️ Substitua `ffmenezes` pelo seu usuário do GitHub se for fork.
> Se a imagem é privada, faça login antes:
> ```bash
> echo "$GITHUB_TOKEN" | docker login ghcr.io -u ffmenezes --password-stdin
> ```

### Opção B — Build local

```bash
cd ~/ai-workspace
docker build -t ai-workspace:latest .
```

Use essa opção se você modificou o Dockerfile localmente ou quer testar
mudanças antes de commitar.

---

## Passo 4: Deploy via Portainer

1. Abrir Portainer → **Stacks** → **Add Stack**
2. Nome: `aiworkspace`
3. **Build method**: Web editor
4. Colar o conteúdo de `aiworkspace.yaml`
5. Clicar **Deploy the stack**

**Alternativa via CLI:**
```bash
docker stack deploy -c aiworkspace.yaml aiworkspace
```

---

## Passo 5: Configurar aliases no host

One-liner (não precisa clonar o repo):

```bash
curl -fsSL https://raw.githubusercontent.com/ffmenezes/ai-workspace/main/setup-host-aliases.sh | bash
source ~/.bashrc
```

Mesmo comando serve pra **resetar** os aliases depois de updates — o script remove o bloco antigo do `~/.bashrc` antes de reescrever.

Adiciona os atalhos `ai-enter`, `ai-attach`, `ai-dev`, `ai-dev-danger`, `ai-sessions`, `ai-kill`, `ai-kill-all`, `ai-fix-perms`, `ai-update` e `ai-help` ao host. Rode `ai-help` pra ver a referência completa.

---

## Passo 6: Autenticar as CLIs

```bash
ai-enter

# ── Claude Code (subscription Pro/Max) ──
claude /login
# Vai mostrar uma URL — copie e abra no browser
# O token fica salvo em ~/.claude/.credentials.json (volume aiworkspace_claude)
claude -p "ping"

# ── Gemini CLI ──
# Gere API key em: https://aistudio.google.com/apikey
# IMPORTANTE: configure no aiworkspace.yaml (environment), NÃO no ~/.bashrc.
# O ~/.bashrc do container é recriado a cada rebuild — env var no stack sobrevive.
gemini --version

# ── Qwen Code ──
# Opção A: Qwen OAuth (gratuito, 1000 req/dia)
qwen
# Na primeira execução, escolha "Qwen OAuth (Free)" e siga o browser
# Token persiste em ~/.qwen (volume aiworkspace_qwen)

# Opção B: API key (DashScope, OpenRouter, etc.) — configure no stack file
# OPENAI_API_KEY, OPENAI_BASE_URL, OPENAI_MODEL

# ── Cursor CLI ──
# Opção A: browser OAuth (recomendado)
agent login
# Token persiste em ~/.cursor/cli-config.json (volume aiworkspace_cursor)

# Opção B: API key — configure CURSOR_API_KEY no stack file

# ── OpenCode CLI ──
opencode auth login
# Interativo: escolhe provider (Anthropic, OpenAI, Google, etc.) e cola a key.
# Suporta múltiplos providers ao mesmo tempo.
opencode auth list
# Auth persiste em ~/.local/share/opencode/auth.json (volume aiworkspace_opencode)
```

> **NOTA sobre persistência**: Claude, Qwen, Cursor e OpenCode guardam credenciais
> em arquivos dentro de volumes dedicados — sobrevivem a rebuild. Já o Gemini usa
> apenas env vars (`GEMINI_API_KEY`); a forma robusta é declará-las em
> `aiworkspace.yaml` na seção `environment:` do serviço, não no `~/.bashrc`
> interno (que é recriado a cada rebuild).

---

## Passo 7: Configurar GitHub e clonar projetos

```bash
ai-enter

# Gerar chave SSH
ssh-keygen -t ed25519 -C "ai-workspace"
# Aperte Enter em tudo (path padrão, sem passphrase)

# Copiar chave pública
cat ~/.ssh/id_ed25519.pub
# Copie o output → GitHub → Settings → SSH and GPG keys → New SSH key → colar e salvar

# Testar conexão
ssh -T git@github.com
# "Hi usuario! You've successfully authenticated..."

# Clonar um projeto
cd ~/projects
git clone git@github.com:seu-user/seu-repo.git meu-projeto

# Configurar identidade do git (uma vez)
git config --global user.name "Seu Nome"
git config --global user.email "seu@email.com"

# Sair e abrir workspace
exit
ai-dev meu-projeto
```

A chave SSH persiste no volume `aiworkspace_ssh` — não precisa refazer no rebuild.
Para múltiplas contas GitHub, veja o **Apêndice A** no final deste documento.

---

## Uso diário

### Comando `ai-dev` — workspace modular

Por padrão, `ai-dev` abre **todos** os agents (Claude + Gemini + Qwen + Cursor + OpenCode). Pra abrir só um subconjunto, nomeie as ferramentas que quer:

```bash
# Padrão — todos os agents
ai-dev meu-projeto

# Só Claude (leve, ~100MB RAM)
ai-dev meu-projeto --claude

# Combinar quem quiser (sem Claude também é válido)
ai-dev meu-projeto --claude --gemini
ai-dev meu-projeto --qwen --cursor
ai-dev meu-projeto --opencode

# --all é sinônimo explícito do padrão
ai-dev meu-projeto --all

# Modificadores (não contam como "agent flag" — não desativam o padrão)
ai-dev meu-projeto --rc                 # adiciona Remote Control no Claude
ai-dev meu-projeto --danger             # skip-permissions/yolo em quem suporta
ai-dev-danger meu-projeto                   # atalho pra --danger (todos)
```

**Flags `--danger` por CLI** (cada uma usa o flag nativo):

| CLI | Flag |
|-----|------|
| `claude` | `--dangerously-skip-permissions` |
| `gemini` | `--yolo` |
| `qwen` | `--yolo` |
| `cursor` | `-f` (`--force`) |
| `opencode` | — (sem equivalente, ignorado) |

### Dentro do tmux

```bash
# ── Windows (cada agent abre numa window) ──
Ctrl+B 1     → Claude Code
Ctrl+B 2     → Gemini / Qwen / Browser (depende do que abriu)
Ctrl+B n     → próxima window
Ctrl+B p     → window anterior
Ctrl+B w     → lista visual de todas as windows
Ctrl+B c     → nova window no mesmo diretório

# ── Splits dentro de uma window ──
Ctrl+B |     → split vertical
Ctrl+B -     → split horizontal
Ctrl+B ←↑→↓  → navegar entre splits

# ── Sessões (cada projeto = uma sessão) ──
Ctrl+B s     → menu visual de todas as sessões
Ctrl+B (     → sessão anterior
Ctrl+B )     → próxima sessão

# ── Sair sem matar ──
Ctrl+B d     → detach (sessão continua rodando em background)

# ── Matar (encerrar de verdade) ──
Ctrl+B X     → matar sessão atual (com confirmação)
Ctrl+B Q     → matar TODAS as sessões (com confirmação)

# ── Recarregar config ──
Ctrl+B r     → reload do tmux.conf
```

### Gerenciar sessões pelo shell

```bash
tmux ls                              # lista todas as sessões
tmux attach -t meu-projeto           # entrar numa específica
tmux kill-session -t meu-projeto     # matar uma específica
tmux kill-server                     # matar todas (nuclear)

# Atalho: dentro do container
ai-kill meu-projeto                  # mata sessão do projeto
ai-sessions                            # ver tudo que tá rodando
```

### Múltiplos projetos ao mesmo tempo

Cada `ai-dev` cria uma sessão tmux **independente**. Pra ter dois projetos
abertos simultaneamente:

```bash
# Abre o primeiro
ai-dev projeto-a --all
# Trabalha, e quando quiser sair sem matar:
Ctrl+B d

# Abre o segundo (cria nova sessão)
ai-dev projeto-b --all
Ctrl+B d

# Alterna entre eles:
Ctrl+B s          # menu visual com setas
# ou
tmux attach -t projeto-a
```

### Reconectar a um projeto

```bash
ai-dev meu-projeto    # se a sessão já existe, reconecta direto
```

### Pelo app Claude (celular)

Quando usar `--rc`, o Claude Code ativa Remote Control.
Abra o app Claude no celular → sessão aparece automaticamente com UX nativa.

### Quick Tunnel (acessar localhost de qualquer lugar)

Quando rodar `npm run dev` ou qualquer server local no container, ele fica
em `localhost:3000` (ou outra porta) — inacessível de fora. O `cloudflared`
cria um túnel público instantâneo, sem config, sem domínio, sem auth.

```bash
# Na window shell, subir o projeto:
npm run dev
# Server rodando em http://localhost:3000

# Abrir split (Ctrl+B |) e rodar:
cfd http://localhost:3000

# Output:
# +-----------------------------------------------------------+
# |  Your quick Tunnel has been created! Visit it at:          |
# |  https://abc-xyz-123.trycloudflare.com                    |
# +-----------------------------------------------------------+

# Abra essa URL em qualquer device — celular, outro computador, etc.
# Ctrl+C pra encerrar o túnel quando terminar.
```

Funciona pra qualquer porta: Vite (5173), Next.js (3000), Astro (4321), etc.
O túnel é efêmero — morre quando você fechar. Sem rastros, sem config residual.

### Ralph Loop (agent autônomo)

O `ralph` roda um AI agent em loop até completar uma tarefa. Útil pra
tarefas que precisam de múltiplas iterações (implementar features, corrigir
testes, refatorar). Você inicia, faz detach, e volta quando terminar.

**Modo interativo (wizard):**

```bash
ai-enter
cd ~/projects/meu-projeto
ralph
# Escolhe o agent, digita o prompt, configura loops, confirma
```

**Modo direto:**

```bash
ai-enter
cd ~/projects/meu-projeto
ralph -a claude   -p "implemente os testes do módulo auth" -d -m 30
ralph -a gemini   -f prompt.md
ralph -a qwen     -p "refatore o componente X" --done "FINALIZADO"
ralph -a cursor   -p "corrija os warnings do typescript" -d
ralph -a opencode -p "documente as funções públicas"      # opencode ignora --danger
```

**Flags:**

| Flag | Descrição | Default |
|------|-----------|---------|
| `-a, --agent` | claude, gemini, qwen, cursor ou opencode | claude |
| `-p, --prompt` | prompt inline | — |
| `-f, --file` | prompt de arquivo | — |
| `-m, --max` | máximo de loops | 50 |
| `-d, --danger` | skip-permissions/yolo | false |
| `--done` | palavra de parada | RALPH_DONE |

**Teste rápido (pasta vazia):**

```bash
ai-enter
mkdir -p ~/projects/ralph-teste
cd ~/projects/ralph-teste

# Criar TODO simples
cat > TODO.md << 'EOF'
# Tarefas

- [ ] Criar um arquivo hello.js que imprime "Hello World"
- [ ] Criar um arquivo soma.js com função que soma dois números
- [ ] Criar um README.md explicando os dois arquivos
EOF

# Rodar (deve completar em ~3 loops)
ralph -a claude -p "Leia o TODO.md. Execute a próxima tarefa marcada como [ ]. Marque como [x] quando completar. Se todas estiverem [x], responda RALPH_DONE" -d -m 10
```

Logs de cada iteração ficam em `.ralph-logs/` dentro do projeto.

**Workflow típico:**

```bash
ai-enter
cd ~/projects/meu-projeto
ralph -a claude -f prompt.md -d    # inicia o loop
# Ctrl+C se quiser parar manualmente
# Ou deixa rodar, sai do container (exit), faz detach (Ctrl+B d)
# O loop continua na VPS
# Volta depois: ai-enter → cd ~/projects/meu-projeto → cat .ralph-logs/loop-*.log
```

---

## Snippets do Termius

Configure em **Settings > Snippets**:

| Nome     | Comando                        | Descrição                      |
|----------|--------------------------------|--------------------------------|
| `enter`  | `ai-enter`                     | Entrar no container            |
| `dev`    | `ai-dev`                       | Workspace (todos os agents)    |
| `claude` | `ai-dev --claude`              | Workspace só Claude            |
| `dev-rc` | `ai-dev --rc`                  | Workspace + Remote Control     |
| `ws`     | `ai-sessions`                  | Status das sessões             |
| `help`   | `ai-help`                      | Ajuda dos comandos             |

---

## Manutenção

### Instalar pacotes no container

O container roda como user `dev` (sem sudo). Para instalar pacotes globais,
use `docker exec -u root` do host:

```bash
# Do host (não de dentro do container):

# npm global
docker exec -u root $(docker ps -q -f name=aiworkspace) npm install -g nome-do-pacote

# apt (ferramentas do sistema)
docker exec -u root $(docker ps -q -f name=aiworkspace) bash -c "apt-get update && apt-get install -y nome-do-pacote"

# pip
docker exec -u root $(docker ps -q -f name=aiworkspace) pip install nome-do-pacote --break-system-packages
```

Pacotes instalados assim **não sobrevivem a rebuild**. Se for algo que usa sempre,
adicione ao Dockerfile e faça rebuild.

### Atualizar as CLIs (regra geral)

**A forma confiável de atualizar qualquer CLI é rebuild da imagem + `ai-update`.**
Não confie em auto-updaters dentro do container — eles ou estão bloqueados pelo
layout do Dockerfile (Claude, Cursor) ou são apagados no próximo rebuild
(npm-installed CLIs).

```bash
# Na VPS:
ai-update

# O que ele faz por trás:
docker pull ghcr.io/ffmenezes/ai-workspace:latest
docker service update --image ghcr.io/ffmenezes/ai-workspace:latest --force aiworkspace_aiworkspace
```

A imagem é buildada automaticamente pelo GitHub Actions a cada push em `main`.
Logo, fluxo típico de update:

1. Mudar Dockerfile (ou esperar rebuild diário, se configurado)
2. `git push`
3. Aguardar Actions (~5-10min)
4. Na VPS: `ai-update`
5. Sessões tmux antigas morrem (esperado), volumes persistem

Para usar uma instância Swarm com nome diferente, exporte
`AI_WORKSPACE_SERVICE=meu_servico` antes de chamar `ai-update`.

### Por que rebuild e não auto-update?

| CLI | Auto-update funciona? | Por quê |
|-----|------------------------|---------|
| Claude Code | ❌ | O binário é copiado pra `/opt/claude` (read-only) e symlinkado em `/usr/local/bin`. O auto-updater nativo baixa novas versões em `~/.local/share/claude/versions/`, mas o symlink em PATH continua apontando pra versão de build — então o update silencioso acontece, mas nunca é executado. |
| Cursor CLI | ❌ | Mesmo problema (`/opt/cursor-agent` read-only). |
| Gemini / Qwen / OpenCode | Parcial | São pacotes npm globais. `npm update -g <pkg>` dentro do container funciona, mas o resultado vive só naquela instância — qualquer rebuild apaga. |

### Atualizar pontualmente (efêmero, só dura até o próximo rebuild)

```bash
ai-enter

npm update -g @google/gemini-cli      # Gemini
npm update -g @qwen-code/qwen-code    # Qwen
npm update -g opencode-ai             # OpenCode

# Claude e Cursor: NÃO há caminho pontual confiável — só rebuild.
```

Se uma CLI precisar de versão fixa, edite o Dockerfile e dispare rebuild via
push. Versões "pinadas" via `ARG` ainda não estão implementadas (ver
`CLAUDE.md` em "Known limitations").

### Backup dos volumes

```bash
for vol in projects config claude gemini qwen cursor opencode ssh; do
    docker run --rm \
        -v aiworkspace_${vol}:/data \
        -v /opt/backups:/backup \
        debian:12-slim \
        tar czf /backup/aiworkspace_${vol}_$(date +%Y%m%d).tar.gz -C /data .
done
```

### Restaurar volume

```bash
docker run --rm \
    -v aiworkspace_projects:/data \
    -v /opt/backups:/backup \
    debian:12-slim \
    tar xzf /backup/aiworkspace_projects_20260330.tar.gz -C /data
```

---

## Checklist de verificação

```bash
ai-enter                      # ✅ Entrou no container
claude --version              # ✅ Claude Code
gemini --version              # ✅ Gemini CLI
qwen --version                # ✅ Qwen Code
cloudflared --version         # ✅ cloudflared
claude -p "ping"              # ✅ Auth Claude
ai-dev teste                   # ✅ Workspace criado (Ctrl+B d pra sair)
ai-kill teste                 # ✅ Cleanup
ai-sessions                     # ✅ Status
exit
ai-dev teste --all             # ✅ Workspace completo do host
```

---

## Segurança

- Container roda como user `dev` (não root)
- Tokens ficam dentro dos volumes (não expostos no YAML)
- `network_swarm_public` dá acesso ao Postgres, Redis, etc. — útil se MCPs precisarem
- Claude Remote Control usa outbound HTTPS — não abre portas
- Limites de CPU/RAM controlados pelo Swarm (`deploy.resources.limits`)
- Pra proteger `~/.bashrc` com tokens: `chmod 600 ~/.bashrc` dentro do container

---

## Manter o repo & publicar atualizações

O projeto usa **GitHub Actions** pra buildar e publicar automaticamente
no GitHub Container Registry (`ghcr.io`) sempre que você fizer push.

### Setup inicial (uma vez)

1. **Criar repo no GitHub**

```bash
cd ~/ai-workspace
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin git@github.com:ffmenezes/ai-workspace.git
git push -u origin main
```

2. **Habilitar GitHub Packages** (já vem ativo por padrão)

3. **Tornar a imagem pública** (opcional, pra outros usarem sem login)
   - GitHub → seu perfil → Packages → ai-workspace → Settings → Change visibility → Public

### Workflow de manutenção

```bash
# 1. Editar Dockerfile, scripts, configs
nano Dockerfile

# 2. Commit + push → GitHub Actions builda automaticamente
git add .
git commit -m "feat: adiciona ferramenta X"
git push

# 3. Acompanhar build
# https://github.com/ffmenezes/ai-workspace/actions

# 4. Após o build (~5-10min), atualizar na VPS
ssh sua-vps
ai-update
```

### Versionamento — v0.x beta permanente, auto-bump no CI

O projeto fica em **v0.x indefinidamente**. Não há plano de lançar v1.0.0
— a versão major fica em 0 pra sempre, sinalizando que o projeto é uma
ferramenta pessoal em evolução constante. Semver permite isso ("anything
goes in 0.x").

**Você não precisa marcar tag.** Cada `git push origin main` dispara o
GitHub Actions, que:

1. Lê a última tag `v0.x.y` do repo
2. Bumpa o patch (`v0.1.5` → `v0.1.6`)
3. Cria a tag nova e empurra de volta pro repo
4. Builda a imagem e publica no GHCR
5. Cria uma GitHub Release marcada como prerelease com changelog do diff

**Quando bumpar minor manualmente** (raro):

Quando você quiser sinalizar uma mudança maior (nova CLI, refator que muda
comportamento, breaking change interna), force um minor bump pusheando uma
tag manual:

```bash
git tag v0.2.0
git push origin main --tags
```

A partir daí, o auto-bump continua de `v0.2.0` → `v0.2.1` → `v0.2.2` ...

> **Detalhe técnico**: tags criadas pelo `GITHUB_TOKEN` do workflow **não
> disparam outro workflow** (proteção do GitHub) — então não há loop infinito
> mesmo com o auto-bump escrevendo de volta no repo.

A Action publica automaticamente:

| Tag da imagem | Quando recebe update | Uso típico |
|---------------|----------------------|------------|
| `:0.1.0` | nunca (pin exato) | produção que não pode mudar |
| `:0.1` | a cada `v0.1.x` | "fica no minor 0.1 e me dê os patches" |
| `:latest` | a cada push em main *ou* tag nova | dev/teste |
| `:sha-abc1234` | nunca (pin por commit) | rollback granular sem precisar taguear |
| `:main` | a cada push em main | bleeding edge |

E cria uma **GitHub Release** marcada como prerelease com changelog
auto-gerado do diff entre tags.

**Pinar no `aiworkspace.yaml`**:

```yaml
# Opção conservadora: pin exato, só atualiza com edição manual
image: ghcr.io/ffmenezes/ai-workspace:0.1.0

# Opção balanceada: recebe patches automaticamente
image: ghcr.io/ffmenezes/ai-workspace:0.1

# Opção cabeça-quente: sempre o último build
image: ghcr.io/ffmenezes/ai-workspace:latest
```

**Atualizar a VPS pra uma versão específica**:

```bash
ai-update ghcr.io/ffmenezes/ai-workspace:0.1.0
ai-update ghcr.io/ffmenezes/ai-workspace:sha-abc1234   # rollback granular
```

---

## Apêndice A: Múltiplas contas GitHub

O GitHub não permite a mesma chave SSH em mais de uma conta. Se você usa
mais de uma conta (pessoal + trabalho), gere uma chave separada pra cada:

```bash
ai-enter

# Chave da conta principal (já criada no passo 7)
# ~/.ssh/id_ed25519

# Gerar chave da segunda conta
ssh-keygen -t ed25519 -C "conta2" -f ~/.ssh/id_ed25519_conta2

# Adicionar a chave pública no GitHub da segunda conta:
cat ~/.ssh/id_ed25519_conta2.pub
```

Criar o config do SSH pra rotear automaticamente:

```bash
cat > ~/.ssh/config << 'EOF'
# Conta principal
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519

# Segunda conta
Host github-conta2
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_conta2
EOF

chmod 600 ~/.ssh/config
```

Uso:

```bash
# Clonar da conta principal (normal):
git clone git@github.com:ffmenezes/meu-repo.git

# Clonar da segunda conta (usa o Host alias):
git clone git@github-conta2:outra-conta/repo.git
```

Dentro de um repo da segunda conta, configure o user local:

```bash
cd ~/projects/repo-conta2
git config user.name "Nome Conta2"
git config user.email "email@conta2.com"
```

Tudo persiste no volume `aiworkspace_ssh`.
