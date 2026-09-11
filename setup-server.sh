#!/bin/bash
# setup-server.sh — Levanta el servidor base (Traefik + Supabase + n8n) en un VPS Ubuntu limpio.
# Réplica del servidor de Maze Funnels. Correr como root DENTRO del VPS:
#   curl -sSL https://raw.githubusercontent.com/mazeos/client-vps-template/main/setup-server.sh -o setup-server.sh && bash setup-server.sh
set -euo pipefail

RAW="https://raw.githubusercontent.com/mazeos/client-vps-template/main"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "${RED}✗${NC} $1"; }
step() { echo -e "\n${BOLD}${CYAN}$1${NC}\n"; }
ask()  { echo -e "${YELLOW}?${NC}  $1"; }
leer() { local v; read -r -p "  → " v < /dev/tty; echo "$v"; }
leer_secreto() { local v; read -r -s -p "  → " v < /dev/tty; echo "" >&2; echo "$v"; }
rand_hex() { openssl rand -hex "$1"; }
rand_pass() { openssl rand -base64 24 | tr -d '/+=' | cut -c1-20; }

[[ "$(uname -s)" == "Linux" ]] || { err "Este script corre dentro del VPS (Linux)."; exit 1; }
[[ "$(id -u)" == "0" ]] || { err "Correlo como root: sudo bash setup-server.sh"; exit 1; }

clear
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   VPS Template — Servidor base                   ║${NC}"
echo -e "${BOLD}${CYAN}║   Traefik + Supabase + n8n                       ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Antes de seguir, en tu DNS creá estos registros A apuntando a la IP de este VPS"
echo "  (sin proxy de Cloudflare, para que Let's Encrypt pueda emitir los certificados):"
echo "    traefik.TUDOMINIO · n8n.TUDOMINIO · supabase.TUDOMINIO"
echo ""
read -r -p "  Presioná Enter para comenzar..." < /dev/tty

# ════════════════════════════════════════════════════════════════
step "[ 1 / 7 ]  Datos del servidor"
# ════════════════════════════════════════════════════════════════
ask "Dominio base (ej: miempresa.com):"; DOMAIN="$(leer)"
while [[ -z "$DOMAIN" ]]; do err "No puede estar vacío."; DOMAIN="$(leer)"; done
ask "Email para los certificados SSL (Let's Encrypt):"; ACME_EMAIL="$(leer)"
while [[ -z "$ACME_EMAIL" ]]; do err "No puede estar vacío."; ACME_EMAIL="$(leer)"; done
ask "Zona horaria [America/Caracas]:"; TZ_IN="$(leer)"; TZ_VAL="${TZ_IN:-America/Caracas}"
ask "Contraseña para el dashboard de Traefik (Enter = generar una):"; TRAEFIK_PASS="$(leer_secreto)"
[[ -z "$TRAEFIK_PASS" ]] && TRAEFIK_PASS="$(rand_pass)"
ask "Contraseña para Supabase Studio (Enter = generar una):"; DASHBOARD_PASSWORD="$(leer_secreto)"
[[ -z "$DASHBOARD_PASSWORD" ]] && DASHBOARD_PASSWORD="$(rand_pass)"

echo ""
echo -e "  Dominio   → ${BOLD}$DOMAIN${NC}"
echo -e "  SSL email → ${BOLD}$ACME_EMAIL${NC}"
echo -e "  Zona hor. → ${BOLD}$TZ_VAL${NC}"
echo ""
read -r -p "  ¿Continuar? [S/n]: " CONFIRM < /dev/tty
[[ "${CONFIRM:-S}" =~ ^[nN] ]] && { echo "  Cancelado."; exit 0; }

# ════════════════════════════════════════════════════════════════
step "[ 2 / 7 ]  Sistema, Docker y firewall"
# ════════════════════════════════════════════════════════════════
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y -qq curl git ufw apache2-utils python3 openssl jq >/dev/null
ok "Paquetes base"

if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
fi
ok "Docker $(docker --version | awk '{print $3}' | tr -d ,)"

mkdir -p /etc/docker
curl -fsSL "$RAW/host/docker-daemon.json" -o /etc/docker/daemon.json
systemctl restart docker
ok "Logs de Docker limitados (10 MB × 3 por contenedor)"

