# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Infra-as-code for a containerized multi-agent dev environment built around five AI coding CLIs — **Claude Code**, **Gemini CLI**, **Qwen Code**, **Cursor CLI**, and **OpenCode CLI** — deployed as a Docker Swarm service on a VPS. Browser tooling (Lightpanda, Playwright), `cloudflared`, language toolchains (Go, Rust, uv/Python), and shell utilities are bundled as supporting accessories for the agents but are not the focus of this repo. There is no application code here — only the Dockerfile, the Swarm stack, host/container shell scripts, and shell configs. Edits to this repo change how the workspace container is built and how users interact with it.

## Build / deploy

- Image build is automated by GitHub Actions (`.github/workflows/`) on push to `main`, publishing to `ghcr.io/ffmenezes/ai-workspace:latest`. Tag pushes (`vX.Y.Z`) also publish `X.Y.Z` and `X.Y` tags.
- Local build: `docker build -t ai-workspace:latest .`
- Deploy: Portainer stack from `aiworkspace.yaml`, or `docker stack deploy -c aiworkspace.yaml aiworkspace`.
- Runtime update on the VPS: `ai-update` (pulls `ghcr.io/ffmenezes/ai-workspace:latest` and force-updates the `aiworkspace_workspace` service; service name overridable via `AI_WORKSPACE_SERVICE` env var).
- There are no tests, linters, or package manager — changes are validated by building the image and running it.

## Architecture

- **Base image**: `node:22-bookworm-slim`. Choice is load-bearing: Gemini CLI and Qwen Code require Node 20+, and Claude Code ships glibc-linked binaries (Alpine/musl crashes). Don't switch to Alpine.
- **The five CLIs**:
  - Claude Code — Anthropic's native installer; auth in `~/.claude/.credentials.json` (volume `aiworkspace_claude`).
  - Gemini CLI — `npm i -g @google/gemini-cli`; auth via `GEMINI_API_KEY` env var (configure in stack file, not bashrc).
  - Qwen Code — `npm i -g @qwen-code/qwen-code`; OAuth (free tier) in `~/.qwen` (volume `aiworkspace_qwen`).
  - Cursor CLI — native installer; auth in `~/.cursor/cli-config.json` via `agent login` (volume `aiworkspace_cursor`).
  - OpenCode CLI — `npm i -g opencode-ai`; multi-provider auth in `~/.local/share/opencode/auth.json` via `opencode auth login` (volume `aiworkspace_opencode`).
  **Update story**: Claude and Cursor have native auto-updaters that are *intentionally bypassed* — both binaries are copied to `/opt/{claude,cursor-agent}` (read-only) and symlinked into PATH. Auto-updates download to `~/.local/share/...` but the symlink keeps pointing at the build-time version, so they never run. The only reliable update path for any CLI is image rebuild + `ai-update`. Gemini/Qwen/OpenCode can be updated pontually via `npm update -g ...` inside the container, but those changes vanish on rebuild. When changing how a CLI is installed, updated, or authenticated, update Dockerfile + aiworkspace.yaml + README in lockstep.
- **Container user**: runs as non-root `dev`. No sudo inside. To install packages at runtime, use `docker exec -u root` from the host (see README "Manutenção"); persistent additions belong in the Dockerfile.
- **Persistence** is entirely in named Docker volumes mounted into `/home/dev`:
  - `aiworkspace_projects` → `~/projects`
  - `aiworkspace_config` → `~/.config`
  - `aiworkspace_claude` → `~/.claude` (Claude auth + skills)
  - `aiworkspace_gemini` → `~/.gemini`
  - `aiworkspace_qwen` → `~/.qwen`
  - `aiworkspace_cursor` → `~/.cursor`
  - `aiworkspace_opencode` → `~/.local/share/opencode`
  - `aiworkspace_ssh` → `~/.ssh`
  Anything written outside these paths is lost on rebuild.
- **Networking**: container joins `network_swarm_public` so agent MCPs can reach sibling Swarm services (Postgres, Redis, n8n, etc.).
- **Host integration**: `setup-host-aliases.sh` installs shell functions on the VPS host, all prefixed `ai-` (`ai-enter`, `ai-attach`, `ai-dev`, `ai-dev-danger`, `ai-sessions`, `ai-kill`, `ai-kill-all`, `ai-fix-perms`, `ai-update`, `ai-help`). These are the user's main entry points — most just `docker exec` the equivalently-named script inside the container. `ai-help` is the canonical reference and includes a column showing where each command runs (host vs container).

## How `ai-dev` works (the core UX)

`scripts/ai-dev` is the workspace launcher invoked from the host. It:
1. Resolves a project name to `~/projects/<name>` inside the container.
2. Creates (or attaches to) a tmux session named after the project.
3. Opens windows based on flags. **Default (no agent flag) opens all five agents**; naming any agent flag (`--claude`, `--gemini`, `--qwen`, `--cursor`, `--opencode`) restricts to only the named ones. `--rc` adds Remote Control to Claude. `--danger` passes the per-CLI danger flag (`--dangerously-skip-permissions`, `--yolo`, `-f`; OpenCode has no equivalent and is silently skipped). `ai-dev-danger` = `ai-dev <projeto> --danger`.

When changing agent invocation, flags, or window layout, edit `scripts/ai-dev` and keep `scripts/ai-kill`, `scripts/ai-kill-all`, and `scripts/ai-sessions` consistent with session naming. Container scripts and host aliases share the same names by convention — if you rename one, rename both and update `ai-help`.

## Ralph loop

`scripts/ralph` runs an agent (claude/gemini/qwen/cursor/opencode) in a loop until it emits a stop word (default `RALPH_DONE`) or hits `--max`. Iteration logs go to `.ralph-logs/` inside the target project. Used for long-running autonomous tasks; users typically start it then detach from tmux. OpenCode uses a `run` subcommand instead of `-p` and has no danger mode.

## Conventions

- README.md is in Portuguese and is the canonical user-facing doc — keep it in sync when changing flags, scripts, volume names, or the stack.
- The GHCR image owner is hardcoded as `ffmenezes` in `setup-host-aliases.sh` (`ai-update` default) and throughout the README; forks must update both. The Swarm service name is also hardcoded as `aiworkspace_workspace` but is overridable via `AI_WORKSPACE_SERVICE` env var.
- Shell scripts target bash on Debian 12 inside the container (and bash on the Debian VPS host). Don't assume GNU-only flags work everywhere, but POSIX-strict isn't required.
- This repo is developed on Windows (`win32`) but every script runs on Linux — use Unix line endings and forward slashes.
