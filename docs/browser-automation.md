# Browser Automation no AI Workspace

O container inclui **3 ferramentas de browser** complementares, cada uma com um papel diferente:

| Ferramenta | Tipo | Quando usar |
|---|---|---|
| **agent-browser** | CLI nativo (Rust) | AI agents automatizando sites (skill padrão) |
| **Playwright** | Framework Node.js | Scripts programáticos, testes E2E, codegen |
| **Lightpanda** | Headless browser | Scraping rápido, baixo consumo de memória |

---

## 1. agent-browser (recomendado para AI agents)

CLI da Vercel Labs otimizado para AI coding agents. Usa snapshots textuais com refs (`@e1`, `@e2`) em vez de DOM bruto — extremamente eficiente em tokens.

**Já vem como skill global** em `~/.agents/skills/agent-browser/` — todos os 8 CLIs (Claude, Gemini, Qwen, Cursor, OpenCode, Codex, Cline, Aider) reconhecem automaticamente via `setup-agent-links`.

### Uso no terminal

```bash
# Navegar e ver elementos interativos
agent-browser open https://example.com
agent-browser snapshot -i

# Preencher formulário
agent-browser fill @e1 "email@test.com"
agent-browser fill @e2 "senha123"
agent-browser click @e3

# Screenshot
agent-browser screenshot
agent-browser screenshot --full        # página inteira
agent-browser screenshot --annotate    # com labels numerados nos elementos

# Batch (múltiplos comandos em uma chamada)
agent-browser batch "open https://example.com" "snapshot -i" "screenshot"

# Usar Lightpanda como engine (10x mais rápido, 10x menos memória)
agent-browser --engine lightpanda open https://example.com
```

### Uso nas AI CLIs

Qualquer agent pode usar browser automation automaticamente — a skill `agent-browser` já está carregada. Basta pedir:

> "Abre o site X e preenche o formulário de contato"
> "Faz um screenshot do dashboard em https://app.exemplo.com"
> "Scrape os preços de todos os produtos nessa página"
> "Testa se o formulário de login funciona"

O agent vai usar `agent-browser` internamente (open → snapshot → interact → re-snapshot).

### Sessões persistentes (auth)

```bash
# Salvar credenciais encriptadas (vault)
echo "$SENHA" | agent-browser auth save meuapp \
    --url https://app.exemplo.com/login \
    --username usuario \
    --password-stdin

# Login automático (agent nunca vê a senha)
agent-browser auth login meuapp

# Sessão com cookies persistentes
agent-browser --session-name meuapp open https://app.exemplo.com/login
# ... fluxo de login ...
agent-browser close   # estado auto-salvo

# Próxima vez: estado auto-restaurado
agent-browser --session-name meuapp open https://app.exemplo.com/dashboard
```

### Configuração por projeto

Crie `agent-browser.json` na raiz do projeto:

```json
{
  "colorScheme": "dark",
  "viewport": { "width": 1920, "height": 1080 }
}
```

---

## 2. Playwright (framework completo)

O Playwright está instalado globalmente (`npm i -g playwright`) com **Chromium** em `/opt/ms-playwright`. Indicado para:

- Scripts programáticos complexos (Node.js API)
- Testes E2E automatizados
- Gravação de interações (`codegen`)
- Geração de PDFs

### Comandos úteis no terminal

```bash
# Verificar instalação
npx playwright --version

# Gravar interações e gerar código automaticamente
# (abre browser headless, grava ações, gera script Node.js)
npx playwright codegen https://example.com --output script.js

# Executar script gerado
node script.js

# Tirar screenshot via CLI
npx playwright screenshot https://example.com screenshot.png

# Gerar PDF de uma página
npx playwright pdf https://example.com page.pdf

# Rodar testes E2E (se o projeto tiver tests/)
npx playwright test
npx playwright test --headed        # com browser visível (precisa de display)
npx playwright show-report          # relatório HTML do último test run
```

### Script Node.js (API programática)

Crie um arquivo `.js` e execute com `node`:

