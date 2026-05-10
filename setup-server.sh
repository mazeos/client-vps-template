#!/bin/bash
# setup-server.sh — Configura el VPS desde cero (Ubuntu 22.04+)
# Corre este script DENTRO del VPS, no en tu máquina local.
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "${RED}✗${NC} $1"; exit 1; }
step() { echo -e "\n${BOLD}${CYAN}$1${NC}"; }
ask()  { echo -e "${YELLOW}?${NC}  $1"; }

# ── Verificar que corre en Linux ────────────────────────────────
[[ "$OSTYPE" != "linux-gnu"* ]] && err "Este script debe correr en el VPS (Ubuntu/Debian), no en tu máquina local."
[[ "$EUID" -ne 0 ]] && err "Corre como root: sudo bash setup-server.sh"

clear
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   VPS Template — Setup del servidor              ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Configura Docker + el stack completo en este servidor."
echo "  Servicios: Traefik, n8n, Supabase, Portainer, FlareSolverr, Playwright"
echo ""
read -p "  Presiona Enter para comenzar..."

# ════════════════════════════════════════════════════════════════
step "[ PASO 1 / 5 ]  Instalar Docker"
# ════════════════════════════════════════════════════════════════
echo ""

if command -v docker &>/dev/null; then
  ok "Docker ya instalado ($(docker --version))"
else
  echo "  Instalando Docker..."
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable docker
  systemctl start docker
  ok "Docker instalado"
fi

if docker compose version &>/dev/null; then
  ok "Docker Compose disponible"
else
  err "Docker Compose no encontrado. Reinstala Docker."
fi

# ════════════════════════════════════════════════════════════════
step "[ PASO 2 / 5 ]  Configuración del servidor"
# ════════════════════════════════════════════════════════════════
echo ""
echo "  Necesitas tener un dominio apuntando a la IP de este servidor."
echo "  Ejemplo: si tu dominio es 'miempresa.com', los subdominios"
echo "  n8n.miempresa.com, supabase.miempresa.com etc. deben apuntar aquí."
echo ""

ask "Tu dominio principal (ej: miempresa.com):"
read -p "  → " DOMAIN
while [[ -z "$DOMAIN" ]]; do
  err "El dominio no puede estar vacío."; read -p "  → " DOMAIN
done

ask "Tu email (para certificados SSL de Let's Encrypt):"
read -p "  → " ACME_EMAIL
while [[ -z "$ACME_EMAIL" ]]; do
  err "El email no puede estar vacío."; read -p "  → " ACME_EMAIL
done

echo ""
echo "  Ahora configura las contraseñas. Usa contraseñas seguras."
echo ""

ask "Password para el dashboard de Traefik:"
read -s -p "  → " TRAEFIK_PASS; echo ""
while [[ -z "$TRAEFIK_PASS" ]]; do
  err "No puede estar vacío."; read -s -p "  → " TRAEFIK_PASS; echo ""
done

ask "Password para n8n:"
read -s -p "  → " N8N_PASS; echo ""
while [[ -z "$N8N_PASS" ]]; do
  err "No puede estar vacío."; read -s -p "  → " N8N_PASS; echo ""
done

ask "Password para la base de datos (PostgreSQL):"
read -s -p "  → " DB_PASS; echo ""
while [[ -z "$DB_PASS" ]]; do
  err "No puede estar vacío."; read -s -p "  → " DB_PASS; echo ""
done

ask "Password para Playwright (token de acceso):"
read -s -p "  → " PLAYWRIGHT_PASS; echo ""
while [[ -z "$PLAYWRIGHT_PASS" ]]; do
  err "No puede estar vacío."; read -s -p "  → " PLAYWRIGHT_PASS; echo ""
done

# Generar claves automáticamente
N8N_KEY=$(openssl rand -hex 16)
JWT_SECRET=$(openssl rand -hex 32)
TRAEFIK_HASH=$(docker run --rm httpd:alpine htpasswd -nbB admin "$TRAEFIK_PASS" | sed 's/\$/$$/g' | cut -d: -f2)

