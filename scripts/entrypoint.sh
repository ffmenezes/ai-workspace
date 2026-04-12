#!/bin/bash
# ══════════════════════════════════════════════════════════════
# entrypoint.sh — Boot do container AI Workspace
#
# Roda como root, inicia serviços, dropa pra user dev.
# Substitui o CMD inline do Dockerfile.
# ══════════════════════════════════════════════════════════════
set -e

LOG="/home/dev/.ai-workspace.log"

log() {
    echo "[$(date -Iseconds)] $*" | tee -a "$LOG"
}

# ── 1. Boot log ──
log "AI Workspace started — version=${AI_WORKSPACE_VERSION} commit=${AI_WORKSPACE_COMMIT} build_date=${AI_WORKSPACE_BUILD_DATE}"

# ── 2. Restaurar ~/.claude.json se ausente ──
if [ ! -f /home/dev/.claude.json ]; then
    LATEST=$(ls -t /home/dev/.claude/backups/.claude.json.backup.* 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        cp "$LATEST" /home/dev/.claude.json
        chown dev:dev /home/dev/.claude.json
        log "Restored ~/.claude.json from $LATEST"
    fi
fi

# ── 3. Seed default skills ──
mkdir -p /home/dev/.agents/skills
for skill in /opt/default-skills/*/; do
    [ -d "$skill" ] || continue
    name=$(basename "$skill")
    if [ ! -d "/home/dev/.agents/skills/$name" ]; then
        cp -r "$skill" "/home/dev/.agents/skills/$name"
        chown -R dev:dev "/home/dev/.agents/skills/$name"
        log "Seeded default skill: $name"
    fi
done

# ── 4. SSH server ──
# Gera host keys se não existirem (efêmeras — regeneradas a cada rebuild)
ssh-keygen -A 2>/dev/null

# Fixa permissões (sshd é strict)
mkdir -p /run/sshd
chmod 0755 /run/sshd
chmod 700 /home/dev/.ssh 2>/dev/null || true
chmod 600 /home/dev/.ssh/authorized_keys 2>/dev/null || true
chown -R dev:dev /home/dev/.ssh 2>/dev/null || true

# Inicia sshd em background
/usr/sbin/sshd
log "sshd started on port 2222"

# ── 5. Dropa pra dev → tmux + tail ──
exec gosu dev bash -c "tmux new-session -d -s main && tail -f $LOG"
