---
name: clipboard
description: Clipboard bridge between the developer's PC and the container. Use when the user references a pasted image, shares a screenshot via @path from ~/.clipboard/, or asks about how to share images. Triggers include "I pasted an image", "look at this screenshot", references to @/home/dev/.clipboard/ paths, or questions about sharing visual content.
allowed-tools: Bash(ls *), Bash(node *), Read
---

# Clipboard Bridge

The AI Workspace includes a clipboard bridge that lets the developer paste images from their PC into the container. This is started when the user runs `ai-dev <project> --clipboard`.

## How it works

1. A web server runs in the container on port 3456
2. The developer opens `http://localhost:<tunnel-port>` in their PC browser
3. They press Ctrl+V to paste an image from their clipboard
4. The image is saved to `~/.clipboard/` with a timestamped filename
5. The `@path` is automatically copied to their clipboard
6. They paste the path as text in any CLI prompt

## Referencing pasted images

When the developer pastes an image, it's saved as:
```
/home/dev/.clipboard/20260412-143022-001.png
```

They will reference it in their prompt using the `@` prefix:
```
@/home/dev/.clipboard/20260412-143022-001.png
```

When you see a path like this, it's an image the developer pasted from their PC. Read it to see the image.

## Listing recent clipboard images

```bash
ls -lt ~/.clipboard/ | head -20
```

## Saving your own images to clipboard

When you generate images (screenshots, diagrams, etc.), save them to `~/.clipboard/` so the developer can easily find and reference them:

```bash
# Example: save a browser screenshot
node -e "
const pw = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');
(async () => {
    const browser = await pw.chromium.connectOverCDP('http://localhost:9222');
    const page = browser.contexts()[0].pages().pop();
    await page.screenshot({ path: '/home/dev/.clipboard/page-screenshot.png' });
    console.log('Saved: /home/dev/.clipboard/page-screenshot.png');
})();
"
```

Tell the developer the path so they can view it:
```
Screenshot saved at @/home/dev/.clipboard/page-screenshot.png
```

## Checking if clipboard is running

```bash
curl -sf http://localhost:3456/ >/dev/null && echo "Clipboard bridge active" || echo "Clipboard not running"
```

If not running, the developer needs to restart with `--clipboard`:
```
ai-dev <project> --clipboard
```

Or start it directly:
```bash
node ~/bin/ai-clipboard &
```
