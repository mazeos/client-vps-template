# setup-local.ps1 — Configura tu Windows para operar con Claude Code.
# Instala Claude Code y conecta los MCPs del sistema: Google Workspace (lectura y escritura),
# n8n, GoHighLevel, Meta Ads, Apify, Fathom, Discord y ElevenLabs (opcional).
# PowerShell como Administrador:
#   irm https://raw.githubusercontent.com/mazeos/client-vps-template/main/setup-local.ps1 -OutFile $env:TEMP\setup-local.ps1; & $env:TEMP\setup-local.ps1
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Ok($m)   { Write-Host "OK  $m" -ForegroundColor Green }
function Warn($m) { Write-Host "!   $m" -ForegroundColor Yellow }
function Err($m)  { Write-Host "X   $m" -ForegroundColor Red }
function Step($m) { Write-Host "`n$m`n" -ForegroundColor Cyan }
function Ask($m)  { Write-Host "?   $m" -ForegroundColor Yellow }
function Leer()   { return (Read-Host "  ->").Trim() }
function LeerSecreto() { $s = Read-Host "  ->" -AsSecureString; return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)) }
function Pausa()  { Read-Host "  Presiona Enter cuando este listo" | Out-Null }
function Refrescar-Path { $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User") }
$CallbackPort = 33418
$GoogleRedirect = "http://localhost:$CallbackPort/callback"

Clear-Host
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Setup local - Claude Code + MCPs (Windows)     " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Vas a conectar, en este orden:"
Write-Host "    1. Google Workspace (Gmail, Calendar, Drive, Docs, Sheets)"
Write-Host "    2. n8n de tu VPS       3. GoHighLevel       4. Meta Ads       5. Apify"
Write-Host "    6. Fathom              7. Discord           8. ElevenLabs (opcional)"
Write-Host ""
Pausa

# ---------------------------------------------------------------
Step "[ 1 / 10 ]  Prerrequisitos"
# ---------------------------------------------------------------
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Err "Falta winget (App Installer de la Microsoft Store). Instalalo y volve a correr."; exit 1 }
foreach ($t in @(@{cmd="git"; id="Git.Git"}, @{cmd="node"; id="OpenJS.NodeJS.LTS"}, @{cmd="python"; id="Python.Python.3.12"})) {
  if (Get-Command $t.cmd -ErrorAction SilentlyContinue) { Ok "$($t.cmd) instalado" }
  else { Warn "Instalando $($t.cmd)..."; winget install --id $t.id -e --silent --accept-package-agreements --accept-source-agreements | Out-Null; Refrescar-Path }
}
if (Get-Command claude -ErrorAction SilentlyContinue) { Ok "Claude Code instalado" }
else { Warn "Instalando Claude Code..."; npm install -g @anthropic-ai/claude-code | Out-Null; Refrescar-Path; Ok "Claude Code instalado" }
Write-Host ""
Write-Host "  Si todavia no iniciaste sesion en Claude Code, abri otra terminal, corre 'claude' y segui el login."
Pausa

# ---------------------------------------------------------------
Step "[ 2 / 10 ]  Datos de tu servidor"
# ---------------------------------------------------------------
Ask "Dominio base de tu VPS (ej: miempresa.com):"; $Domain = Leer
while (-not $Domain) { Err "No puede estar vacio."; $Domain = Leer }

