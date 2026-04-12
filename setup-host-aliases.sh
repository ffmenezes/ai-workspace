#!/bin/bash
# ══════════════════════════════════════════════════════════════
# setup-host-aliases.sh
# Rodar UMA VEZ no HOST da VPS (não dentro do container)
# Adiciona aliases para acessar o AI Workspace facilmente
#
# Uso:
#   bash setup-host-aliases.sh        → instala
#   source ~/.bashrc                  → ativa na sessão atual
# ══════════════════════════════════════════════════════════════

# Verificar se já foi instalado (evitar duplicatas)
if grep -q "# AI_WORKSPACE_ALIASES" ~/.bashrc 2>/dev/null; then
    echo "⚠️  Aliases já estão no ~/.bashrc. Removendo versão anterior..."
    sed -i '/# AI_WORKSPACE_ALIASES_START/,/# AI_WORKSPACE_ALIASES_END/d' ~/.bashrc
fi

echo "Adicionando aliases ao ~/.bashrc do host..."

cat >> ~/.bashrc << 'ALIASES'

# AI_WORKSPACE_ALIASES_START
# ══════════════════════════════════════════════════════════════
# AI Workspace — atalhos do host para o container
# Convenção: todo comando começa com "ai-" e é auto-explicativo.
# ══════════════════════════════════════════════════════════════

_ai_container() {
    docker ps -q -f name=aiworkspace | head -1
}

_ai_require_container() {
    local CID
    CID=$(_ai_container)
    if [ -z "$CID" ]; then
        echo "❌ Container ai-workspace não está rodando." >&2
        echo "   docker service ls | grep aiworkspace" >&2
        return 1
    fi
    echo "$CID"
}

# Entrar no container (shell zsh interativo)
ai-enter() {
    local CID; CID=$(_ai_require_container) || return 1
    docker exec -it -u dev "$CID" zsh -l
}

# Anexar ao tmux principal do container
ai-attach() {
    local CID; CID=$(_ai_require_container) || return 1
    docker exec -it -u dev "$CID" tmux attach -t main 2>/dev/null \
        || docker exec -it -u dev "$CID" zsh -l
}

# Criar/reconectar workspace tmux de um projeto
# Uso: ai-dev <projeto> [--claude] [--gemini] [--qwen] [--cursor] [--opencode] [--codex] [--cline] [--aider] [--rc] [--danger] [--clipboard] [--browser]
ai-dev() {
    local CID; CID=$(_ai_require_container) || return 1
    docker exec -it -u dev "$CID" zsh -lc "ai-dev $*"
}

# Atalho: workspace com todos os agents em modo danger
ai-dev-danger() {
    local CID; CID=$(_ai_require_container) || return 1
    docker exec -it -u dev "$CID" zsh -lc "ai-dev $1 --danger"
}

# Mostrar versão da imagem rodando no container
ai-version() {
    local CID; CID=$(_ai_require_container) || return 1
    docker exec -u dev "$CID" bash -c 'echo "version: $AI_WORKSPACE_VERSION"; echo "commit:  $AI_WORKSPACE_COMMIT"; echo "built:   $AI_WORKSPACE_BUILD_DATE"; echo ""; echo "Boot log (últimas 5 entradas):"; tail -5 /home/dev/.ai-workspace.log 2>/dev/null || echo "(sem log)"'
}

# Listar sessões tmux ativas no container
ai-sessions() {
    local CID; CID=$(_ai_require_container) || return 1
    docker exec -it -u dev "$CID" ai-sessions
}

# Matar uma sessão tmux específica
ai-kill() {
    local CID; CID=$(_ai_require_container) || return 1
    docker exec -it -u dev "$CID" ai-kill "$1"
}

# Configurar defaults do ai-dev (quais agents abrem por padrão)
ai-setup() {
    local CID; CID=$(_ai_require_container) || return 1
    docker exec -it -u dev "$CID" ai-setup "$@"
}

# Apagar projeto (mata sessão + apaga pasta)
# Corrige permissões como root antes de deletar (arquivos via SFTP/IDE podem ser root-owned)
ai-delete() {
    local CID; CID=$(_ai_require_container) || return 1
    local PROJECT="$1"
    [ -z "$PROJECT" ] && { echo "Uso: ai-delete <nome-do-projeto>"; return 1; }
    docker exec -u root "$CID" chown -R dev:dev "/home/dev/projects/$PROJECT" 2>/dev/null
    docker exec -it -u dev "$CID" ai-delete "$PROJECT"
}

