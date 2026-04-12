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

# Host keys persistentes: salva no volume ~/.ssh/.host_keys/ para que
# não mudem entre rebuilds (evita "host key changed" no cliente SSH).
HOST_KEYS_DIR="/home/dev/.ssh/.host_keys"
mkdir -p "$HOST_KEYS_DIR"
if [ -z "$(ls -A "$HOST_KEYS_DIR" 2>/dev/null)" ]; then
    # Primeiro boot: gera e salva no volume
    ssh-keygen -A 2>/dev/null
    cp /etc/ssh/ssh_host_* "$HOST_KEYS_DIR/"
    log "SSH host keys generated and saved to volume"
else
    # Boot seguinte: restaura do volume
    cp "$HOST_KEYS_DIR"/ssh_host_* /etc/ssh/
    log "SSH host keys restored from volume"
fi

# Injetar authorized_keys via env var (se definida no stack)
# Permite setup automático sem docker exec manual.
if [ -n "$SSH_AUTHORIZED_KEYS" ]; then
    mkdir -p /home/dev/.ssh
    # Append sem duplicar: só adiciona se a chave ainda não está presente
    touch /home/dev/.ssh/authorized_keys
    while IFS= read -r key; do
        [ -z "$key" ] && continue
        grep -qF "$key" /home/dev/.ssh/authorized_keys 2>/dev/null || echo "$key" >> /home/dev/.ssh/authorized_keys
    done <<< "$SSH_AUTHORIZED_KEYS"
    log "SSH authorized_keys injected from environment"
fi

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
