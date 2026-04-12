---
name: cdp-shared
description: Connect to the shared Chromium CDP instance running in the container. Use when the user asks you to interact with a browser they have open, take a screenshot of what they see, inspect a page, or when you need browser automation and `--browser` was passed to ai-dev. Triggers include "screenshot what I see", "take a screenshot of the browser", "what's on the page", "interact with the browser", "open a tab", "check the page I'm looking at".
allowed-tools: Bash(node *), Bash(curl *), Bash(agent-browser *)
---

# Shared Chromium CDP

The AI Workspace can run a shared Chromium instance with Chrome DevTools Protocol (CDP) enabled on port 9222. This is started when the user runs `ai-dev <project> --browser`.

The same Chromium instance is accessible to:
- **You (the AI agent)** — via CDP for automation, screenshots, interaction
- **The human developer** — via Chrome DevTools on their PC (`chrome://inspect`)

This means you can see and interact with the exact same browser and pages the developer is looking at. If they set up a page in DevTools, you can screenshot it. If you navigate to a URL, they see it live.

## Checking if CDP is available

```bash
# Quick health check
curl -sf http://localhost:9222/json/version && echo "CDP available" || echo "CDP not running"

# List open tabs
curl -sf http://localhost:9222/json | jq '.[].url'
```

If CDP is not running, tell the user to restart with `--browser`:
```
ai-dev <project> --browser
```

Or start it directly:
```bash
ai-browser        # starts on port 9222
ai-browser status # check status
```

## Taking a screenshot of what the developer sees

The developer interacts with the browser via DevTools on their PC. To screenshot the page they're looking at:

```javascript
// save as /tmp/screenshot.js and run with: node /tmp/screenshot.js
const pw = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');

(async () => {
    const browser = await pw.chromium.connectOverCDP('http://localhost:9222');
    const contexts = browser.contexts();
    if (contexts.length === 0) { console.log('No browser contexts'); process.exit(1); }
    const pages = contexts[0].pages();

    // List all tabs
    for (let i = 0; i < pages.length; i++) {
        console.log(`Tab ${i}: ${pages[i].url()}`);
    }

    // Screenshot the last active tab (usually the one the dev is looking at)
    const target = pages[pages.length - 1];
    const path = `/home/dev/.clipboard/screenshot-${Date.now()}.png`;
    await target.screenshot({ path });
    console.log(`Screenshot saved: ${path}`);

    // IMPORTANT: do NOT close the browser — it's shared!
})();
```

```bash
node /tmp/screenshot.js
```

Or using agent-browser (simpler, if it supports CDP connection):

```bash
agent-browser --cdp 9222 screenshot
```

## Opening a new tab

```javascript
const pw = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');

(async () => {
    const browser = await pw.chromium.connectOverCDP('http://localhost:9222');
    const context = browser.contexts()[0];
    const page = await context.newPage();
    await page.goto('https://example.com');
    console.log('Opened: ' + page.url());
    // The developer will see this new tab appear in their DevTools
})();
```

## Interacting with a page

```javascript
const pw = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');

(async () => {
    const browser = await pw.chromium.connectOverCDP('http://localhost:9222');
    const pages = browser.contexts()[0].pages();
    const page = pages[pages.length - 1];

    // Read page content
    const title = await page.title();
    const url = page.url();
    console.log(`Page: ${title} (${url})`);

    // Get text content
    const text = await page.textContent('body');
    console.log(text.slice(0, 2000));

    // Fill a form field
    // await page.fill('#email', 'user@example.com');

    // Click a button
    // await page.click('button[type="submit"]');

    // DO NOT close the browser
})();
```

## Important rules

1. **NEVER call `browser.close()`** — the Chromium instance is shared. Closing it kills the browser for the developer too.
2. **NEVER call `chromium.launch()`** — always use `connectOverCDP('http://localhost:9222')` to connect to the existing instance.
3. **Save screenshots to `~/.clipboard/`** — this is the shared directory for images. The developer can reference them with `@path` in any CLI.
4. **List tabs before acting** — the developer may have multiple tabs open. Ask which one to target if it's ambiguous.
5. **Prefer agent-browser when possible** — `agent-browser --cdp 9222 <command>` is simpler than writing Node.js scripts for basic operations.

## Combining with clipboard

When you take a screenshot or save an image, put it in `~/.clipboard/` so the developer can easily reference it:

```bash
# After saving screenshot to ~/.clipboard/screenshot-1234.png
echo "Screenshot saved. You can reference it with: @/home/dev/.clipboard/screenshot-1234.png"
```

The `~/.clipboard/` directory is also where the clipboard bridge (ai-clipboard) saves images pasted by the developer from their PC.
