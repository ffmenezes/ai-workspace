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
# AI Workspace — atalhos para acessar o container
# Busca qualquer container com "aiworkspace" no nome
# ══════════════════════════════════════════════════════════════

_aiw_container() {
    docker ps -q -f name=aiworkspace | head -1
}

# Entrar no container (zsh)
aiw() {
    local CID=$(_aiw_container)
    if [ -z "$CID" ]; then
        echo "❌ Container ai-workspace não está rodando."
        echo "   docker service ls | grep aiworkspace"
        return 1
    fi
    docker exec -it "$CID" zsh -l
}

# Entrar direto no tmux do container
ait() {
    local CID=$(_aiw_container)
    if [ -z "$CID" ]; then
        echo "❌ Container ai-workspace não está rodando."
        return 1
    fi
    docker exec -it "$CID" tmux attach -t main 2>/dev/null \
        || docker exec -it "$CID" zsh -l
}

# Criar/reconectar workspace de projeto direto do host
aidev() {
    local CID=$(_aiw_container)
    if [ -z "$CID" ]; then
        echo "❌ Container ai-workspace não está rodando."
        return 1
    fi
    docker exec -it "$CID" zsh -lc "aidev $*"
}

# Workspace em modo danger (Claude skip-permissions + outros em yolo)
aidanger() {
    local CID=$(_aiw_container)
    if [ -z "$CID" ]; then
        echo "❌ Container ai-workspace não está rodando."
        return 1
    fi
    docker exec -it "$CID" zsh -lc "aidev $1 --all --danger"
}

# Status do workspace
aiws() {
    local CID=$(_aiw_container)
    if [ -z "$CID" ]; then
        echo "❌ Container ai-workspace não está rodando."
        return 1
    fi
    docker exec -it "$CID" ai-status
}

# Corrigir permissões dos arquivos em ~/projects (após upload via Portainer/SCP)
aifix() {
    local CID=$(_aiw_container)
    if [ -z "$CID" ]; then
        echo "❌ Container ai-workspace não está rodando."
        return 1
    fi
    docker exec -u root "$CID" chown -R dev:dev /home/dev/projects
    echo "✅ Permissões corrigidas em ~/projects"
}

# Atualizar imagem do AI Workspace (puxa última versão do ghcr.io)
aiupdate() {
    local IMAGE="${1:-ghcr.io/ffmenezes/ai-workspace:latest}"
    echo "📥 Baixando imagem: $IMAGE"
    docker pull "$IMAGE" || { echo "❌ Falha no pull"; return 1; }
    echo "♻️  Atualizando serviço Swarm..."
    docker service update --image "$IMAGE" --force aiworkspace_workspace
    echo "✅ Workspace atualizado"
}
# AI_WORKSPACE_ALIASES_END

ALIASES

echo ""
echo "✅ Aliases instalados!"
echo ""
echo "   aiw       → Entrar no container (zsh)"
echo "   ait       → Entrar direto no tmux do container"
echo "   aidev X   → Criar/reconectar workspace do projeto X"
echo "   aidanger X → Workspace com skip-permissions + yolo"
echo "   aiws      → Ver status das sessões"
echo "   aifix     → Corrigir permissões após upload via Portainer/SCP"
echo "   aiupdate  → Atualizar imagem do workspace (pull + restart)"
echo ""
echo "⚡ Rode agora:  source ~/.bashrc"
echo ""