# Matar TODAS as sessões tmux de projeto (preserva "main")
ai-kill-all() {
    local CID; CID=$(_ai_require_container) || return 1
    docker exec -it -u dev "$CID" ai-kill-all
}

# Corrigir permissões em ~/projects (após upload via Portainer/SCP)
ai-fix-perms() {
    local CID; CID=$(_ai_require_container) || return 1
    docker exec -u root "$CID" chown -R dev:dev /home/dev/projects
    echo "✅ Permissões corrigidas em ~/projects"
}

# Atualizar imagem do AI Workspace (pull + force update do serviço Swarm)
# Service name overridable via AI_WORKSPACE_SERVICE env var.
ai-update() {
    local IMAGE="${1:-ghcr.io/ffmenezes/ai-workspace:latest}"
    local SERVICE="${AI_WORKSPACE_SERVICE:-aiworkspace_aiworkspace}"

    # Avisar se há sessões tmux que vão morrer no restart
    local CID; CID=$(_ai_container)
    if [ -n "$CID" ]; then
        local ACTIVE
        ACTIVE=$(docker exec "$CID" tmux ls -F '#{session_name}' 2>/dev/null | grep -v '^main$' || true)
        if [ -n "$ACTIVE" ]; then
            echo "⚠️  As seguintes sessões tmux serão encerradas pelo restart:"
            echo "$ACTIVE" | sed 's/^/    - /'
            read -rp "Continuar? [s/N]: " CONFIRM
            case "$CONFIRM" in
                s|S|sim|y|Y|yes) ;;
                *) echo "Cancelado."; return 0 ;;
            esac
        fi
    fi

    echo "📥 Baixando imagem: $IMAGE"
    docker pull "$IMAGE" || { echo "❌ Falha no pull"; return 1; }
    echo "♻️  Atualizando serviço Swarm: $SERVICE"
    docker service update --image "$IMAGE" --force "$SERVICE"
    echo "✅ Workspace atualizado"
}

# SSH direto no container (requer authorized_keys no volume .ssh)
ai-ssh() {
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 dev@localhost "$@"
}

# Clipboard bridge: inicia servidor web no container + abre tunnel
# Uso: ai-clipboard [porta]    (default: 3456)
# No PC, abre http://localhost:<porta> para colar imagens via Ctrl+V
ai-clipboard() {
    local CID; CID=$(_ai_require_container) || return 1
    local PORT="${1:-3456}"

    # Checar se já tem servidor rodando nessa porta
    if docker exec "$CID" bash -c "ss -tlnp 2>/dev/null | grep -q ':$PORT '" 2>/dev/null; then
        echo "📋 Clipboard já rodando na porta $PORT"
    else
        echo "📋 Iniciando ai-clipboard na porta $PORT..."
        docker exec -d -u dev "$CID" node /home/dev/bin/ai-clipboard "$PORT"
        sleep 1
    fi

    echo "🔗 Abrindo tunnel porta $PORT → container"
    echo ""
    echo "   No browser do PC, abra:"
    echo "   http://localhost:$PORT"
    echo ""
    echo "   Ctrl+V cola imagem → @path copiado automaticamente"
    echo "   Ctrl+C para encerrar tunnel"
    echo ""
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -N -L "$PORT:localhost:$PORT" -p 2222 dev@localhost
}

