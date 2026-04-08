# AI Workspace — Deploy Guide

Setup containerizado de Claude Code + Gemini CLI + Qwen Code + Lightpanda
no Docker Swarm, com persistência em volumes e acesso via Termius.

---

## TL;DR

```bash
# 1. Na VPS: descompactar, buildar, deploy
cd ~/ai-workspace
docker build -t ai-workspace:latest .
# Deploy via Portainer (Stacks → Add Stack → colar stack-aiworkspace.yaml)

# 2. Instalar atalhos no host
bash setup-host-aliases.sh && source ~/.bashrc

# 3. Entrar e autenticar (uma vez só)
aiw
claude /login                   # segue a URL no browser
export GEMINI_API_KEY="key"     # https://aistudio.google.com/apikey
echo 'export GEMINI_API_KEY="key"' >> ~/.bashrc
qwen                            # Qwen OAuth gratuito (1000 req/dia)
ssh-keygen -t ed25519 -C "ai-workspace"   # adicionar pub key no GitHub
exit

# 4. Usar
aidev meu-projeto                          # só Claude + shell (leve)
aidev meu-projeto --gemini                 # Claude + Gemini
aidev meu-projeto --qwen                   # Claude + Qwen
aidev meu-projeto --all                    # Claude + Gemini + Qwen + Browser
aidev meu-projeto --rc                     # + Remote Control (celular)
aidev meu-projeto --danger                 # skip-permissions + yolo
aidev meu-projeto --gemini --qwen --rc     # combina o que quiser
aidanger meu-projeto                       # atalho pra --all --danger

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

Um comando (`aidev nome`) cria o workspace completo. Múltiplos projetos rodam
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
│   └── ai-workspace (container)        ← Claude + Gemini + Qwen + Lightpanda
│       ├── /home/dev/projects  → vol   ← repos, código
│       ├── /home/dev/.config   → vol   ← auth tokens, settings
│       ├── /home/dev/.claude   → vol   ← skills, CLAUDE.md
│       ├── /home/dev/.gemini   → vol   ← sessions, memory
│       └── /home/dev/.ssh      → vol   ← chaves SSH
│
└── Host
    └── aiw / aidev / aidanger          ← atalhos pra entrar no container
```

### Por que `node:22-bookworm-slim`?

| Critério | Decisão |
|----------|---------|
| **Node.js** | Gemini CLI e Qwen Code requerem Node.js 20+. A base já inclui Node 22 LTS + npm. |
| **glibc vs musl** | Claude Code, Lightpanda e uv distribuem binários nativos linkados contra glibc. Alpine (musl) causa crash. |
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
> echo "$GITHUB_TOKEN" | docker login ghcr.io -u SEU_USUARIO --password-stdin
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
4. Colar o conteúdo de `stack-aiworkspace.yaml`
5. Clicar **Deploy the stack**

**Alternativa via CLI:**
```bash
docker stack deploy -c stack-aiworkspace.yaml aiworkspace
```

---

## Passo 5: Configurar aliases no host

```bash
cd ~/ai-workspace
bash setup-host-aliases.sh
source ~/.bashrc
```

Adiciona os atalhos `aiw`, `ait`, `aidev`, `aidanger`, `aiws` ao host.

---

## Passo 6: Autenticar as CLIs

```bash
aiw

# ── Claude Code (subscription Pro/Max) ──
claude /login
# Vai mostrar uma URL — copie e abra no browser
# O token fica salvo em ~/.claude/ (volume persistente)
claude -p "ping"

# ── Gemini CLI ──
# Gere API key em: https://aistudio.google.com/apikey
export GEMINI_API_KEY="sua-api-key"
echo 'export GEMINI_API_KEY="sua-api-key"' >> ~/.bashrc
gemini --version

# ── Qwen Code ──
# Opção A: Qwen OAuth (gratuito, 1000 req/dia)
qwen
# Na primeira execução, escolha "Qwen OAuth (Free)" e siga o browser

# Opção B: API key (DashScope, OpenRouter, etc.)
# export OPENAI_API_KEY="sua-key"
# export OPENAI_BASE_URL="https://dashscope.aliyuncs.com/compatible-mode/v1"
# export OPENAI_MODEL="qwen3-coder-plus"
```

> **NOTA**: A auth do Claude persiste no volume `aiworkspace_claude`.
> A API key do Gemini fica no `~/.bashrc` dentro do container — se recriar
> o container, re-exporte ou configure direto no YAML do stack.

---

## Passo 7: Configurar GitHub e clonar projetos

```bash
aiw

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
aidev meu-projeto
```

A chave SSH persiste no volume `aiworkspace_ssh` — não precisa refazer no rebuild.
Para múltiplas contas GitHub, veja o **Apêndice A** no final deste documento.

---

## Uso diário

### Comando `aidev` — workspace modular

O `aidev` sempre abre Claude Code + shell. Os demais agents são opcionais:

```bash
# Só Claude (leve, ~100MB RAM)
aidev meu-projeto

# Claude + Gemini
aidev meu-projeto --gemini

# Claude + Qwen
aidev meu-projeto --qwen

# Claude + Gemini + Qwen + Browser (completo)
aidev meu-projeto --all

# Combinar flags livremente
aidev meu-projeto --gemini --browser --rc

# Modo danger (skip-permissions + yolo em todos)
aidev meu-projeto --danger
aidev meu-projeto --all --danger
aidanger meu-projeto                   # atalho pra --all --danger
```

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
ai-status                            # ver tudo que tá rodando
```

### Múltiplos projetos ao mesmo tempo

Cada `aidev` cria uma sessão tmux **independente**. Pra ter dois projetos
abertos simultaneamente:

```bash
# Abre o primeiro
aidev projeto-a --all
# Trabalha, e quando quiser sair sem matar:
Ctrl+B d

