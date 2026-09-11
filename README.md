# VPS Template — Servidor base + Claude Code

Réplica del servidor de [Maze Funnels](https://mazefunnels.io): **Traefik + Supabase + n8n** en un VPS propio, más la configuración local de Claude Code y sus MCPs. Sincronizado con el servidor real en septiembre 2026.

> Después de este repo → [client-vault-template](https://github.com/mazeos/client-vault-template) (el vault de Obsidian). Son independientes: podés instalar uno solo.

## Qué levanta en el servidor

| Servicio | Qué hace | URL |
|---|---|---|
| Traefik v2.11 | Reverse proxy con SSL automático (Let's Encrypt) | `traefik.tudominio.com` |
| Supabase (oficial, self-hosted) | Postgres + Auth + API + Storage + Studio | `supabase.tudominio.com` |
| n8n 2.17.3 en modo cola | Automatizaciones, con worker y Redis | `n8n.tudominio.com` |

Además: firewall (solo 22, 80, 443), rotación de logs de Docker, backup diario de Supabase (30 días) y limpieza semanal de imágenes. Todo lo que instalás después (apps propias, otros servicios) se enchufa a la red `traefik-public` con 5 labels y sale con SSL solo.

## Requisitos

- Cuenta de Claude (Pro, Max o Team) con Claude Code.
- VPS con **Ubuntu 22.04 o 24.04**, mínimo **8 GB de RAM** (Supabase completo usa ~3 GB) y acceso root.
- Un dominio con 3 registros A apuntando a la IP del VPS: `traefik`, `n8n` y `supabase`. Si usás Cloudflare, **sin proxy** (nube gris) para que Let's Encrypt pueda emitir los certificados.

## Instalación

### Paso 1 — Servidor (corre DENTRO del VPS, como root)

```bash
curl -sSL https://raw.githubusercontent.com/mazeos/client-vps-template/main/setup-server.sh -o setup-server.sh && bash setup-server.sh
```

Pregunta 5 cosas (dominio, email para SSL, zona horaria y dos contraseñas opcionales) y en ~5 minutos deja los 3 servicios arriba. Al final imprime las credenciales y las guarda en `/root/vps-setup-summary.txt`.

### Paso 2 — Tu computadora

**Mac / Linux:**
```bash
curl -sSL https://raw.githubusercontent.com/mazeos/client-vps-template/main/setup-local.sh -o setup-local.sh && bash setup-local.sh
```

**Windows (PowerShell como Administrador):**
```powershell
irm https://raw.githubusercontent.com/mazeos/client-vps-template/main/setup-local.ps1 -OutFile $env:TEMP\setup-local.ps1; & $env:TEMP\setup-local.ps1
```

Instala Claude Code y conecta los MCPs del sistema, guiándote paso a paso en cada uno:

| # | MCP | Qué permite | Cómo se conecta |
|---|---|---|---|
| 1 | **Google Workspace**: Gmail, Calendar, Drive, Docs, Sheets | Leer, crear y editar correos, eventos, archivos, documentos y planillas | Servidores MCP oficiales de Google con tus propias credenciales OAuth (proyecto gratuito en Google Cloud, el script te guía) |
| 2 | **n8n** | Ejecutar y editar workflows de tu VPS | Servidor MCP nativo de n8n + token |
| 3 | **GoHighLevel** | Contactos, conversaciones, pipelines, calendarios de tu subcuenta | Servidor local compilado por el script + Private Integration Token |
| 4 | **Meta Ads** | Campañas, conjuntos, anuncios, métricas | Conector oficial de Meta, login en el navegador |
| 5 | **Fathom** | Transcripciones y resúmenes de tus llamadas | Conector desde claude.ai (2 clics) |
| 6 | **Discord** | Hablar con Claude por DM desde tu bot | Plugin oficial de Claude Code + bot propio |
| 7 | **ElevenLabs** (opcional) | Voz, audio, clonación | API key |

Cada MCP se puede saltar con Enter y agregar después volviendo a correr el script. El MCP de **Obsidian** lo configura el vault template (paso 3).

### Paso 3 — El vault de Obsidian

→ [client-vault-template](https://github.com/mazeos/client-vault-template)

## Estructura del repo

```
setup-server.sh                       → instalador del VPS (idempotente: se puede volver a correr)
setup-local.sh / setup-local.ps1      → Claude Code + MCPs en tu máquina
stacks/traefik/docker-compose.yml     → /docker/traefik
stacks/n8n/docker-compose.yml         → /docker/n8n
stacks/supabase/docker-compose.override.yml → se suma al compose oficial en /root/supabase/docker
host/                                 → daemon.json, cron de limpieza, script de backup
```

## Después de instalar

- **n8n**: entrá a `https://n8n.tudominio.com` y creá el usuario dueño. Para el MCP de n8n, generá una API key en Settings → n8n API.
- **Supabase Studio**: usuario `admin` y la contraseña del resumen. Las claves `ANON_KEY` y `SERVICE_ROLE_KEY` del resumen son las que usan tus apps.
- **Guardá el resumen en tu vault** (`03 Credenciales/`) y borralo del servidor si querés: `rm /root/vps-setup-summary.txt`.
- Para agregar una app propia: carpeta en `/docker/{app}`, compose con `networks: [traefik-public]` y los labels de Traefik (copiá los de `stacks/n8n`).

## Creado por

[Maze Funnels](https://mazefunnels.io)
