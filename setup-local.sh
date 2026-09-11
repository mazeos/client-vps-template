#!/bin/bash
# setup-local.sh — Configura tu Mac/Linux para operar con Claude Code.
# Instala Claude Code y conecta los MCPs del sistema: Google Workspace (lectura y escritura),
# n8n, GoHighLevel, Meta Ads, Apify, Fathom, Discord y ElevenLabs (opcional).
#   curl -sSL https://raw.githubusercontent.com/mazeos/client-vps-template/main/setup-local.sh -o setup-local.sh && bash setup-local.sh
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "${RED}✗${NC} $1"; }
step() { echo -e "\n${BOLD}${CYAN}$1${NC}\n"; }
ask()  { echo -e "${YELLOW}?${NC}  $1"; }
leer() { local v; read -r -p "  → " v < /dev/tty; echo "$v"; }
leer_secreto() { local v; read -r -s -p "  → " v < /dev/tty; echo "" >&2; echo "$v"; }
pausa() { read -r -p "  Presioná Enter cuando esté listo..." < /dev/tty; }
CALLBACK_PORT=33418
GOOGLE_REDIRECT="http://localhost:$CALLBACK_PORT/callback"

[[ "$OSTYPE" != "darwin"* && "$OSTYPE" != "linux-gnu"* ]] && { err "En Windows usá setup-local.ps1"; exit 1; }

clear
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   Setup local — Claude Code + MCPs               ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Vas a conectar, en este orden:"
echo "    1. Google Workspace (Gmail, Calendar, Drive, Docs, Sheets)"
echo "    2. n8n de tu VPS       3. GoHighLevel       4. Meta Ads       5. Apify"
echo "    6. Fathom              7. Discord           8. ElevenLabs (opcional)"
echo ""
echo "  Cada paso te dice qué abrir y qué copiar. Podés saltar uno con Enter y volver después."
echo ""
pausa

# ════════════════════════════════════════════════════════════════
step "[ 1 / 10 ]  Prerrequisitos"
# ════════════════════════════════════════════════════════════════
if [[ "$OSTYPE" == "darwin"* ]] && ! command -v brew &>/dev/null; then
  warn "Instalando Homebrew..."; /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/tty
fi
for tool in git python3 node; do
  if command -v $tool &>/dev/null; then ok "$tool ($($tool --version 2>&1 | head -1 | awk '{print $NF}'))"
  else
    warn "Instalando $tool..."
    if [[ "$OSTYPE" == "darwin"* ]]; then brew install $tool; else sudo apt-get install -y $tool; fi
  fi
done
if command -v claude &>/dev/null; then ok "Claude Code ($(claude --version 2>/dev/null | head -1))"
else warn "Instalando Claude Code..."; npm install -g @anthropic-ai/claude-code && ok "Claude Code instalado"; fi
echo ""
echo "  Si todavía no iniciaste sesión en Claude Code, abrí otra terminal, corré 'claude' y seguí el login."
pausa

# ════════════════════════════════════════════════════════════════
step "[ 2 / 10 ]  Datos de tu servidor"
# ════════════════════════════════════════════════════════════════
ask "Dominio base de tu VPS (ej: miempresa.com):"; DOMAIN="$(leer)"
while [[ -z "$DOMAIN" ]]; do err "No puede estar vacío."; DOMAIN="$(leer)"; done

# ════════════════════════════════════════════════════════════════
step "[ 3 / 10 ]  Google Workspace — Gmail, Calendar, Drive, Docs y Sheets (lectura y escritura)"
# ════════════════════════════════════════════════════════════════
echo "  Google publica servidores MCP oficiales. Necesitás credenciales OAuth propias (gratis, 10 minutos):"
echo ""
echo "  1. Entrá a https://console.cloud.google.com y creá un proyecto (ej: 'Claude Code')."
echo "  2. APIs y servicios → Biblioteca: habilitá Gmail API, Google Drive API, Google Docs API,"
echo "     Google Sheets API y Google Calendar API."
echo "  3. En la misma Biblioteca habilitá también los servicios MCP: 'Gmail MCP', 'Drive MCP',"
echo "     'Docs MCP', 'Sheets MCP' y 'Calendar MCP' (buscá 'MCP')."
echo "  4. APIs y servicios → Pantalla de consentimiento OAuth: tipo Externo, agregá tu email como usuario de prueba."
echo "  5. APIs y servicios → Credenciales → Crear credenciales → ID de cliente OAuth → Aplicación web."
echo "     En 'URI de redireccionamiento autorizados' agregá EXACTAMENTE estos dos:"
echo -e "        ${BOLD}$GOOGLE_REDIRECT${NC}"
echo -e "        ${BOLD}https://claude.ai/api/mcp/auth_callback${NC}"
echo "  6. Copiá el ID de cliente y el secreto."
echo ""
ask "ID de cliente OAuth de Google (Enter para saltar Google):"; GOOGLE_CLIENT_ID="$(leer)"
if [[ -n "$GOOGLE_CLIENT_ID" ]]; then
  ask "Secreto del cliente OAuth:"; GOOGLE_CLIENT_SECRET="$(leer_secreto)"
  declare -a GOOGLE_MCPS=(
    "gmail|https://gmailmcp.googleapis.com/mcp/v1"
    "google-calendar|https://calendarmcp.googleapis.com/mcp/v1"
    "google-drive|https://drivemcp.googleapis.com/mcp/v1"
    "google-docs|https://docsmcp.googleapis.com/mcp/v1"
    "google-sheets|https://sheetsmcp.googleapis.com/mcp/v1"
  )
  for par in "${GOOGLE_MCPS[@]}"; do
    nombre="${par%%|*}"; url="${par#*|}"
    claude mcp remove -s user "$nombre" >/dev/null 2>&1 || true
    MCP_CLIENT_SECRET="$GOOGLE_CLIENT_SECRET" claude mcp add --transport http -s user \
      --client-id "$GOOGLE_CLIENT_ID" --client-secret --callback-port "$CALLBACK_PORT" \
      "$nombre" "$url" >/dev/null && ok "MCP $nombre registrado"
  done
  echo ""
  echo "  Ahora se abre el navegador 5 veces (una por servicio) para que autorices tu cuenta de Google."
  pausa
  for par in "${GOOGLE_MCPS[@]}"; do
    nombre="${par%%|*}"
    claude mcp login "$nombre" < /dev/tty && ok "$nombre autorizado" || warn "$nombre: autorización pendiente (corré: claude mcp login $nombre)"
  done
