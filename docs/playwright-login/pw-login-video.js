#!/usr/bin/env node
// pw-login-video.js — Login com gravação de vídeo + trace
// Uso: node pw-login-video.js <url> <email> <senha> [output-dir]

const { chromium } = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');

const URL_TARGET = process.argv[2] || 'https://example.com/login';
const EMAIL = process.argv[3] || 'user@example.com';
const PASSWORD = process.argv[4] || 'password';
const OUT_DIR = process.argv[5] || './pw-output/video';

const fs = require('fs');
fs.mkdirSync(OUT_DIR, { recursive: true });

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

(async () => {
    console.log(`\n=== PLAYWRIGHT LOGIN — VÍDEO + TRACE ===`);
    console.log(`URL: ${URL_TARGET}`);
    console.log(`Email: ${EMAIL}`);
    console.log(`Output: ${OUT_DIR}\n`);

    const browser = await chromium.launch();
    const context = await browser.newContext({
        viewport: { width: 1280, height: 720 },
        recordVideo: {
            dir: OUT_DIR,
            size: { width: 1280, height: 720 }
        }
    });

    // Inicia trace (replay detalhado com DOM snapshots)
    await context.tracing.start({
        screenshots: true,
        snapshots: true,
        sources: true
    });

    const page = await context.newPage();

    // Navegar
    console.log('Navegando...');
    await page.goto(URL_TARGET, { waitUntil: 'networkidle', timeout: 30000 });
    await page.waitForTimeout(1000);

    // Preencher email
    console.log('Preenchendo email...');
    await findAndFill(page, 'email', EMAIL);
    await page.waitForTimeout(800);

    // Preencher senha
    console.log('Preenchendo senha...');
    await findAndFill(page, 'password', PASSWORD);
    await page.waitForTimeout(800);

    // Submit
    console.log('Clicando submit...');
    await findAndClickSubmit(page);

    // Aguardar resultado
    console.log('Aguardando resposta...');
    try {
        await page.waitForLoadState('networkidle', { timeout: 10000 });
    } catch { /* ok */ }
    await page.waitForTimeout(3000);

    console.log(`URL final: ${page.url()}`);

    // Salvar trace
    const traceFile = `${OUT_DIR}/trace.zip`;
    await context.tracing.stop({ path: traceFile });
    console.log(`Trace salvo: ${traceFile}`);

    // Fechar context (isso finaliza o vídeo)
    await context.close();
    await browser.close();

    // Listar arquivos gerados
    const files = fs.readdirSync(OUT_DIR);
    console.log(`\nArquivos gerados em ${OUT_DIR}/:`);
    files.forEach(f => console.log(`  - ${f}`));

    console.log(`\nPara ver o trace (no seu PC local):`);
    console.log(`  npx playwright show-trace ${traceFile}`);
    console.log(`\nOu online: https://trace.playwright.dev (arraste o trace.zip)`);
})();