# Abre o segundo (cria nova sessão)
aidev projeto-b --all
Ctrl+B d

# Alterna entre eles:
Ctrl+B s          # menu visual com setas
# ou
tmux attach -t projeto-a
```

### Reconectar a um projeto

```bash
aidev meu-projeto    # se a sessão já existe, reconecta direto
```

### Pelo app Claude (celular)

Quando usar `--rc`, o Claude Code ativa Remote Control.
Abra o app Claude no celular → sessão aparece automaticamente com UX nativa.

### Lightpanda (headless browser)

Sobe automaticamente quando usar `--browser` ou `--all`.
Qualquer ferramenta que precise de browser se conecta em `ws://localhost:9222`.

```bash
# Dump rápido de uma página
lightpanda fetch https://example.com

# Puppeteer: browserWSEndpoint: "ws://localhost:9222"
# Playwright: browser = await chromium.connectOverCDP("http://localhost:9222")
```

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
aiw
cd ~/projects/meu-projeto
ralph
# Escolhe o agent, digita o prompt, configura loops, confirma
```

**Modo direto:**

```bash
aiw
cd ~/projects/meu-projeto
ralph -a claude -p "implemente os testes do módulo auth" -d -m 30
ralph -a gemini -f prompt.md
ralph -a qwen -p "refatore o componente X" --done "FINALIZADO"
```

**Flags:**

| Flag | Descrição | Default |
|------|-----------|---------|
| `-a, --agent` | claude, gemini ou qwen | claude |
| `-p, --prompt` | prompt inline | — |
| `-f, --file` | prompt de arquivo | — |
| `-m, --max` | máximo de loops | 50 |
| `-d, --danger` | skip-permissions/yolo | false |
| `--done` | palavra de parada | RALPH_DONE |

**Teste rápido (pasta vazia):**

```bash
aiw
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
aiw
cd ~/projects/meu-projeto
ralph -a claude -f prompt.md -d    # inicia o loop
# Ctrl+C se quiser parar manualmente
# Ou deixa rodar, sai do container (exit), faz detach (Ctrl+B d)
# O loop continua na VPS
# Volta depois: aiw → cd ~/projects/meu-projeto → cat .ralph-logs/loop-*.log
```

---

## Snippets do Termius

Configure em **Settings > Snippets**:

| Nome     | Comando                        | Descrição                      |
|----------|--------------------------------|--------------------------------|
| `aiw`    | `aiw`                          | Entrar no container            |
| `dev`    | `aidev `                       | Workspace só Claude            |
| `dev+`   | `aidev  --all`                 | Workspace completo             |
| `dev-rc` | `aidev  --rc`                  | Workspace + Remote Control     |
| `ws`     | `aiws`                         | Status das sessões             |

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

### Atualizar a imagem (recomendado)

A imagem é mantida no GitHub Container Registry e atualizada automaticamente
via GitHub Actions. Pra puxar a versão mais nova:

```bash
# Atalho simples
aiupdate

# O que ele faz por trás:
docker pull ghcr.io/ffmenezes/ai-workspace:latest
docker service update --image ghcr.io/ffmenezes/ai-workspace:latest --force aiworkspace_workspace
```

Os volumes persistem — projetos, auth, SSH keys, tudo preservado.

### Atualizar ferramentas pontualmente (sem rebuild)

```bash
aiw

# Claude Code — atualiza automaticamente (native installer)
claude --version

# Gemini CLI
npm update -g @google/gemini-cli

# Qwen Code
npm update -g @qwen-code/qwen-code

# Cursor CLI — atualiza automaticamente
cursor --version
```

### Backup dos volumes

```bash
for vol in projects config claude gemini ssh; do
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
aiw                           # ✅ Entrou no container
claude --version              # ✅ Claude Code
gemini --version              # ✅ Gemini CLI
qwen --version                # ✅ Qwen Code
lightpanda --help             # ✅ Lightpanda
cloudflared --version         # ✅ cloudflared
claude -p "ping"              # ✅ Auth Claude
aidev teste                   # ✅ Workspace criado (Ctrl+B d pra sair)
ai-kill teste                 # ✅ Cleanup
ai-status                     # ✅ Status
exit
aidev teste --all             # ✅ Workspace completo do host
```

---

## Segurança

- Container roda como user `dev` (não root)
- Tokens ficam dentro dos volumes (não expostos no YAML)
- `network_swarm_public` dá acesso ao Postgres, Redis, etc. — útil se MCPs precisarem
- Claude Remote Control usa outbound HTTPS — não abre portas
- Lightpanda CDP server roda interno ao container (não exposto ao host)
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
git remote add origin git@github.com:SEU_USUARIO/ai-workspace.git
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
# https://github.com/SEU_USUARIO/ai-workspace/actions

# 4. Após o build (~5-10min), atualizar na VPS
ssh sua-vps
aiupdate
```

### Versionamento (tags)

Pra marcar releases estáveis:

```bash
git tag v1.0.0
git push --tags
```

A Action vai publicar 3 tags da imagem: `latest`, `1.0.0`, `1.0`. Aí
outras pessoas podem fixar versão:

```yaml
image: ghcr.io/SEU_USUARIO/ai-workspace:1.0.0
```

### Pull manual de versões específicas

```bash
docker pull ghcr.io/SEU_USUARIO/ai-workspace:1.0.0
docker pull ghcr.io/SEU_USUARIO/ai-workspace:latest
```

---

## Apêndice A: Múltiplas contas GitHub

O GitHub não permite a mesma chave SSH em mais de uma conta. Se você usa
mais de uma conta (pessoal + trabalho), gere uma chave separada pra cada:

```bash
aiw

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
