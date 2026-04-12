# CDP ao Vivo — Chrome DevTools remoto no AI Workspace

Este guia ensina a **ver e interagir ao vivo** com o browser headless do container, usando o Chrome DevTools Protocol (CDP). Você conecta o Chrome DevTools do seu PC ao Chromium remoto e pode:

- **Ver** a página renderizada, network, console — tudo em tempo real
- **Interagir** diretamente: digitar em inputs, clicar em botões, modificar o DOM
- **Debugar**: breakpoints, inspecionar elementos, monitorar requests
- **Colaborar com agents**: o agent vê e interage com as mesmas páginas que você

Qualquer ação feita no DevTools é executada no Chromium remoto. Os AI agents podem conectar ao mesmo browser simultaneamente — quando você monta uma página no DevTools, pode pedir ao agent para tirar screenshot, extrair dados, ou interagir programaticamente.

---

## TL;DR — Tunnel completo (clipboard + DevTools)

```bash
# ── VPS host (terminal 1) — criar workspace ──
ai-dev meu-projeto --claude --clipboard --browser

# ── VPS host (terminal 2) — abrir tunnels pro container ──
ai-tunnel 3456 9222

# ── PC local — tunnel até a VPS ──
ssh -L 13456:localhost:3456 -L 19222:localhost:9222 root@<ip-vps>

# ── PC local — usar ──
# Clipboard:  http://localhost:13456        → Ctrl+V cola imagem
# DevTools:   chrome://inspect → Configure  → localhost:19222 → Inspect
```

---

## Modo rápido (recomendado): ai-dev --browser

```bash
# 1. No host da VPS — inicia workspace com Chromium CDP
ai-dev meu-projeto --claude --browser

# 2. No host da VPS (outro terminal) — tunnel
ai-tunnel 9222

# 3. No seu PC — tunnel até a VPS
ssh -L 19222:localhost:9222 root@<ip-vps>

# 4. No Chrome do PC
#    chrome://inspect → Configure → localhost:19222 → Inspect
```

O Chromium fica rodando enquanto o workspace existir. Pode pedir ao agent:
> "Tira um screenshot do que estou vendo no browser"

E ele conecta ao mesmo Chromium via `connectOverCDP('http://localhost:9222')`.

### Combinando com clipboard bridge

```bash
# Clipboard + browser juntos
ai-dev meu-projeto --claude --clipboard --browser

# Tunnel de ambas as portas
ai-tunnel 3456 9222
```

Você cola imagens via clipboard (:3456) e inspeciona o browser via DevTools (:9222).

### Gerenciamento do Chromium

```bash
# No container:
ai-browser          # inicia (idempotente — se já roda, não faz nada)
ai-browser status   # verifica PID + porta
ai-browser stop     # para o Chromium
```

---

## Modo manual (scripts Playwright)

Para fluxos mais controlados (login step-by-step, debug passo a passo), use os scripts Playwright com CDP. Veja [docs/playwright-login/](playwright-login/) para templates prontos.

---

## Pré-requisitos

Antes de começar, confirme que:

1. **O container está rodando** com sshd na porta 2222
2. **A chave SSH do host está no container** (setup one-time, veja abaixo)
3. **Você tem acesso SSH à VPS** a partir do seu PC

### Setup da chave SSH (uma vez só)

No **host da VPS**:

```bash
# 1. Gerar chave se não existir
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519

# 2. Copiar chave pública pro container
cat ~/.ssh/id_ed25519.pub | docker exec -i $(docker ps -q -f name=aiworkspace) tee /home/dev/.ssh/authorized_keys

# 3. Testar conexão
ssh -p 2222 dev@localhost
```

Deve conectar e mostrar o prompt do container. Digite `exit` pra sair.

> **Nota**: se o container for recriado (ai-update), a chave persiste no volume `aiworkspace_ssh`. Mas se o host key do sshd mudar (rebuild da imagem), pode dar aviso de "host key changed" — resolva com `ssh-keygen -R "[localhost]:2222"` no host.

---

## Passo a passo completo

São necessários **3 terminais**: um no container, um no host da VPS, e um no seu PC.

### Terminal 1 — Container (rodar o script CDP)

Entre no container e rode o script:

```bash
# Do host da VPS:
ai-enter

# Dentro do container:
cd ~/projects/<seu-projeto>
node pw-login-cdp.js https://site-alvo.com email@example.com senha123
```

O script vai:
1. Lançar o Chromium com CDP na porta 9222
2. Mostrar "CDP ATIVO EM 0.0.0.0:9222"
3. Pausar e esperar você dar ENTER pra avançar cada passo

**Não aperte ENTER ainda** — primeiro conecte o DevTools.

### Terminal 2 — Host da VPS (tunnel SSH pro container)

```bash
# Cria um tunnel: porta 9222 do host → porta 9222 do container
ai-tunnel 9222
```

Ou manualmente:

```bash
ssh -N -L 9222:localhost:9222 -p 2222 dev@localhost
```

O terminal vai ficar parado (é normal — o tunnel está ativo). Deixe aberto.

**Verificação** (em outro terminal do host):

```bash
curl -s http://localhost:9222/json
```

Deve retornar um JSON com os targets do browser. Se retornar vazio, o script CDP não está rodando ou o tunnel não conectou.

### Terminal 3 — Seu PC (tunnel SSH pra VPS)

```bash
# No PowerShell ou terminal do seu PC:
ssh -L 19222:localhost:9222 root@<ip-da-vps>
```

> **Por que porta 19222?** No Windows, portas abaixo de 1024 (e algumas acima, como 9222) podem dar "Permission denied" se o terminal não estiver como administrador. Usar uma porta alta (19222) evita esse problema.

### Chrome — Conectar o DevTools

1. Abra o Chrome no seu PC
2. Acesse `http://localhost:19222/json` — deve retornar o JSON dos targets
3. Acesse `chrome://inspect`
4. Clique em **"Configure..."**
5. Adicione `localhost:19222`
6. O target `about:blank` aparece em **"Remote Target"**
7. Clique em **"inspect"**

O Chrome DevTools abre conectado ao Chromium remoto. Você vê a página renderizada na aba "Elements", o console, o network — tudo ao vivo.

### Executar o login

Volte ao **Terminal 1** (container) e aperte ENTER para avançar cada passo:

1. **ENTER** → Navega para a URL alvo
2. **ENTER** → Preenche o email
3. **ENTER** → Preenche a senha
4. **ENTER** → Clica no botão de submit
5. **ENTER** → Mostra o resultado final
6. **ENTER** → Fecha o browser

Em cada passo, veja ao vivo no DevTools do seu PC o que acontece.

---

## Diagrama da conexão

```
┌──────────────┐     SSH tunnel      ┌──────────────┐     SSH tunnel      ┌──────────────────┐
│   Seu PC     │ ──────────────────► │   VPS host   │ ──────────────────► │   Container      │
│              │  localhost:19222     │              │  localhost:9222     │                  │
│ Chrome       │ ◄──── WebSocket ──► │  (porta 9222)│ ◄──── TCP ───────► │ Chromium CDP     │
│ DevTools     │                     │              │                     │ (porta 9222)     │
└──────────────┘                     └──────────────┘                     └──────────────────┘
```

---

## Usando com seus próprios scripts

O `pw-login-cdp.js` é um exemplo. Para usar CDP com qualquer script Playwright:

```javascript
const { chromium } = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');
const { spawn } = require('child_process');
const { execSync } = require('child_process');

// 1. Encontra o Chromium
const browserPath = execSync('find /opt/ms-playwright -name "chrome" | head -1').toString().trim();

// 2. Lança Chromium direto com CDP
const proc = spawn(browserPath, [
    '--remote-debugging-port=9222',
    '--remote-debugging-address=0.0.0.0',
    '--headless=new',
    '--no-sandbox',
    '--disable-gpu',
    '--disable-dev-shm-usage',
    'about:blank'
], { stdio: 'pipe' });

// 3. Espera CDP ficar pronto (polling /json)
// ...

// 4. Conecta Playwright via CDP
const browser = await chromium.connectOverCDP('http://localhost:9222');
const page = browser.contexts()[0].pages()[0];

// 5. Usa page normalmente
await page.goto('https://example.com');
// ...
```

**Importante**: NÃO use `chromium.launch({ args: ['--remote-debugging-port=9222'] })` — o Playwright ignora esse argumento e usa sua própria porta CDP interna. Sempre lance o Chromium com `spawn()` e conecte via `connectOverCDP()`.

---

## Outros scripts disponíveis

Se não precisa de CDP ao vivo, existem alternativas mais simples:

| Script | O que faz | Quando usar |
|--------|-----------|-------------|
| `pw-login-screenshots.js` | Screenshots em cada passo | Ver o estado visual em cada etapa |
| `pw-login-video.js` | Grava vídeo .webm + trace | Replay completo depois, sem setup de tunnel |
| `pw-login-cdp.js` | CDP ao vivo com DevTools | Debugar em tempo real, inspecionar DOM/network |

Todos aceitam os mesmos argumentos: `node <script> <url> <email> <senha>`

---

## Referência rápida

```bash
# === SETUP (uma vez) ===
# No host:
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub | docker exec -i $(docker ps -q -f name=aiworkspace) tee /home/dev/.ssh/authorized_keys

# === USO ===
# Terminal 1 (container):   node pw-login-cdp.js <url> <email> <senha>
# Terminal 2 (host VPS):    ai-tunnel 9222
# Terminal 3 (seu PC):      ssh -L 19222:localhost:9222 root@<ip-vps>
# Chrome:                   chrome://inspect → Configure → localhost:19222
```
