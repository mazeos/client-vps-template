#!/bin/bash
# setup-local.sh — Configura tu Mac para trabajar con el VPS
# Instala Claude Code y configura todos los MCPs.
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "${RED}✗${NC} $1"; }
step() { echo -e "\n${BOLD}${CYAN}$1${NC}"; }
ask()  { echo -e "${YELLOW}?${NC}  $1"; }

[[ "$OSTYPE" != "darwin"* && "$OSTYPE" != "linux-gnu"* ]] && { err "En Windows usa setup-local.ps1"; exit 1; }

clear
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   VPS Template — Setup local (Mac)               ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Instala Claude Code y configura los MCPs en tu máquina."
echo ""
read -p "  Presiona Enter para comenzar..."

# ════════════════════════════════════════════════════════════════
step "[ PASO 1 / 4 ]  Instalar prerrequisitos"
# ════════════════════════════════════════════════════════════════
echo ""

if [[ "$OSTYPE" == "darwin"* ]] && ! command -v brew &>/dev/null; then
  warn "Instalando Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ok "Homebrew instalado"
fi

if command -v python3 &>/dev/null; then
  ok "Python 3 ($(python3 --version))"
else
  [[ "$OSTYPE" == "darwin"* ]] && brew install python3 || sudo apt-get install -y python3
  ok "Python 3 instalado"
fi

if command -v node &>/dev/null; then
  ok "Node.js ($(node --version))"
else
  warn "Node.js no encontrado. Instalando..."
  [[ "$OSTYPE" == "darwin"* ]] && brew install node || { curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs; }
  ok "Node.js instalado"
fi

if command -v claude &>/dev/null; then
  ok "Claude Code ($(claude --version 2>/dev/null | head -1))"
else
  warn "Instalando Claude Code..."
  npm install -g @anthropic-ai/claude-code
  ok "Claude Code instalado"
fi

# ════════════════════════════════════════════════════════════════
step "[ PASO 2 / 4 ]  Datos de tu servidor"
# ════════════════════════════════════════════════════════════════
echo ""
echo "  Ingresa los datos del VPS que acabas de configurar."
echo ""

ask "Dominio principal del VPS (ej: miempresa.com):"
read -p "  → " DOMAIN
while [[ -z "$DOMAIN" ]]; do
  err "No puede estar vacío."; read -p "  → " DOMAIN
done

ask "IP del VPS (para configurar SSH):"
read -p "  → " VPS_IP

# ════════════════════════════════════════════════════════════════
step "[ PASO 3 / 4 ]  Configurar MCPs"
# ════════════════════════════════════════════════════════════════
echo ""
echo "  Configura los MCPs uno por uno."
echo "  Presiona Enter para saltar cualquiera y configurarlo después."
echo ""

CLAUDE_JSON="$HOME/.claude.json"
[[ ! -f "$CLAUDE_JSON" ]] && echo '{}' > "$CLAUDE_JSON"

add_mcp() {
  local name="$1"; local config="$2"
  python3 - <<PYEOF
import json
from pathlib import Path
p = Path("$CLAUDE_JSON")
c = json.loads(p.read_text())
c.setdefault("mcpServers", {})["$name"] = $config
p.write_text(json.dumps(c, indent=2, ensure_ascii=False))
PYEOF
}

# ── MCP: n8n (apunta al VPS) ──────────────────────────────────
echo -e "  ${BOLD}[MCP 1/9] n8n${NC} — https://n8n.$DOMAIN"
echo "  API Key: n8n → Settings → n8n API → Create an API key"
echo ""
ask "n8n API Key (Enter para saltar):"
read -p "  → " N8N_KEY
if [[ -n "$N8N_KEY" ]]; then
  add_mcp "n8n" '{"command":"npx","args":["-y","n8n-mcp-server"],"env":{"N8N_URL":"https://n8n.'"$DOMAIN"'","N8N_API_KEY":"'"$N8N_KEY"'"}}'
  ok "MCP n8n configurado → https://n8n.$DOMAIN"
else
  warn "MCP n8n omitido"
fi
echo ""

# ── MCP: Obsidian (local) ─────────────────────────────────────
echo -e "  ${BOLD}[MCP 2/9] Obsidian${NC} — local"
echo "  Requiere plugin 'Local REST API' activo en Obsidian."
echo "  API Key: Obsidian → Settings → Local REST API → API Key"
echo ""
ask "Ruta de tu vault de Obsidian (ej: ~/Documents/Obsidian Vault):"
read -p "  → " VAULT_PATH
VAULT_PATH="${VAULT_PATH:-$HOME/Documents/Obsidian Vault}"
ask "Obsidian API Key (Enter para saltar):"
read -p "  → " OBS_KEY
if [[ -n "$OBS_KEY" ]]; then
  add_mcp "obsidian" '{"command":"npx","args":["-y","mcp-obsidian","'"$VAULT_PATH"'"],"env":{"OBSIDIAN_API_KEY":"'"$OBS_KEY"'"}}'
  ok "MCP Obsidian configurado"
else
  warn "MCP Obsidian omitido"
fi
echo ""

