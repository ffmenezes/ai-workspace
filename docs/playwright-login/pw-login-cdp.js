#!/usr/bin/env node
// pw-login-cdp.js — Login com CDP remoto para acompanhar ao vivo
// Uso: node pw-login-cdp.js <url> <email> <senha> [cdp-port]
//
// COMO FUNCIONA:
//   1. Lança Chromium DIRETO (não via Playwright.launch) com remote debugging
//   2. Conecta Playwright via connectOverCDP
//   3. Você tunela a porta via SSH e vê ao vivo no chrome://inspect
//
// PASSO A PASSO:
//   Terminal 1 (container): node pw-login-cdp.js <url> <email> <senha>
//   Terminal 2 (host VPS):  ai-tunnel 9222
//   Terminal 3 (seu PC):    ssh -L 19222:localhost:9222 root@<vps-ip>
//   Seu Chrome:             chrome://inspect → Configure → localhost:19222

const { chromium } = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');
const { execSync, spawn } = require('child_process');
const readline = require('readline');

const URL_TARGET = process.argv[2] || 'https://example.com/login';
const EMAIL = process.argv[3] || 'user@example.com';
const PASSWORD = process.argv[4] || 'password';
const CDP_PORT = process.argv[5] || '9222';

async function findAndFill(page, fieldType, value) {
    const strategies = fieldType === 'email'
        ? [
            'input[type="email"]',
            'input[name="email"]',
            'input[autocomplete="email"]',
            'input[placeholder*="mail" i]',
            'input[placeholder*="usu" i]',
            'input[type="text"]:first-of-type'
        ]
        : [
            'input[type="password"]',
            'input[name="password"]',
            'input[name="senha"]',
            'input[autocomplete="current-password"]',
            'input[placeholder*="senha" i]',
            'input[placeholder*="pass" i]'
        ];

    for (const sel of strategies) {
        const el = await page.$(sel);
        if (el && await el.isVisible()) {
            await el.fill(value);
            console.log(`  → ${fieldType} preenchido via: ${sel}`);
            return true;
        }
    }
    console.error(`  ✗ Não encontrou campo de ${fieldType}`);
    return false;
}

async function findAndClickSubmit(page) {
    const strategies = [
        'button[type="submit"]',
        'input[type="submit"]',
        'button:has-text("Entrar")',
        'button:has-text("Login")',
        'button:has-text("Sign in")',
        'button:has-text("Acessar")',
        '[role="button"]:has-text("Entrar")',
        'form button',
        'button'
    ];

    for (const sel of strategies) {
        try {
            const el = await page.$(sel);
            if (el && await el.isVisible()) {
                await el.click();
                console.log(`  → submit clicado via: ${sel}`);
                return true;
            }
        } catch { /* next */ }
    }
    console.error('  ✗ Não encontrou botão de submit');
    return false;
}

function waitForEnter(msg) {
    return new Promise(resolve => {
        const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
        rl.question(`\n⏸  ${msg} [ENTER para continuar] `, () => {
            rl.close();
            resolve();
        });
    });
}

function findChromium() {
    const browserPath = process.env.PLAYWRIGHT_BROWSERS_PATH || '/opt/ms-playwright';
    try {
        const result = execSync(`find ${browserPath} -name "chromium" -o -name "chrome" | head -1`).toString().trim();
        if (result) return result;
    } catch {}
    return chromium.executablePath();
}