# ════════════════════════════════════════════════════════════════
step "[ PASO 3 / 5 ]  Crear archivos de configuración"
# ════════════════════════════════════════════════════════════════
echo ""

INSTALL_DIR="/opt/vps-stack"
mkdir -p "$INSTALL_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/docker/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml"

cat > "$INSTALL_DIR/.env" <<EOF
DOMAIN=$DOMAIN
ACME_EMAIL=$ACME_EMAIL

TRAEFIK_DASHBOARD_USER=admin
TRAEFIK_DASHBOARD_PASSWORD=$TRAEFIK_HASH

N8N_ENCRYPTION_KEY=$N8N_KEY
N8N_USER=admin
N8N_PASSWORD=$N8N_PASS

POSTGRES_PASSWORD=$DB_PASS
POSTGRES_DB=supabase
JWT_SECRET=$JWT_SECRET
ANON_KEY=placeholder_anon_key
SERVICE_ROLE_KEY=placeholder_service_key

FLARESOLVERR_LOG_LEVEL=info

PLAYWRIGHT_TOKEN=$PLAYWRIGHT_PASS
EOF

chmod 600 "$INSTALL_DIR/.env"
ok "Archivos creados en $INSTALL_DIR"

# Crear directorio para acme.json de Traefik
mkdir -p "$INSTALL_DIR/letsencrypt"
touch "$INSTALL_DIR/letsencrypt/acme.json"
chmod 600 "$INSTALL_DIR/letsencrypt/acme.json"

# ════════════════════════════════════════════════════════════════
step "[ PASO 4 / 5 ]  Levantar el stack"
# ════════════════════════════════════════════════════════════════
echo ""
echo "  Descargando imágenes y levantando servicios..."
echo "  (Esto puede tardar 3-5 minutos la primera vez)"
echo ""

cd "$INSTALL_DIR"
docker compose up -d

ok "Stack levantado"

# ════════════════════════════════════════════════════════════════
step "[ PASO 5 / 5 ]  Verificación"
# ════════════════════════════════════════════════════════════════
echo ""

sleep 5

ERRORS=0
for service in traefik n8n postgres supabase-studio portainer flaresolverr playwright; do
  STATUS=$(docker compose ps --format "{{.Service}} {{.State}}" 2>/dev/null | grep "^$service " | awk '{print $2}')
  if [[ "$STATUS" == "running" ]]; then
    ok "$service corriendo"
  else
    warn "$service — estado: ${STATUS:-desconocido}"
    ERRORS=$((ERRORS+1))
  fi
done

echo ""
if [[ $ERRORS -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║   ✅  Servidor configurado correctamente         ║${NC}"
  echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
else
  echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${YELLOW}${BOLD}║   ⚠️   Servidor levantado con $ERRORS advertencia(s)      ║${NC}"
  echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
fi

echo ""
echo -e "${BOLD}  URLs de tus servicios:${NC}"
echo "  🔒 Traefik    → https://traefik.$DOMAIN"
echo "  ⚡ n8n         → https://n8n.$DOMAIN"
echo "  🗄  Supabase   → https://supabase.$DOMAIN"
echo "  🐳 Portainer  → https://portainer.$DOMAIN"
echo "  🌐 FlareSolverr → https://flaresolverr.$DOMAIN"
echo "  🎭 Playwright  → https://playwright.$DOMAIN"
echo ""
echo -e "${BOLD}  Credenciales guardadas en:${NC} $INSTALL_DIR/.env"
echo ""
echo "  Siguiente paso: corre setup-local.sh (Mac) o setup-local.ps1 (Windows)"
echo "  en TU MÁQUINA para instalar Claude Code y configurar los MCPs."
echo ""

# Guardar resumen para el setup local
cat > "$INSTALL_DIR/server-info.txt" <<EOF
DOMAIN=$DOMAIN
N8N_URL=https://n8n.$DOMAIN
PLAYWRIGHT_URL=https://playwright.$DOMAIN
FLARESOLVERR_URL=https://flaresolverr.$DOMAIN
EOF