ufw allow 22/tcp >/dev/null; ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null
ufw --force enable >/dev/null
ok "Firewall activo: solo 22, 80 y 443"

docker network inspect traefik-public >/dev/null 2>&1 || docker network create traefik-public >/dev/null
ok "Red traefik-public"

# ════════════════════════════════════════════════════════════════
step "[ 3 / 7 ]  Traefik (proxy + SSL)"
# ════════════════════════════════════════════════════════════════
mkdir -p /docker/traefik && cd /docker/traefik
curl -fsSL "$RAW/stacks/traefik/docker-compose.yml" -o docker-compose.yml
touch acme.json && chmod 600 acme.json
# htpasswd genera $ que docker compose interpreta como variable → se duplican
TRAEFIK_AUTH="$(htpasswd -nbB admin "$TRAEFIK_PASS" | sed -e 's/\$/\$\$/g')"
cat > .env <<ENV
DOMAIN=$DOMAIN
ACME_EMAIL=$ACME_EMAIL
TRAEFIK_DASHBOARD_AUTH=$TRAEFIK_AUTH
ENV
chmod 600 .env
docker compose up -d >/dev/null
ok "Traefik arriba → https://traefik.$DOMAIN"

# ════════════════════════════════════════════════════════════════
step "[ 4 / 7 ]  Supabase (self-hosted oficial)"
# ════════════════════════════════════════════════════════════════
SB=/root/supabase/docker
if [[ ! -f "$SB/docker-compose.yml" ]]; then
  rm -rf /tmp/supabase-src
  git clone -q --depth 1 https://github.com/supabase/supabase /tmp/supabase-src
  mkdir -p /root/supabase && cp -r /tmp/supabase-src/docker "$SB" && rm -rf /tmp/supabase-src
fi
cd "$SB"
curl -fsSL "$RAW/stacks/supabase/docker-compose.override.yml" -o docker-compose.override.yml
cp -n .env.example .env

POSTGRES_PASSWORD="$(rand_hex 16)"
JWT_SECRET="$(rand_hex 20)"
python3 - "$SB/.env" "$JWT_SECRET" "$POSTGRES_PASSWORD" "$DASHBOARD_PASSWORD" "$DOMAIN" <<'PYEOF'
import sys, re, json, hmac, hashlib, base64, time, secrets
env_path, jwt_secret, pg_pass, dash_pass, domain = sys.argv[1:6]

def b64(b): return base64.urlsafe_b64encode(b).rstrip(b"=").decode()
def jwt(role):
    now = int(time.time())
    header = b64(json.dumps({"alg":"HS256","typ":"JWT"}, separators=(",",":")).encode())
    payload = b64(json.dumps({"role":role,"iss":"supabase","iat":now,"exp":now+10*365*24*3600}, separators=(",",":")).encode())
    sig = b64(hmac.new(jwt_secret.encode(), f"{header}.{payload}".encode(), hashlib.sha256).digest())
    return f"{header}.{payload}.{sig}"

valores = {
  "POSTGRES_PASSWORD": pg_pass,
  "JWT_SECRET": jwt_secret,
  "ANON_KEY": jwt("anon"),
  "SERVICE_ROLE_KEY": jwt("service_role"),
  "DASHBOARD_USERNAME": "admin",
  "DASHBOARD_PASSWORD": dash_pass,
  "SECRET_KEY_BASE": secrets.token_hex(32),
  "VAULT_ENC_KEY": secrets.token_hex(16),
  "PG_META_CRYPTO_KEY": secrets.token_hex(16),
  "LOGFLARE_PUBLIC_ACCESS_TOKEN": secrets.token_hex(16),
  "LOGFLARE_PRIVATE_ACCESS_TOKEN": secrets.token_hex(16),
  "LOGFLARE_API_KEY": secrets.token_hex(16),
  "S3_PROTOCOL_ACCESS_KEY_ID": secrets.token_hex(16),
  "S3_PROTOCOL_ACCESS_KEY_SECRET": secrets.token_hex(32),
  "POOLER_TENANT_ID": "default",
  "SITE_URL": f"https://supabase.{domain}",
  "API_EXTERNAL_URL": f"https://supabase.{domain}",
  "SUPABASE_PUBLIC_URL": f"https://supabase.{domain}",
  "STUDIO_DEFAULT_ORGANIZATION": domain,
  "STUDIO_DEFAULT_PROJECT": "principal",
  "DOMAIN": domain,
}
txt = open(env_path, encoding="utf-8").read()
for k, v in valores.items():
    if re.search(rf"^{k}=", txt, flags=re.M):
        txt = re.sub(rf"^{k}=.*$", f"{k}={v}", txt, flags=re.M)
    else:
        txt += f"\n{k}={v}"