```javascript
// scrape-precos.js
const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage();

    await page.goto('https://exemplo.com/produtos');

    // Extrair todos os preços
    const precos = await page.$$eval('.preco', els =>
        els.map(el => ({
            nome: el.closest('.produto').querySelector('.nome').textContent,
            valor: el.textContent.trim()
        }))
    );

    console.log(JSON.stringify(precos, null, 2));
    await browser.close();
})();
```

```bash
node scrape-precos.js
```

### Script com login + screenshot

```javascript
// dashboard-screenshot.js
const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage();

    // Login
    await page.goto('https://app.exemplo.com/login');
    await page.fill('#email', 'usuario@teste.com');
    await page.fill('#password', 'senha123');
    await page.click('button[type="submit"]');

    // Esperar dashboard carregar
    await page.waitForURL('**/dashboard');

    // Screenshot full page
    await page.screenshot({ path: 'dashboard.png', fullPage: true });

    // Gerar PDF
    await page.pdf({ path: 'dashboard.pdf', format: 'A4' });

    await browser.close();
})();
```

### Teste E2E básico

```javascript
// tests/login.spec.js
const { test, expect } = require('@playwright/test');

test('login funciona', async ({ page }) => {
    await page.goto('https://app.exemplo.com/login');
    await page.fill('#email', 'test@test.com');
    await page.fill('#password', 'test123');
    await page.click('button[type="submit"]');

    await expect(page).toHaveURL(/dashboard/);
    await expect(page.locator('h1')).toContainText('Dashboard');
});
```

```bash
npx playwright test tests/login.spec.js
```

### Usar nas AI CLIs

Os agents podem criar e executar scripts Playwright quando a tarefa exige lógica programática complexa que o agent-browser não cobre (ex: loops, condicionais, transformação de dados):

> "Cria um script Playwright que faz login, navega por todas as páginas de produtos, e exporta os dados em CSV"

O agent vai criar um `.js` e rodar com `node`.

---

## 3. Lightpanda (headless leve)

Browser headless escrito em Zig, focado em performance. **10x mais rápido** e **10x menos memória** que Chromium. Ideal para scraping simples onde não precisa de JavaScript completo.

### Uso direto

```bash
# Fetch de conteúdo (similar a curl, mas renderiza JS)
lightpanda fetch https://example.com

# Com output em arquivo
lightpanda fetch https://example.com > page.html
```

### Via agent-browser

```bash
# Engine flag (recomendado — aproveita toda a UX do agent-browser)
agent-browser --engine lightpanda open https://example.com
agent-browser snapshot -i

# Via env var (aplica pra toda a sessão)
export AGENT_BROWSER_ENGINE=lightpanda
agent-browser open https://example.com
```

### Limitações do Lightpanda

- Sem suporte a `--profile`, `--state`, `--extension`, `--allow-file-access`
- JavaScript engine mais limitado que V8/Chromium
- Alguns sites com SPAs complexas podem não renderizar corretamente
- Sem suporte a WebGL, Web Audio, etc.

**Regra prática**: Use Lightpanda para scraping de conteúdo estático ou semi-estático. Se o site não renderizar bem, troque para Chromium (engine padrão do agent-browser).

---

## Qual usar? (decisão rápida)

```
Precisa de browser automation?
├── AI agent fazendo a tarefa? → agent-browser (skill automática)
│   ├── Site simples/rápido? → --engine lightpanda
│   └── Site complexo/SPA? → engine padrão (chromium)
├── Script programático? → Playwright (Node.js API)
│   ├── Testes E2E? → npx playwright test
│   ├── Gravar interação? → npx playwright codegen
│   └── Scraping complexo com lógica? → script .js + node
└── Fetch rápido com JS rendering? → lightpanda fetch
```

---

## 4. Shared Chromium CDP (ai-dev --browser)

Quando o workspace é iniciado com `--browser`, um Chromium headless permanece rodando com CDP na porta 9222. Isso habilita:

- **DevTools bidirecional**: o dev vê e interage via `chrome://inspect` no PC
- **Agents conectam via CDP**: Playwright `connectOverCDP()` ou `agent-browser --cdp 9222`
- **Mesmo browser para todos**: dev e agents veem as mesmas abas e estado

### Início rápido

```bash
# No host da VPS:
ai-dev meu-projeto --claude --browser

# Em outro terminal do host:
ai-tunnel 9222

# No PC:
ssh -L 19222:localhost:9222 root@<ip-vps>
# Chrome: chrome://inspect → Configure → localhost:19222
```

### Uso por agents

Agents com a skill `cdp-shared` sabem conectar automaticamente. Basta pedir:

> "Tira um screenshot do que estou vendo no browser"
> "Abre uma nova aba em https://example.com"
> "O que tem na página que estou olhando?"

O agent conecta ao Chromium compartilhado via `connectOverCDP('http://localhost:9222')`.

### Gerenciamento direto

```bash
ai-browser          # inicia (idempotente)
ai-browser status   # verifica se está rodando
ai-browser stop     # para o Chromium
```

### Regras importantes

- **Nunca fechar o browser** (`browser.close()`) — ele é compartilhado
- **Nunca lançar novo** (`chromium.launch()`) — sempre conectar ao existente
- **Screenshots em `~/.clipboard/`** — para fácil referência com `@path`

### Combinando com ai-clipboard

```bash
# Workspace completo: agent + clipboard + browser
ai-dev meu-projeto --claude --clipboard --browser
```

O dev cola imagens via clipboard bridge (:3456), o agent tira screenshots via CDP (:9222), e ambos salvam em `~/.clipboard/` para referência cruzada.

---

## Variáveis de ambiente relevantes

| Variável | Valor no container | Descrição |
|---|---|---|
| `PLAYWRIGHT_BROWSERS_PATH` | `/opt/ms-playwright` | Onde o Chromium está instalado |
| `LIGHTPANDA_DISABLE_TELEMETRY` | `true` | Telemetria desabilitada |
| `AGENT_BROWSER_ENGINE` | (não definido) | Engine padrão: `chrome`. Setar `lightpanda` para usar Lightpanda |
| `AGENT_BROWSER_CONTENT_BOUNDARIES` | (não definido) | Setar `1` para segurança (marca conteúdo de página vs output de tool) |
| `AGENT_BROWSER_MAX_OUTPUT` | (não definido) | Limite de output para evitar flooding de contexto |
| `AGENT_BROWSER_IDLE_TIMEOUT_MS` | (não definido) | Auto-shutdown do daemon após inatividade |

---

## Troubleshooting

### "Browser not found" / "Executable doesn't exist"

```bash
# Verificar se Chromium está instalado
ls /opt/ms-playwright/
echo $PLAYWRIGHT_BROWSERS_PATH

# Verificar se agent-browser detecta
agent-browser install --dry-run
```

### "Permission denied" ao rodar Playwright/agent-browser

```bash
# Verificar permissões (deve ser a+rX)
ls -la /opt/ms-playwright/

# Se perdeu permissões, pedir ao host:
# (do host) ai-fix-perms
```

### Agent não usa browser automaticamente

Verificar se a skill está presente no projeto:

```bash
# Deve existir SKILL.md aqui:
ls -la .agents/skills/agent-browser/SKILL.md

# Se não existir, rodar manualmente:
setup-agent-links
# Ou reentrar no projeto:
# (do host) ai-dev <projeto>
```

### Lightpanda não renderiza site corretamente

```bash
# Trocar para Chromium (engine padrão)
agent-browser --engine chrome open https://site-problematico.com

# Ou remover a env var se estava setada globalmente
unset AGENT_BROWSER_ENGINE
```

### Chromium crash / OOM

O container tem limite de 2GB RAM (`aiworkspace.yaml`). Chromium com muitas tabs pode estourar.

```bash
# Fechar todas as sessões de browser
agent-browser close --all

# Monitorar memória
htop
```

Se precisar de mais memória para browser automation intensiva, aumentar o limite em `aiworkspace.yaml`:

```yaml
resources:
  limits:
    memory: 4096M
```
