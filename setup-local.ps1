# setup-local.ps1 — Configura tu Windows para trabajar con el VPS
# Instala Claude Code y configura todos los MCPs.
# Ejecutar como Administrador.

#Requires -Version 5.1
$ErrorActionPreference = "Stop"

function Ok($msg)   { Write-Host "✓  $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "⚠  $msg" -ForegroundColor Yellow }
function Err($msg)  { Write-Host "✗  $msg" -ForegroundColor Red }
function Step($msg) { Write-Host "`n$msg" -ForegroundColor Cyan }
function Ask($msg)  { Write-Host "?  $msg" -ForegroundColor Yellow }

function Add-Mcp($Name, $Config) {
    $p = "$env:USERPROFILE\.claude.json"
    if (-not (Test-Path $p)) { '{}' | Set-Content $p -Encoding UTF8 }
    $c = Get-Content $p -Raw | ConvertFrom-Json
    if (-not $c.mcpServers) { $c | Add-Member -MemberType NoteProperty -Name mcpServers -Value ([PSCustomObject]@{}) }
    $c.mcpServers | Add-Member -MemberType NoteProperty -Name $Name -Value $Config -Force
    $c | ConvertTo-Json -Depth 10 | Set-Content $p -Encoding UTF8
}

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Err "Ejecuta PowerShell como Administrador (click derecho → Ejecutar como administrador)"
    exit 1
}

Clear-Host
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   VPS Template — Setup local (Windows)           ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Instala Claude Code y configura los MCPs en tu máquina."
Write-Host ""
Read-Host "  Presiona Enter para comenzar"

# ════════════════════════════════════════════════════════════════
Step "[ PASO 1 / 4 ]  Instalar prerrequisitos"
# ════════════════════════════════════════════════════════════════
Write-Host ""

if (Get-Command python -ErrorAction SilentlyContinue) {
    Ok "Python ($(python --version 2>&1))"
} else {
    Warn "Python no encontrado. Instalando..."
    winget install --id Python.Python.3 -e --accept-source-agreements --accept-package-agreements
    Ok "Python instalado"
}

if (Get-Command node -ErrorAction SilentlyContinue) {
    Ok "Node.js ($(node --version))"
} else {
    Warn "Node.js no encontrado. Instalando..."
    winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
    $env:PATH += ";$env:ProgramFiles\nodejs"
    Ok "Node.js instalado — reinicia la terminal si hay errores"
}

if (Get-Command claude -ErrorAction SilentlyContinue) {
    Ok "Claude Code instalado"
} else {
    Warn "Instalando Claude Code..."
    npm install -g "@anthropic-ai/claude-code"
    Ok "Claude Code instalado"
}

if (Get-Command git -ErrorAction SilentlyContinue) {
    Ok "Git instalado"
} else {
    Warn "Git no encontrado. Instalando..."
    winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
    Ok "Git instalado"
}

# ════════════════════════════════════════════════════════════════
Step "[ PASO 2 / 4 ]  Datos de tu servidor"
# ════════════════════════════════════════════════════════════════
Write-Host ""

Ask "Dominio principal del VPS (ej: miempresa.com):"
$Domain = Read-Host "  → "
while ([string]::IsNullOrWhiteSpace($Domain)) {
    Err "No puede estar vacío."
    $Domain = Read-Host "  → "
}

Ask "IP del VPS:"
$VpsIp = Read-Host "  → "

# ════════════════════════════════════════════════════════════════
Step "[ PASO 3 / 4 ]  Configurar MCPs"
# ════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  Configura los MCPs uno por uno."
Write-Host "  Presiona Enter para saltar cualquiera y configurarlo después."
Write-Host ""

$ClaudeJson = "$env:USERPROFILE\.claude.json"
if (-not (Test-Path $ClaudeJson)) { '{}' | Set-Content $ClaudeJson -Encoding UTF8 }

# ── MCP: n8n ──────────────────────────────────────────────────
Write-Host "  [MCP 1/7] n8n — https://n8n.$Domain" -ForegroundColor White
Write-Host "  API Key: n8n → Settings → n8n API → Create an API key"
Write-Host ""
Ask "n8n API Key (Enter para saltar):"
$N8nKey = Read-Host "  → "
if ($N8nKey) {
    Add-Mcp "n8n" ([PSCustomObject]@{
        command = "npx"; args = @("-y", "n8n-mcp-server")
        env = [PSCustomObject]@{ N8N_URL = "https://n8n.$Domain"; N8N_API_KEY = $N8nKey }
    })
    Ok "MCP n8n configurado"
} else { Warn "MCP n8n omitido" }
Write-Host ""

