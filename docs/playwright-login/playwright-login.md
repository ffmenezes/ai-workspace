---
name: playwright-login
description: "Templates de login automatizado com Playwright. Tres modos: screenshots step-by-step, video+trace, e CDP ao vivo. Use quando o usuario pedir para testar login, automatizar autenticacao, debugar formulario, ou ver browser ao vivo."
argument-hint: "<url> <email> <senha>"
disable-model-invocation: true
allowed-tools: Read Write Bash(node *) Glob Grep
effort: medium
---

# Playwright Login Templates

Tres scripts para automatizar e debugar fluxos de login em qualquer site. Cada um tem um proposito diferente:

| Script | Proposito | Output |
|--------|-----------|--------|
| `pw-login-screenshots.js` | Ver o estado visual de cada etapa | PNGs em `./pw-output/screenshots/` |
| `pw-login-video.js` | Replay completo com trace interativo | `.webm` + `trace.zip` em `./pw-output/video/` |
| `pw-login-cdp.js` | Debugar ao vivo via Chrome DevTools | CDP na porta 9222, requer SSH tunnel |

## Como usar

Os scripts estao nesta pasta como templates. Copie para o projeto e rode:

```bash
# Copiar para o projeto
cp ~/.agents/skills/playwright-login/pw-login-*.js ~/projects/<projeto>/

# Rodar
cd ~/projects/<projeto>
node pw-login-screenshots.js https://site.com email@test.com senha123
node pw-login-video.js https://site.com email@test.com senha123
node pw-login-cdp.js https://site.com email@test.com senha123
```

Todos os argumentos sao opcionais — sem argumentos, o script pede que voce edite os defaults.

## Modo CDP (ao vivo)

O `pw-login-cdp.js` lanca Chromium com remote debugging e pausa entre cada passo. Requer SSH tunnel para acessar do PC:

1. Container: `node pw-login-cdp.js <url> <email> <senha>`
2. Host VPS: `ai-tunnel 9222`
3. PC: `ssh -L 19222:localhost:9222 root@<ip-vps>`
4. Chrome: `chrome://inspect` → Configure → `localhost:19222`

Tutorial completo: veja `docs/cdp-live-debugging.md`

## Detalhes tecnicos

- Playwright esta instalado globalmente — scripts usam require dinamico:
  ```js
  const { chromium } = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');
  ```
- O CDP script lanca Chromium com `spawn()` (nao `chromium.launch()`) porque Playwright ignora `--remote-debugging-port` nos args de launch
- Chromium esta em `/opt/ms-playwright`
- Estrategias de preenchimento cobrem campos por type, name, autocomplete, placeholder (PT-BR e EN)

## Customizacao

Para adaptar a outro tipo de formulario (ex: cadastro, checkout), edite as funcoes `findAndFill()` e `findAndClickSubmit()` — elas usam listas de seletores CSS tentados em ordem.