else
  warn "Google omitido. Después: volvé a correr este script o seguí el README."
fi

# ════════════════════════════════════════════════════════════════
step "[ 4 / 10 ]  n8n — tu instancia en https://n8n.$DOMAIN"
# ════════════════════════════════════════════════════════════════
echo "  1. Entrá a https://n8n.$DOMAIN → Settings → Instance-level MCP → 'Enable MCP access'."
echo "  2. Botón 'Connect a client' → pestaña API key → copiá el token."
echo "  3. Cada workflow que quieras que Claude pueda usar: menú del workflow → Settings → 'Available in MCP'."
echo ""
ask "Token MCP de n8n (Enter para saltar):"; N8N_TOKEN="$(leer_secreto)"
if [[ -n "$N8N_TOKEN" ]]; then
  claude mcp remove -s user n8n >/dev/null 2>&1 || true
  claude mcp add --transport http -s user n8n "https://n8n.$DOMAIN/mcp-server/http" \
    --header "Authorization: Bearer $N8N_TOKEN" >/dev/null && ok "MCP n8n → https://n8n.$DOMAIN"
else warn "n8n omitido"; fi

# ════════════════════════════════════════════════════════════════
step "[ 5 / 10 ]  GoHighLevel"
# ════════════════════════════════════════════════════════════════
echo "  En GHL: Settings de la subcuenta → Private Integrations → crear una con todos los scopes → copiá el token."
echo "  El Location ID está en Settings → Business Profile."
echo ""
ask "Private Integration Token de GHL (Enter para saltar):"; GHL_KEY="$(leer_secreto)"
if [[ -n "$GHL_KEY" ]]; then
  ask "Location ID de la subcuenta:"; GHL_LOC="$(leer)"
  if [[ ! -f "$HOME/ghl-mcp-server/dist/server.js" ]]; then
    warn "Instalando el servidor MCP de GHL (1-2 minutos)..."
    rm -rf "$HOME/ghl-mcp-server"
    git clone -q https://github.com/mastanley13/GoHighLevel-MCP.git "$HOME/ghl-mcp-server" \
      && (cd "$HOME/ghl-mcp-server" && npm install --silent && npm run build --silent) \
      && ok "Servidor GHL compilado en ~/ghl-mcp-server" || err "Falló la compilación del servidor GHL"
  fi
  if [[ -f "$HOME/ghl-mcp-server/dist/server.js" ]]; then
    claude mcp remove -s user ghl >/dev/null 2>&1 || true
    claude mcp add -s user ghl -e "GHL_API_KEY=$GHL_KEY" -e "GHL_LOCATION_ID=$GHL_LOC" \
      -- node "$HOME/ghl-mcp-server/dist/server.js" >/dev/null && ok "MCP GHL configurado (subcuenta $GHL_LOC)"
  fi
else warn "GHL omitido"; fi

# ════════════════════════════════════════════════════════════════
step "[ 6 / 10 ]  Meta Ads (conector oficial de Meta)"
# ════════════════════════════════════════════════════════════════
echo "  Requisito: tu cuenta publicitaria dentro de un Business Manager al que tengas acceso."
echo "  Se abre el navegador para iniciar sesión en Meta."
echo ""
ask "¿Conectar Meta Ads ahora? [S/n]:"; R="$(leer)"
if [[ ! "${R:-S}" =~ ^[nN] ]]; then
  claude mcp remove -s user meta-ads >/dev/null 2>&1 || true
  claude mcp add --transport http -s user meta-ads https://mcp.facebook.com/ads >/dev/null && ok "MCP meta-ads registrado"
  claude mcp login meta-ads < /dev/tty && ok "Meta Ads autorizado" || warn "Meta Ads: autorización pendiente (claude mcp login meta-ads)"
