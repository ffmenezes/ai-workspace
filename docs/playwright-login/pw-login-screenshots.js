#!/usr/bin/env node
// pw-login-screenshots.js — Login com screenshots step-by-step
// Uso: node pw-login-screenshots.js <url> <email> <senha> [output-dir]

const { chromium } = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');

const URL_TARGET = process.argv[2] || 'https://example.com/login';
const EMAIL = process.argv[3] || 'user@example.com';
const PASSWORD = process.argv[4] || 'password';
const OUT_DIR = process.argv[5] || './pw-output/screenshots';

const fs = require('fs');
fs.mkdirSync(OUT_DIR, { recursive: true });

let step = 0;
async function snap(page, label) {
    step++;
    const file = `${OUT_DIR}/step${String(step).padStart(2, '0')}-${label}.png`;
    await page.screenshot({ path: file, fullPage: true });
    console.log(`[step ${step}] ${label} → ${file}`);
}

async function dumpFormElements(page) {
    return page.evaluate(() => {
        const els = [];
        document.querySelectorAll('input, button, [role="button"], a[href]').forEach(el => {
            const rect = el.getBoundingClientRect();
            if (rect.width === 0 && rect.height === 0) return;
            els.push({
                tag: el.tagName.toLowerCase(),
                type: el.type || '',
                id: el.id || '',
                name: el.name || '',
                placeholder: el.placeholder || '',
                text: el.textContent?.trim().substring(0, 60) || '',
                ariaLabel: el.getAttribute('aria-label') || ''
            });
        });
        return els;
    });
}

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
        } catch { /* selector syntax may not work, try next */ }
    }
    console.error('  ✗ Não encontrou botão de submit');
    return false;
}

(async () => {
    console.log(`\n=== PLAYWRIGHT LOGIN — SCREENSHOTS ===`);
    console.log(`URL: ${URL_TARGET}`);
    console.log(`Email: ${EMAIL}`);
    console.log(`Output: ${OUT_DIR}\n`);

    const browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

    // Step 1: Navegar
    console.log('Navegando...');
    await page.goto(URL_TARGET, { waitUntil: 'networkidle', timeout: 30000 });
    await snap(page, 'pagina-inicial');

    // Dump dos elementos encontrados
    const elements = await dumpFormElements(page);
    console.log(`\nElementos encontrados: ${elements.length}`);
    elements.forEach(el => {
        console.log(`  <${el.tag}> type="${el.type}" id="${el.id}" name="${el.name}" placeholder="${el.placeholder}" text="${el.text}"`);
    });

    // Step 2: Preencher email
    console.log('\nPreenchendo email...');
    await findAndFill(page, 'email', EMAIL);
    await snap(page, 'email-preenchido');

    // Step 3: Preencher senha
    console.log('Preenchendo senha...');
    await findAndFill(page, 'password', PASSWORD);
    await snap(page, 'senha-preenchida');

    // Step 4: Clicar submit
    console.log('Clicando submit...');
    await snap(page, 'antes-submit');
    await findAndClickSubmit(page);

    // Step 5: Aguardar resultado
    console.log('Aguardando resposta...');
    try {
        await page.waitForLoadState('networkidle', { timeout: 10000 });
    } catch { /* timeout ok, page may not navigate */ }
    await new Promise(r => setTimeout(r, 3000));
    await snap(page, 'apos-submit');

    // Step 6: Resultado final
    const finalUrl = page.url();
    console.log(`\nURL final: ${finalUrl}`);

    const errorText = await page.evaluate(() => {
        const errorEls = document.querySelectorAll('[class*="error" i], [class*="alert" i], [role="alert"]');
        return Array.from(errorEls).map(el => el.textContent?.trim()).filter(Boolean).join(' | ');
    });
    if (errorText) console.log(`Mensagens de erro: ${errorText}`);

    await snap(page, 'resultado-final');

    await browser.close();
    console.log(`\nDone! ${step} screenshots em ${OUT_DIR}/`);
})();