# SSH tunnel: forward de porta local para o container
# Uso: ai-tunnel 9222         (forward localhost:9222 → container:9222)
#       ai-tunnel 9222 3000    (forward múltiplas portas)
ai-tunnel() {
    [ $# -eq 0 ] && { echo "Uso: ai-tunnel <porta> [porta2] [porta3] ..."; return 1; }
    local FORWARDS=""
    for PORT in "$@"; do
        FORWARDS="$FORWARDS -L $PORT:localhost:$PORT"
    done
    echo "Tunnel ativo: $(echo "$@" | tr ' ' ', ') → container"
    echo "Ctrl+C para encerrar"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -N $FORWARDS -p 2222 dev@localhost
}

# Ajuda — lista todos os comandos ai-* disponíveis
ai-help() {
    cat << 'HELP'
╔══════════════════════════════════════════════════════════════════════╗
║  AI Workspace — referência de comandos                               ║
╚══════════════════════════════════════════════════════════════════════╝

  Coluna "Onde":
    H   = roda no HOST da VPS (após setup-host-aliases.sh)
    C   = roda dentro do CONTAINER (após ai-enter)
    H/C = mesmo nome existe nos dois lugares; o do host só faz
          docker exec do equivalente interno (use de qualquer um)

  Comando                    Onde   Descrição
  ────────────────────────── ────── ────────────────────────────────────
  ai-enter                   H      Shell zsh dentro do container
  ai-attach                  H      Anexa ao tmux principal (sessão "main")
  ai-update [imagem]         H      Pull + force update do serviço Swarm
                                    (AI_WORKSPACE_SERVICE override do nome)
  ai-version                 H      Mostra versão da imagem em execução + boot log
  ai-fix-perms               H      Corrige owner em ~/projects (dev:dev)
  ai-ssh                     H      SSH direto no container (porta 2222)
  ai-tunnel <porta> [...]    H      SSH tunnel de portas para o container
  ai-clipboard [porta]       H      Clipboard bridge: cola imagens via browser
                                    (default porta 3456, abre tunnel automaticamente)
  ai-browser [porta|status|stop] C  Chromium headless com CDP (default porta 9222)
  ai-help                    H/C    Esta ajuda

  ai-dev <projeto> [flags]   H/C    Cria/reconecta workspace tmux do projeto
  ai-dev-danger <projeto>    H/C    Atalho: ai-dev <projeto> --danger
  ai-sessions                H/C    Lista sessões tmux + processos + recursos
  ai-kill <projeto>          H/C    Mata uma sessão tmux específica
  ai-kill-all                H/C    Mata TODAS as sessões (preserva "main")
  ai-delete <projeto>        H/C    Mata sessão + APAGA pasta do projeto

  ai-setup                   H/C    Define quais agents abrem por padrão
  ai-setup --reset           H/C    Reseta config e roda wizard de novo

  ralph -a <agent> -p "..."  C      Loop autônomo de um agent até concluir
  claude / gemini / qwen     C      Invocar uma CLI diretamente
  cursor / opencode          C      (idem)
  codex / cline / aider      C      (idem)

  Flags do ai-dev
  ───────────────
  (sem flag)         abre os DEFAULTS (configurados via ai-setup)
  --claude           só Claude
  --gemini           só Gemini
  --qwen             só Qwen
  --cursor           só Cursor
  --opencode         só OpenCode
  --codex            só Codex
  --cline            só Cline
  --aider            só Aider
  --all              TODOS os 8 agents (override dos defaults)
  (combine livre)    --claude --gemini, --qwen --cursor, etc.
  --rc               adiciona Remote Control no Claude
  --danger           skip-permissions/yolo nos agents que suportam
  --clipboard        inicia clipboard bridge (cola imagens via browser)
  --browser          inicia Chromium headless com CDP (DevTools remoto)

  Flags --danger por CLI
  ──────────────────────
  claude    --dangerously-skip-permissions
  gemini    --yolo
  qwen      --yolo
  cursor    -f
  opencode  (sem equivalente — ignorado)
  codex     --yolo
  cline     --yolo
  aider     --yes-always

  Como atualizar as CLIs
  ──────────────────────
  Único caminho confiável: rebuild da imagem (push pra GitHub → Actions
  builda) + ai-update na VPS. Auto-updaters do Claude/Cursor estão
  bloqueados pelo layout do Dockerfile (binários em /opt read-only).
  Detalhes em README "Por que rebuild e não auto-update?".

HELP
}
# AI_WORKSPACE_ALIASES_END

ALIASES

echo ""
echo "✅ Aliases instalados!"
echo ""
echo "   ai-enter           → Shell zsh dentro do container"
echo "   ai-attach          → Anexar ao tmux principal"
echo "   ai-dev <proj>      → Workspace de projeto (todos os agents por padrão)"
echo "   ai-dev-danger <p>  → Workspace com --danger"
echo "   ai-sessions        → Listar sessões tmux"
echo "   ai-kill <proj>     → Matar sessão"
echo "   ai-kill-all        → Matar todas as sessões de projeto"
echo "   ai-fix-perms       → Corrigir permissões em ~/projects"
echo "   ai-update          → Pull + restart do serviço"
echo "   ai-version         → Versão da imagem em execução"
echo "   ai-ssh             → SSH direto no container"
echo "   ai-tunnel <porta>  → SSH tunnel de porta para o container"
echo "   ai-clipboard       → Clipboard bridge (cola imagens via browser)"
echo "   ai-setup           → Configurar defaults do ai-dev"
echo "   ai-help            → Ajuda completa"
echo ""
echo "⚡ Rode agora:  source ~/.bashrc  &&  ai-help"
echo ""
