# VPS Template — Infraestructura + Claude Code

Stack completo de servidor y configuración local para operar tu negocio con IA.

> Primero este repo, luego → [client-vault-template](https://github.com/mazeos/client-vault-template)

## Qué incluye

| Componente | Qué hace |
|---|---|
| Traefik | Reverse proxy con SSL automático (Let's Encrypt) |
| n8n | Automatizaciones y workflows |
| Supabase | Base de datos + Studio UI |
| Portainer | Gestión visual de Docker |
| FlareSolverr | Bypass de Cloudflare para scraping |
| Playwright | Automatización de navegador |
| MCPs | Obsidian, n8n, Notion, Google, GHL |

## Instalación

### Paso 1 — Configura el servidor (corre en el VPS)

Contrata un VPS con Ubuntu 22.04+ (mínimo 2GB RAM). Luego conéctate y corre:

```bash
ssh root@IP_DE_TU_VPS
curl -sSL https://raw.githubusercontent.com/mazeos/client-vps-template/main/setup-server.sh | bash
```

### Paso 2 — Configura tu máquina local

**Mac:**
```bash
curl -sSL https://raw.githubusercontent.com/mazeos/client-vps-template/main/setup-local.sh | bash
```

**Windows (PowerShell como Administrador):**
```powershell
irm https://raw.githubusercontent.com/mazeos/client-vps-template/main/setup-local.ps1 | iex
```

### Paso 3 — Configura tu vault de Obsidian

Una vez que Claude Code esté instalado, sigue con:
[client-vault-template](https://github.com/mazeos/client-vault-template)

## Servicios disponibles tras la instalación

```
https://traefik.tudominio.com    → Dashboard de Traefik
https://n8n.tudominio.com        → n8n automatizaciones
https://supabase.tudominio.com   → Supabase Studio
https://portainer.tudominio.com  → Gestión Docker
https://flaresolverr.tudominio.com → FlareSolverr
https://playwright.tudominio.com → Playwright server
```

## MCPs configurados

| MCP | Tipo | Requiere |
|---|---|---|
| n8n | Apunta al VPS | API Key de n8n |
| Obsidian | Local | Plugin Local REST API |
| Notion | Externo | API Key |
| Google Drive/Calendar/Gmail | OAuth | credentials.json |
| GoHighLevel | Local | API Key + Location ID (repo `mastanley13/GoHighLevel-MCP`) |

> Notion y Google también pueden conectarse como integraciones desde `claude.ai/settings` sin instalar nada local.
> Meta Ads y Discord no vienen en el setup — agrégalos manualmente si los necesitas.

## Creado por

[Maze Funnels](https://mazefunnels.io)