# ---------------------------------------------------------------
Step "[ 3 / 10 ]  Google Workspace - Gmail, Calendar, Drive, Docs y Sheets (lectura y escritura)"
# ---------------------------------------------------------------
Write-Host "  Google publica servidores MCP oficiales. Necesitas credenciales OAuth propias (gratis, 10 minutos):"
Write-Host ""
Write-Host "  1. Entra a https://console.cloud.google.com y crea un proyecto (ej: 'Claude Code')."
Write-Host "  2. APIs y servicios -> Biblioteca: habilita Gmail API, Google Drive API, Google Docs API,"
Write-Host "     Google Sheets API y Google Calendar API."
Write-Host "  3. En la misma Biblioteca habilita los servicios MCP: 'Gmail MCP', 'Drive MCP', 'Docs MCP',"
Write-Host "     'Sheets MCP' y 'Calendar MCP' (busca 'MCP')."
Write-Host "  4. Pantalla de consentimiento OAuth: tipo Externo, agrega tu email como usuario de prueba."
Write-Host "  5. Credenciales -> Crear credenciales -> ID de cliente OAuth -> Aplicacion web."
Write-Host "     En 'URI de redireccionamiento autorizados' agrega EXACTAMENTE estos dos:"
Write-Host "        $GoogleRedirect" -ForegroundColor White
Write-Host "        https://claude.ai/api/mcp/auth_callback" -ForegroundColor White
Write-Host "  6. Copia el ID de cliente y el secreto."
Write-Host ""
Ask "ID de cliente OAuth de Google (Enter para saltar Google):"; $GClientId = Leer
if ($GClientId) {
  Ask "Secreto del cliente OAuth:"; $GSecret = LeerSecreto
  $GoogleMcps = @(
    @{n="gmail";           u="https://gmailmcp.googleapis.com/mcp/v1"},
    @{n="google-calendar"; u="https://calendarmcp.googleapis.com/mcp/v1"},
    @{n="google-drive";    u="https://drivemcp.googleapis.com/mcp/v1"},
    @{n="google-docs";     u="https://docsmcp.googleapis.com/mcp/v1"},
    @{n="google-sheets";   u="https://sheetsmcp.googleapis.com/mcp/v1"}
  )
  foreach ($m in $GoogleMcps) {
    & claude mcp remove -s user $m.n 2>$null | Out-Null
    $env:MCP_CLIENT_SECRET = $GSecret
    & claude mcp add --transport http -s user --client-id $GClientId --client-secret --callback-port $CallbackPort $m.n $m.u | Out-Null
    Ok "MCP $($m.n) registrado"
  }
  Remove-Item Env:MCP_CLIENT_SECRET -ErrorAction SilentlyContinue
  Write-Host ""
  Write-Host "  Ahora se abre el navegador 5 veces (una por servicio) para que autorices tu cuenta de Google."
  Pausa
  foreach ($m in $GoogleMcps) { & claude mcp login $m.n; if ($LASTEXITCODE -eq 0) { Ok "$($m.n) autorizado" } else { Warn "$($m.n): pendiente (claude mcp login $($m.n))" } }
} else { Warn "Google omitido." }

# ---------------------------------------------------------------
Step "[ 4 / 10 ]  n8n - tu instancia en https://n8n.$Domain"
# ---------------------------------------------------------------
Write-Host "  1. Entra a https://n8n.$Domain -> Settings -> Instance-level MCP -> 'Enable MCP access'."
Write-Host "  2. Boton 'Connect a client' -> pestana API key -> copia el token."
Write-Host "  3. Cada workflow que quieras que Claude use: menu del workflow -> Settings -> 'Available in MCP'."
Write-Host ""
Ask "Token MCP de n8n (Enter para saltar):"; $N8nToken = LeerSecreto
if ($N8nToken) {
  & claude mcp remove -s user n8n 2>$null | Out-Null
  & claude mcp add --transport http -s user n8n "https://n8n.$Domain/mcp-server/http" --header "Authorization: Bearer $N8nToken" | Out-Null
  Ok "MCP n8n -> https://n8n.$Domain"
} else { Warn "n8n omitido" }

# ---------------------------------------------------------------
Step "[ 5 / 10 ]  GoHighLevel"
# ---------------------------------------------------------------
Write-Host "  En GHL: Settings de la subcuenta -> Private Integrations -> crear una con todos los scopes -> copia el token."
Write-Host "  El Location ID esta en Settings -> Business Profile."
Write-Host ""
Ask "Private Integration Token de GHL (Enter para saltar):"; $GhlKey = LeerSecreto
if ($GhlKey) {
  Ask "Location ID de la subcuenta:"; $GhlLoc = Leer
  $GhlDir = "$env:USERPROFILE\ghl-mcp-server"
  if (-not (Test-Path "$GhlDir\dist\server.js")) {
    Warn "Instalando el servidor MCP de GHL (1-2 minutos)..."
    if (Test-Path $GhlDir) { Remove-Item $GhlDir -Recurse -Force }
    git clone -q https://github.com/mastanley13/GoHighLevel-MCP.git $GhlDir
    Push-Location $GhlDir; npm install --silent | Out-Null; npm run build --silent | Out-Null; Pop-Location
  }
  if (Test-Path "$GhlDir\dist\server.js") {
    & claude mcp remove -s user ghl 2>$null | Out-Null
    & claude mcp add -s user ghl -e "GHL_API_KEY=$GhlKey" -e "GHL_LOCATION_ID=$GhlLoc" -- node "$GhlDir\dist\server.js" | Out-Null
    Ok "MCP GHL configurado (subcuenta $GhlLoc)"
  } else { Err "Fallo la compilacion del servidor GHL" }
} else { Warn "GHL omitido" }

# ---------------------------------------------------------------
Step "[ 6 / 10 ]  Meta Ads (conector oficial de Meta)"
# ---------------------------------------------------------------
Write-Host "  Requisito: tu cuenta publicitaria dentro de un Business Manager al que tengas acceso."
Ask "Conectar Meta Ads ahora? [S/n]:"; $R = Leer
if ($R -notmatch '^[nN]') {
  & claude mcp remove -s user meta-ads 2>$null | Out-Null
  & claude mcp add --transport http -s user meta-ads https://mcp.facebook.com/ads | Out-Null
  & claude mcp login meta-ads; if ($LASTEXITCODE -eq 0) { Ok "Meta Ads autorizado" } else { Warn "Meta Ads pendiente (claude mcp login meta-ads)" }
} else { Warn "Meta Ads omitido" }