else warn "Meta Ads omitido"; fi

# ════════════════════════════════════════════════════════════════
step "[ 7 / 10 ]  Apify (scraping e inteligencia competitiva)"
# ════════════════════════════════════════════════════════════════
echo "  Apify corre los scrapers (Instagram, TikTok, Google, Meta Ad Library…) que alimentan la inteligencia."
echo "  Token: https://console.apify.com/settings/integrations → API tokens → copiá el token."
echo ""
ask "Token de API de Apify (Enter para saltar):"; APIFY_TOKEN="$(leer_secreto)"
if [[ -n "$APIFY_TOKEN" ]]; then
  claude mcp remove -s user apify >/dev/null 2>&1 || true
  claude mcp add --transport http -s user apify "https://mcp.apify.com" \
    --header "Authorization: Bearer $APIFY_TOKEN" >/dev/null && ok "MCP Apify configurado"
else warn "Apify omitido"; fi

# ════════════════════════════════════════════════════════════════
step "[ 8 / 10 ]  Fathom (grabación y transcripción de llamadas)"
# ════════════════════════════════════════════════════════════════
echo "  Fathom se conecta desde claude.ai y Claude Code lo toma solo:"
echo "  1. Abrí https://claude.ai/settings/connectors"
echo "  2. Buscá 'Fathom' → Connect → autorizá tu cuenta de Fathom."
echo "  (Ahí mismo podés sumar Notion si lo usás.)"
echo ""
pausa

# ════════════════════════════════════════════════════════════════
step "[ 9 / 10 ]  Discord (Claude te responde por DM desde tu bot)"
# ════════════════════════════════════════════════════════════════
echo "  1. https://discord.com/developers/applications → New Application → nombre."
echo "  2. Bot → activá 'Message Content Intent' → Reset Token → copiá el token."
echo "  3. OAuth2 → URL Generator → scope 'bot' → permisos: View Channels, Send Messages,"
echo "     Send Messages in Threads, Read Message History, Attach Files, Add Reactions."
echo "     Abrí la URL generada y agregá el bot a un servidor tuyo."
echo ""
ask "Token del bot de Discord (Enter para saltar):"; DISCORD_TOKEN="$(leer_secreto)"
if [[ -n "$DISCORD_TOKEN" ]]; then
  if ! command -v bun &>/dev/null && [[ ! -x "$HOME/.bun/bin/bun" ]]; then
    warn "Instalando Bun..."; curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1
  fi
  export PATH="$HOME/.bun/bin:$PATH"
  claude plugin install discord@claude-plugins-official >/dev/null 2>&1 && ok "Plugin de Discord instalado" || warn "El plugin se instala desde Claude Code: /plugin install discord@claude-plugins-official"
  mkdir -p "$HOME/.claude/channels/discord"
  echo "DISCORD_BOT_TOKEN=$DISCORD_TOKEN" > "$HOME/.claude/channels/discord/.env"; chmod 600 "$HOME/.claude/channels/discord/.env"
  ok "Token guardado en ~/.claude/channels/discord/.env"
  DISCORD_LISTO=1
else warn "Discord omitido"; DISCORD_LISTO=0; fi

# ════════════════════════════════════════════════════════════════
step "[ 10 / 10 ]  ElevenLabs (opcional — voz y audio)"
# ════════════════════════════════════════════════════════════════
ask "API key de ElevenLabs (Enter para saltar):"; EL_KEY="$(leer_secreto)"
if [[ -n "$EL_KEY" ]]; then
  if ! command -v uvx &>/dev/null; then
    warn "Instalando uv..."; curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1; export PATH="$HOME/.local/bin:$PATH"
  fi
  UVX="$(command -v uvx || echo "$HOME/.local/bin/uvx")"
  claude mcp remove -s user elevenlabs >/dev/null 2>&1 || true
  claude mcp add -s user elevenlabs -e "ELEVENLABS_API_KEY=$EL_KEY" -- "$UVX" elevenlabs-mcp >/dev/null && ok "MCP ElevenLabs configurado"
else warn "ElevenLabs omitido"; fi

# ════════════════════════════════════════════════════════════════
step "Verificación"
# ════════════════════════════════════════════════════════════════
claude mcp list 2>/dev/null | grep -vE "^Checking|^$" | sed 's/^/  /'
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   ✅  Setup local completado                     ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}  Próximos pasos:${NC}"
echo "  1. Si algún MCP dice 'Needs authentication': claude mcp login <nombre>"
if [[ "${DISCORD_LISTO:-0}" == "1" ]]; then
echo "  2. Discord: abrí Claude Code con   claude --channels plugin:discord@claude-plugins-official"
echo "     mandale un DM a tu bot, te contesta un código, y en Claude Code:  /discord:access pair <código>"
echo "     Después:  /discord:access policy allowlist"
fi
echo "  3. Instalá el vault de Obsidian:"
echo "     curl -sSL https://raw.githubusercontent.com/mazeos/client-vault-template/main/setup.sh -o setup-vault.sh && bash setup-vault.sh"
echo ""