# ── MCP: Obsidian ─────────────────────────────────────────────
Write-Host "  [MCP 2/7] Obsidian — local" -ForegroundColor White
Write-Host "  Requiere plugin 'Local REST API' activo en Obsidian."
Write-Host ""
Ask "Ruta del vault (ej: C:\Users\Carlos\Documents\Obsidian Vault):"
$VaultPath = Read-Host "  → "
if ([string]::IsNullOrWhiteSpace($VaultPath)) { $VaultPath = "$env:USERPROFILE\Documents\Obsidian Vault" }
Ask "Obsidian API Key (Enter para saltar):"
$ObsKey = Read-Host "  → "
if ($ObsKey) {
    $vaultFwd = $VaultPath.Replace("\", "/")
    Add-Mcp "obsidian" ([PSCustomObject]@{
        command = "npx"; args = @("-y", "mcp-obsidian", $vaultFwd)
        env = [PSCustomObject]@{ OBSIDIAN_API_KEY = $ObsKey }
    })
    Ok "MCP Obsidian configurado"
} else { Warn "MCP Obsidian omitido" }
Write-Host ""

# ── MCP: Notion ───────────────────────────────────────────────
Write-Host "  [MCP 3/7] Notion" -ForegroundColor White
Write-Host "  API Key: https://www.notion.so/my-integrations"
Write-Host ""
Ask "Notion API Key (Enter para saltar):"
$NotionKey = Read-Host "  → "
if ($NotionKey) {
    $headers = "{`"Authorization`":`"Bearer $NotionKey`",`"Notion-Version`":`"2022-06-28`"}"
    Add-Mcp "notion" ([PSCustomObject]@{
        command = "npx"; args = @("-y", "@notionhq/notion-mcp-server")
        env = [PSCustomObject]@{ OPENAPI_MCP_HEADERS = $headers }
    })
    Ok "MCP Notion configurado"
} else { Warn "MCP Notion omitido" }
Write-Host ""

# ── MCP: Google ───────────────────────────────────────────────
Write-Host "  [MCP 4-6] Google Drive, Calendar y Gmail" -ForegroundColor White
Write-Host "  Requieren OAuth — configura manualmente después:"
Write-Host "  https://console.cloud.google.com/apis/credentials"
Write-Host ""
Warn "Google MCPs requieren configuración manual (OAuth)"
Write-Host ""

# ── MCP: GoHighLevel ──────────────────────────────────────────
Write-Host "  [MCP 7/7] GoHighLevel (GHL)" -ForegroundColor White
Write-Host "  Instala primero el servidor:"
Write-Host "  git clone https://github.com/mastanley13/GoHighLevel-MCP.git $env:USERPROFILE\ghl-mcp-server"
Write-Host ""
Ask "GHL API Key (Enter para saltar):"
$GhlKey = Read-Host "  → "
if ($GhlKey) {
    Ask "GHL Location ID:"
    $GhlLoc = Read-Host "  → "
    if ($GhlLoc) {
        Add-Mcp "ghl" ([PSCustomObject]@{
            command = "node"
            args = @("$env:USERPROFILE\ghl-mcp-server\dist\server.js")
            env = [PSCustomObject]@{ GHL_API_KEY = $GhlKey; GHL_LOCATION_ID = $GhlLoc }
        })
        Ok "MCP GHL configurado"
    } else { Warn "MCP GHL omitido — falta Location ID" }
} else { Warn "MCP GHL omitido" }
Write-Host ""

# ════════════════════════════════════════════════════════════════
Step "[ PASO 4 / 4 ]  Verificación final"
# ════════════════════════════════════════════════════════════════
Write-Host ""

$errors = 0
if (Get-Command claude -ErrorAction SilentlyContinue) { Ok "Claude Code instalado" } else { Err "Claude Code no encontrado"; $errors++ }
if (Test-Path $ClaudeJson) { Ok "~/.claude.json presente" } else { Err "~/.claude.json no encontrado"; $errors++ }

$mcpCount = 0
if (Test-Path $ClaudeJson) {
    $cfg = Get-Content $ClaudeJson -Raw | ConvertFrom-Json
    if ($cfg.mcpServers) { $mcpCount = ($cfg.mcpServers | Get-Member -MemberType NoteProperty).Count }
}
Ok "$mcpCount MCP(s) configurados"

Write-Host ""
if ($errors -eq 0) {
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║   ✅  Setup local completado                     ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Green
} else {
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║   ⚠️   Completado con $errors error(s)                   ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Próximos pasos:" -ForegroundColor White
Write-Host "  1. Verifica MCPs activos: claude mcp list"
Write-Host "  2. Configura tu vault de Obsidian:"
Write-Host "     irm https://raw.githubusercontent.com/mazeos/client-vault-template/main/setup.ps1 | iex"
Write-Host "  3. Corre: claude"
Write-Host ""
if ($VpsIp) { Write-Host "  Tu VPS: $VpsIp | Dominio: $Domain" }
Write-Host ""