open(env_path, "w", encoding="utf-8").write(txt)
PYEOF
chmod 600 .env
docker compose pull -q 2>/dev/null || true
docker compose up -d >/dev/null
ok "Supabase arriba → https://supabase.$DOMAIN (Studio: admin)"

# ════════════════════════════════════════════════════════════════
step "[ 5 / 7 ]  n8n (modo cola)"
# ════════════════════════════════════════════════════════════════
mkdir -p /docker/n8n && cd /docker/n8n
curl -fsSL "$RAW/stacks/n8n/docker-compose.yml" -o docker-compose.yml
N8N_ENCRYPTION_KEY="$(rand_hex 16)"
cat > .env <<ENV
DOMAIN=$DOMAIN
TZ=$TZ_VAL
N8N_VERSION=2.17.3
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
ENV
chmod 600 .env
docker compose up -d >/dev/null
ok "n8n arriba → https://n8n.$DOMAIN (creá el usuario dueño al entrar por primera vez)"

# ════════════════════════════════════════════════════════════════
step "[ 6 / 7 ]  Backups y mantenimiento"
# ════════════════════════════════════════════════════════════════
curl -fsSL "$RAW/host/backup-supabase.sh" -o /usr/local/bin/backup-supabase.sh && chmod +x /usr/local/bin/backup-supabase.sh
curl -fsSL "$RAW/host/cron.d-docker-prune" -o /etc/cron.d/docker-prune && chmod 644 /etc/cron.d/docker-prune
( crontab -l 2>/dev/null | grep -v backup-supabase.sh; echo "0 3 * * * /usr/local/bin/backup-supabase.sh >> /var/log/supabase-backup.log 2>&1" ) | crontab -
ok "Backup diario de Supabase (03:00, 30 días) + limpieza semanal de imágenes"

# ════════════════════════════════════════════════════════════════
step "[ 7 / 7 ]  Resumen"
# ════════════════════════════════════════════════════════════════
SUMMARY=/root/vps-setup-summary.txt
cat > "$SUMMARY" <<TXT
Servidor base instalado el $(date '+%Y-%m-%d %H:%M') — dominio $DOMAIN

Traefik   https://traefik.$DOMAIN     usuario: admin   contraseña: $TRAEFIK_PASS
Supabase  https://supabase.$DOMAIN    usuario: admin   contraseña: $DASHBOARD_PASSWORD
n8n       https://n8n.$DOMAIN         (creá el usuario dueño en el primer ingreso)

Supabase — claves para apps y n8n (Postgres host: supabase-db, puerto 5432, usuario postgres):
  POSTGRES_PASSWORD  $POSTGRES_PASSWORD
  ANON_KEY           $(grep '^ANON_KEY=' $SB/.env | cut -d= -f2-)
  SERVICE_ROLE_KEY   $(grep '^SERVICE_ROLE_KEY=' $SB/.env | cut -d= -f2-)
n8n — N8N_ENCRYPTION_KEY: $N8N_ENCRYPTION_KEY (guardala: sin ella no se recuperan las credenciales de n8n)

Rutas: /docker/traefik · /docker/n8n · /root/supabase/docker · backups en /root/backups/supabase
TXT
chmod 600 "$SUMMARY"
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   ✅  Servidor base instalado                    ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
cat "$SUMMARY"
echo ""
echo -e "${BOLD}  Guardá estas credenciales en tu vault (03 Credenciales/).${NC} Copia en $SUMMARY"
echo "  Los certificados SSL tardan 1-2 minutos en emitirse la primera vez."
echo ""
echo "  Siguiente paso, en tu computadora:"
echo "    curl -sSL $RAW/setup-local.sh -o setup-local.sh && bash setup-local.sh"
echo ""