# ── MCP: Notion ───────────────────────────────────────────────
echo -e "  ${BOLD}[MCP 3/9] Notion${NC}"
echo "  API Key: https://www.notion.so/my-integrations → Nueva integración"
echo ""
ask "Notion API Key (Enter para saltar):"
read -p "  → " NOTION_KEY
if [[ -n "$NOTION_KEY" ]]; then
  add_mcp "notion" '{"command":"npx","args":["-y","@notionhq/notion-mcp-server"],"env":{"OPENAPI_MCP_HEADERS":"{\"Authorization\":\"Bearer '"$NOTION_KEY"'\",\"Notion-Version\":\"2022-06-28\"}"}}'
  ok "MCP Notion configurado"
else
  warn "MCP Notion omitido"
fi
echo ""

# ── MCP: Google Drive / Calendar / Gmail ──────────────────────
echo -e "  ${BOLD}[MCP 4-6] Google Drive, Calendar y Gmail${NC}"
echo "  Requieren OAuth — pasos:"
echo "  1. https://console.cloud.google.com/apis/credentials"
echo "  2. Crear credenciales → Aplicación de escritorio → descargar credentials.json"
echo "  3. Agrega manualmente a ~/.claude.json después de la instalación"
echo ""
warn "Google MCPs requieren configuración manual (OAuth)"
echo ""

# ── MCP: Discord ──────────────────────────────────────────────
echo -e "  ${BOLD}[MCP 7/9] Discord${NC}"
echo "  Bot token: https://discord.com/developers/applications → Tu bot → Token"
echo ""
ask "Discord Bot Token (Enter para saltar):"
read -p "  → " DISCORD_TOKEN
if [[ -n "$DISCORD_TOKEN" ]]; then
  add_mcp "discord" '{"command":"npx","args":["-y","@modelcontextprotocol/server-discord"],"env":{"DISCORD_TOKEN":"'"$DISCORD_TOKEN"'"}}'
  ok "MCP Discord configurado"
else
  warn "MCP Discord omitido"
fi
echo ""

# ── MCP: Meta Ads ─────────────────────────────────────────────
echo -e "  ${BOLD}[MCP 8/9] Meta Ads${NC}"
echo "  Access Token: https://developers.facebook.com/tools/explorer/"
echo ""
ask "Meta Access Token (Enter para saltar):"
read -p "  → " META_TOKEN
if [[ -n "$META_TOKEN" ]]; then
  add_mcp "meta-ads" '{"type":"http","url":"https://mcp.ads.meta.com/mcp","headers":{"Authorization":"Bearer '"$META_TOKEN"'"}}'
  ok "MCP Meta Ads configurado"
else
  warn "MCP Meta Ads omitido"
fi
echo ""

# ── MCP: GoHighLevel ──────────────────────────────────────────
echo -e "  ${BOLD}[MCP 9/9] GoHighLevel (GHL)${NC}"
echo "  Requiere instalar el servidor local primero:"
echo "  git clone https://github.com/mastanley13/ghl-mcp-server.git ~/ghl-mcp-server"
echo "  cd ~/ghl-mcp-server && npm install && npm run build"
echo ""
ask "GHL API Key (Enter para saltar):"
read -p "  → " GHL_KEY
if [[ -n "$GHL_KEY" ]]; then
  ask "GHL Location ID:"
  read -p "  → " GHL_LOC
  if [[ -n "$GHL_LOC" ]]; then
    add_mcp "ghl" '{"command":"node","args":["'"$HOME"'/ghl-mcp-server/dist/server.js"],"env":{"GHL_API_KEY":"'"$GHL_KEY"'","GHL_LOCATION_ID":"'"$GHL_LOC"'"}}'
    ok "MCP GHL configurado"
  else
    warn "MCP GHL omitido — falta Location ID"
  fi
else
  warn "MCP GHL omitido"
fi
echo ""

# ════════════════════════════════════════════════════════════════
step "[ PASO 4 / 4 ]  Verificación final"
# ════════════════════════════════════════════════════════════════
echo ""

ERRORS=0
command -v claude &>/dev/null && ok "Claude Code instalado" || { err "Claude Code no encontrado"; ERRORS=$((ERRORS+1)); }
[[ -f "$CLAUDE_JSON" ]] && ok "~/.claude.json presente" || { err "~/.claude.json no encontrado"; ERRORS=$((ERRORS+1)); }

MCP_COUNT=$(python3 -c "
import json
from pathlib import Path
p = Path('$CLAUDE_JSON')
c = json.loads(p.read_text())
print(len(c.get('mcpServers', {})))
" 2>/dev/null || echo 0)
ok "$MCP_COUNT MCP(s) configurados"

echo ""
if [[ $ERRORS -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║   ✅  Setup local completado                     ║${NC}"
  echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
else
  echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${YELLOW}${BOLD}║   ⚠️   Completado con $ERRORS error(s)                    ║${NC}"
  echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
fi

echo ""
echo -e "${BOLD}  Próximos pasos:${NC}"
echo "  1. Verifica MCPs activos: claude mcp list"
echo "  2. Configura tu vault de Obsidian:"
echo "     curl -sSL https://raw.githubusercontent.com/mazeos/client-vault-template/main/setup.sh | bash"
echo "  3. Corre: claude"
echo ""
[[ -n "$VPS_IP" ]] && echo -e "  Tu VPS: ${BOLD}$VPS_IP${NC} | Dominio: ${BOLD}$DOMAIN${NC}" && echo ""