(async () => {
    console.log(`\n=== PLAYWRIGHT LOGIN — CDP AO VIVO ===`);
    console.log(`URL: ${URL_TARGET}`);
    console.log(`Email: ${EMAIL}`);
    console.log(`CDP Port: ${CDP_PORT}\n`);

    // 1. Encontra o executável do Chromium
    const chromiumPath = findChromium();
    console.log(`Chromium: ${chromiumPath}`);

    // 2. Lança Chromium DIRETAMENTE com remote debugging
    console.log(`Lançando Chromium com CDP na porta ${CDP_PORT}...`);
    const chromiumProcess = spawn(chromiumPath, [
        `--remote-debugging-port=${CDP_PORT}`,
        '--remote-debugging-address=0.0.0.0',
        '--headless=new',
        '--no-sandbox',
        '--disable-gpu',
        '--disable-dev-shm-usage',
        '--window-size=1280,720',
        'about:blank'
    ], { stdio: 'pipe' });

    // Espera o CDP ficar pronto
    console.log('Aguardando CDP ficar pronto...');
    for (let i = 0; i < 30; i++) {
        try {
            const http = require('http');
            await new Promise((resolve, reject) => {
                http.get(`http://localhost:${CDP_PORT}/json/version`, res => {
                    let data = '';
                    res.on('data', chunk => data += chunk);
                    res.on('end', () => resolve(data));
                }).on('error', reject);
            });
            console.log('CDP pronto!');
            break;
        } catch {
            await new Promise(r => setTimeout(r, 500));
        }
    }

    // Verifica se está ouvindo
    try {
        const http = require('http');
        const version = await new Promise((resolve, reject) => {
            http.get(`http://localhost:${CDP_PORT}/json/version`, res => {
                let data = '';
                res.on('data', chunk => data += chunk);
                res.on('end', () => resolve(JSON.parse(data)));
            }).on('error', reject);
        });
        console.log(`Browser: ${version.Browser}`);
        console.log(`WebSocket: ${version.webSocketDebuggerUrl}`);
    } catch (e) {
        console.error('ERRO: CDP não respondeu. Chromium pode não ter iniciado.');
        console.error(e.message);
        chromiumProcess.kill();
        process.exit(1);
    }

    console.log(`\n════════════════════════════════════════════════`);
    console.log(`  CDP ATIVO EM 0.0.0.0:${CDP_PORT}`);
    console.log(`════════════════════════════════════════════════`);
    console.log(`\nNo host da VPS:`);
    console.log(`  ai-tunnel ${CDP_PORT}`);
    console.log(`\nNo seu PC:`);
    console.log(`  ssh -L 19222:localhost:${CDP_PORT} root@<vps-ip>`);
    console.log(`\nNo Chrome:`);
    console.log(`  chrome://inspect → Configure → localhost:19222`);

    await waitForEnter('Conectou o DevTools? Vamos começar o login');

    // 3. Conecta Playwright via CDP
    console.log('Conectando Playwright ao Chromium via CDP...');
    const browser = await chromium.connectOverCDP(`http://localhost:${CDP_PORT}`);
    const context = browser.contexts()[0] || await browser.newContext({ viewport: { width: 1280, height: 720 } });
    const page = context.pages()[0] || await context.newPage();

    // Step 1: Navegar
    console.log('\n[1/5] Navegando...');
    await page.goto(URL_TARGET, { waitUntil: 'networkidle', timeout: 30000 });
    console.log(`Página carregada: ${page.url()}`);
    await waitForEnter('Página carregada. Próximo: preencher email');

    // Step 2: Preencher email
    console.log('\n[2/5] Preenchendo email...');
    await findAndFill(page, 'email', EMAIL);
    await waitForEnter('Email preenchido. Próximo: preencher senha');

    // Step 3: Preencher senha
    console.log('\n[3/5] Preenchendo senha...');
    await findAndFill(page, 'password', PASSWORD);
    await waitForEnter('Senha preenchida. Próximo: clicar submit');

    // Step 4: Submit
    console.log('\n[4/5] Clicando submit...');
    await findAndClickSubmit(page);
    await waitForEnter('Submit clicado. Próximo: ver resultado');

    // Step 5: Resultado
    console.log('\n[5/5] Resultado...');
    try {
        await page.waitForLoadState('networkidle', { timeout: 10000 });
    } catch { /* ok */ }
    await new Promise(r => setTimeout(r, 3000));

    console.log(`URL final: ${page.url()}`);

    const errorText = await page.evaluate(() => {
        const errorEls = document.querySelectorAll('[class*="error" i], [class*="alert" i], [role="alert"]');
        return Array.from(errorEls).map(el => el.textContent?.trim()).filter(Boolean).join(' | ');
    });
    if (errorText) console.log(`Mensagens de erro: ${errorText}`);

    await waitForEnter('Finalizar e fechar browser');

    await browser.close();
    chromiumProcess.kill();
    console.log('\nBrowser fechado. Done!');
})();