# ---------------------------------------------------------------
Step "[ 7 / 10 ]  Apify (scraping e inteligencia competitiva)"
# ---------------------------------------------------------------
Write-Host "  Apify corre los scrapers (Instagram, TikTok, Google, Meta Ad Library...) que alimentan la inteligencia."
Write-Host "  Token: https://console.apify.com/settings/integrations -> API tokens -> copia el token."
Write-Host ""
Ask "Token de API de Apify (Enter para saltar):"; $ApifyToken = LeerSecreto
if ($ApifyToken) {
  & claude mcp remove -s user apify 2>$null | Out-Null
  & claude mcp add --transport http -s user apify "https://mcp.apify.com" --header "Authorization: Bearer $ApifyToken" | Out-Null
  Ok "MCP Apify configurado"
} else { Warn "Apify omitido" }

# ---------------------------------------------------------------
Step "[ 8 / 10 ]  Fathom (grabacion y transcripcion de llamadas)"
# ---------------------------------------------------------------
Write-Host "  1. Abri https://claude.ai/settings/connectors"
Write-Host "  2. Busca 'Fathom' -> Connect -> autoriza tu cuenta. (Ahi mismo podes sumar Notion si lo usas.)"
Write-Host ""
Pausa

# ---------------------------------------------------------------
Step "[ 9 / 10 ]  Discord (Claude te responde por DM desde tu bot)"
# ---------------------------------------------------------------
Write-Host "  1. https://discord.com/developers/applications -> New Application -> nombre."
Write-Host "  2. Bot -> activa 'Message Content Intent' -> Reset Token -> copia el token."
Write-Host "  3. OAuth2 -> URL Generator -> scope 'bot' -> permisos: View Channels, Send Messages,"
Write-Host "     Send Messages in Threads, Read Message History, Attach Files, Add Reactions."
Write-Host "     Abri la URL generada y agrega el bot a un servidor tuyo."
Write-Host ""
Ask "Token del bot de Discord (Enter para saltar):"; $DiscordToken = LeerSecreto
$DiscordListo = $false
if ($DiscordToken) {
  if (-not (Get-Command bun -ErrorAction SilentlyContinue)) { Warn "Instalando Bun..."; powershell -c "irm bun.sh/install.ps1 | iex" | Out-Null; Refrescar-Path }
  & claude plugin install discord@claude-plugins-official 2>$null | Out-Null
  $ChanDir = "$env:USERPROFILE\.claude\channels\discord"; New-Item -ItemType Directory -Force $ChanDir | Out-Null
  "DISCORD_BOT_TOKEN=$DiscordToken" | Set-Content "$ChanDir\.env" -Encoding UTF8
  Ok "Plugin de Discord instalado y token guardado en ~\.claude\channels\discord\.env"
  $DiscordListo = $true
} else { Warn "Discord omitido" }

# ---------------------------------------------------------------
Step "[ 10 / 10 ]  ElevenLabs (opcional - voz y audio)"
# ---------------------------------------------------------------
Ask "API key de ElevenLabs (Enter para saltar):"; $ElKey = LeerSecreto
if ($ElKey) {
  if (-not (Get-Command uvx -ErrorAction SilentlyContinue)) { Warn "Instalando uv..."; powershell -c "irm https://astral.sh/uv/install.ps1 | iex" | Out-Null; Refrescar-Path }
  & claude mcp remove -s user elevenlabs 2>$null | Out-Null
  & claude mcp add -s user elevenlabs -e "ELEVENLABS_API_KEY=$ElKey" -- uvx elevenlabs-mcp | Out-Null
  Ok "MCP ElevenLabs configurado"
} else { Warn "ElevenLabs omitido" }

# ---------------------------------------------------------------
Step "Verificacion"
# ---------------------------------------------------------------
& claude mcp list
Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "   OK  Setup local completado                     " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Proximos pasos:" -ForegroundColor White
Write-Host "  1. Si algun MCP dice 'Needs authentication':  claude mcp login <nombre>"
if ($DiscordListo) {
Write-Host "  2. Discord: abri Claude Code con   claude --channels plugin:discord@claude-plugins-official"
Write-Host "     mandale un DM a tu bot, te contesta un codigo, y en Claude Code:  /discord:access pair <codigo>"
Write-Host "     Despues:  /discord:access policy allowlist"
}
Write-Host "  3. Instala el vault de Obsidian:"
Write-Host "     irm https://raw.githubusercontent.com/mazeos/client-vault-template/main/setup.ps1 -OutFile `$env:TEMP\setup-vault.ps1; & `$env:TEMP\setup-vault.ps1"
Write-Host ""
