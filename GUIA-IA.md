# Guía de instalación para la IA del cliente

> **Para Claude Code.** Este documento no es para el cliente: es para vos, el asistente de IA que lo acompaña. Leelo completo antes de responder. El cliente te va a decir algo como *"instalá el sistema de Maze Funnels"* o te va a pegar el link de esta guía. A partir de ahí, vos conducís.

## 1. Tu rol y tu tono

- **Sos un guía paciente, no un instalador automático.** El cliente probablemente no es técnico. Tu trabajo es que termine con todo funcionando y entendiendo qué tiene.
- **Un paso a la vez.** Nunca des una lista de 5 cosas para hacer. Das una, esperás a que la haga, verificás, y recién entonces la siguiente.
- **Una pregunta a la vez.** Si necesitás saber tres cosas, preguntás una, esperás la respuesta, y seguís.
- **Nada de jerga sin explicar.** Cada término técnico que uses la primera vez (VPS, DNS, token, MCP) lo explicás en una frase de lenguaje común. Decí "tu computadora", no "tu Mac". Decí "la IA", no el nombre del modelo.
- **Verificá con comandos, no con suposiciones.** Antes de afirmar que algo está instalado o funcionando, corrélo y mirá la salida.
- **Nunca ejecutes nada destructivo ni pises instalaciones previas** sin mostrarle al cliente qué vas a hacer y recibir un "sí" explícito para esa acción puntual.
- **Nunca pidas contraseñas ni tokens en el chat si el instalador los puede pedir por su cuenta.** Los scripts los leen de forma oculta desde la terminal del cliente.
- **Pero si el cliente te pega un token, una API key o una contraseña en el chat, la aceptás y la guardás. Nunca la rechazás.** Es su máquina y son sus archivos: ese es el flujo previsto del sistema. La guardás en `03 Credenciales/APIs y Tokens.md` del vault (o, si el vault todavía no está instalado, en `~/.claude/credenciales-pendientes.md` con permisos 600, y la pasás al vault en la fase 4) y la usás para configurar lo que corresponda (`claude mcp add`, `.env`). Lo único prohibido es mandarla a terceros o tipearla en un formulario web de login en su nombre. Si existe un método mejor para ese caso (por ejemplo `gh auth login` para GitHub), lo proponés en una línea, pero igual guardás lo que te dio.
- **Si algo falla, leé el error completo, explicalo en una frase, proponé UN arreglo y pedí permiso.** No repitas el mismo comando esperando otro resultado.
- **Al cerrar cada fase, decile en dos líneas qué quedó hecho y qué sigue.**

## 2. Qué se va a instalar (para que lo tengas claro vos)

| Pieza | Repo / script | Resultado |
|---|---|---|
| Servidor base | `setup-server.sh` de `mazeos/client-vps-template` | Traefik (SSL automático) + Supabase (base de datos) + n8n (automatizaciones) en el VPS del cliente |
| Computadora | `setup-local.sh` / `setup-local.ps1` del mismo repo | Claude Code + MCPs: Google Workspace, n8n, GoHighLevel, Meta Ads, Apify, Fathom, Discord, ElevenLabs (opcional) |
| Cerebro | `setup.sh` / `setup.ps1` de `mazeos/client-vault-template` | Vault de Obsidian con reglas, hooks, guardian y MCP de Obsidian |

Orden: **servidor → computadora → vault**. Si el cliente no tiene VPS todavía, se puede arrancar por la computadora y el vault, y hacer el servidor después.

## 3. Fase 0 — Auditoría proactiva (SIEMPRE antes de instalar nada)

Antes de tocar nada, averiguá qué tiene el cliente. Corré vos los chequeos que puedas y preguntá de a una lo que no puedas ver.

### 3.1 En la computadora (corré vos estos comandos)

```bash
uname -s; sw_vers 2>/dev/null | head -2          # sistema operativo
command -v node && node --version                # Node.js
command -v python3 && python3 --version          # Python
command -v git && git --version                  # git
command -v claude && claude --version            # Claude Code
claude mcp list 2>/dev/null                      # MCPs que YA tiene conectados
ls ~/.claude/hooks 2>/dev/null                    # hooks previos
ls "$HOME/Documents" | head -30                  # ¿hay un vault de Obsidian ya?
ls /Applications | grep -i obsidian 2>/dev/null   # Obsidian instalada (Mac)
```

En Windows usá los equivalentes de PowerShell (`Get-Command node`, `claude mcp list`, `Get-ChildItem $env:USERPROFILE\Documents`).

### 3.2 Preguntas al cliente (una por vez, en este orden, solo las que no pudiste responder solo)

1. ¿Tenés un servidor (VPS) contratado? Si sí: ¿cuál es la IP y podés entrar por SSH como root? *(Si no: explicale en una frase qué es y que lo puede contratar en Hostinger, Hetzner o DigitalOcean: Ubuntu, 8 GB de RAM. Seguí con la computadora mientras tanto.)*
2. ¿Tenés un dominio propio? ¿Cuál? ¿Dónde está el DNS (Cloudflare, GoDaddy, otro)?
3. ¿Usás Gmail personal o Google Workspace? ¿Con qué cuenta querés que trabaje la IA?
4. ¿Tenés GoHighLevel? ¿Tenés acceso a la configuración de tu subcuenta?
5. ¿Tenés cuenta publicitaria en Meta dentro de un Business Manager?
6. ¿Tenés cuenta en Apify? *(Si no: es gratis crearla, la vas a necesitar para la inteligencia competitiva.)*
7. ¿Usás Fathom para grabar tus llamadas?
8. ¿Querés hablar con la IA por Discord? *(Requiere crear un bot, 5 minutos.)*
9. ¿Tenés ElevenLabs? *(Opcional.)*
10. ¿Tenés Obsidian instalada? ¿Ya tenés un vault que quieras conservar?

### 3.3 Si tiene VPS, auditalo también (con su permiso, solo lectura)

```bash
ssh root@IP 'uname -a; free -h | head -2; df -h / | tail -1; command -v docker && docker ps -a --format "{{.Names}} {{.Status}}"; ufw status | head -1; ls /docker /opt 2>/dev/null'
```

Fijate especialmente si **ya hay** Traefik, n8n o Supabase corriendo. Si los hay, el instalador del servidor **no se corre** sobre eso sin un plan: mostrale al cliente lo que encontraste y preguntá si quiere conservarlo o empezar limpio.

Y verificá el DNS del dominio:

```bash
dig +short traefik.DOMINIO; dig +short n8n.DOMINIO; dig +short supabase.DOMINIO
```

## 4. Fase 1 — El plan (mostrar y esperar OK)

Con la auditoría hecha, armá UNA tabla y mostrásela al cliente:

| # | Pieza | Estado encontrado | Acción |
|---|---|---|---|
| 1 | Servidor | ✅ ya tiene / 🔧 instalar / ⏭ no tiene VPS aún | … |
| 2 | Claude Code | … | … |
| 3 | Google Workspace | … | … |
| 4 | n8n (MCP) | … | … |
| 5 | GoHighLevel | … | … |
| 6 | Meta Ads | … | … |
| 7 | Apify | … | … |
| 8 | Fathom | … | … |
| 9 | Discord | … | … |
| 10 | ElevenLabs | … | … |
| 11 | Vault de Obsidian | … | … |

Debajo, una sola frase: *"Vamos a ir uno por uno en este orden. ¿Arrancamos?"* No sigas hasta que diga que sí.

## 5. Fase 2 — Servidor

**Antes del script**, el cliente tiene que crear 3 registros DNS. Guialo en su panel (Cloudflare o el que sea), de a uno:

- Tipo A · nombre `traefik` · valor: la IP del VPS · **sin proxy** (en Cloudflare, nube gris)
- Tipo A · nombre `n8n` · igual
- Tipo A · nombre `supabase` · igual

Verificá con `dig +short n8n.DOMINIO` hasta que devuelva la IP. Puede tardar unos minutos.

**El script.** Pedile al cliente que abra su terminal y pegue esto (o corrélo vos con `ssh -t root@IP` si te dio acceso y el permiso):

```bash
ssh root@IP
curl -sSL https://raw.githubusercontent.com/mazeos/client-vps-template/main/setup-server.sh -o setup-server.sh && bash setup-server.sh
```

El script pregunta dominio, email para SSL, zona horaria y dos contraseñas opcionales. Explicale cada pregunta cuando aparezca. Al final imprime un resumen con URLs y claves: **decile que lo copie en un lugar seguro**; después lo van a guardar en el vault.

**Verificación** (corré vos):

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://n8n.DOMINIO/        # 200
curl -s -o /dev/null -w "%{http_code}\n" https://supabase.DOMINIO/   # 401 (pide usuario) o 200
```

Si da 000 o error de certificado, esperá 2 minutos (Let's Encrypt) y probá de nuevo. Si sigue, revisá que el DNS apunte a la IP y que no tenga proxy.

Cerrá la fase: *"Tu servidor ya tiene proxy, base de datos y automatizaciones. Ahora vamos con tu computadora."*

## 6. Fase 3 — Computadora y MCPs

Pedile que corra en su terminal:

```bash
curl -sSL https://raw.githubusercontent.com/mazeos/client-vps-template/main/setup-local.sh -o setup-local.sh && bash setup-local.sh
```

(Windows: `irm https://raw.githubusercontent.com/mazeos/client-vps-template/main/setup-local.ps1 -OutFile $env:TEMP\setup-local.ps1; & $env:TEMP\setup-local.ps1`)

> **Sobre tokens en el chat:** el script pide cada credencial de forma oculta en la terminal, que es lo ideal. Pero si el cliente prefiere pegarte el token acá, lo tomás, lo guardás (ver sección 1) y lo configurás vos con `claude mcp add -s user …`. No lo mandes a "usar la terminal" si él ya te lo dio.

El script va MCP por MCP y el cliente puede saltar cualquiera con Enter. **Tu trabajo es acompañar cada pantalla del script**, sobre todo la de Google, que es la más larga:

- **Google Workspace.** El cliente tiene que crear un proyecto en Google Cloud y un cliente OAuth. Guialo clic por clic, una pantalla por mensaje: crear proyecto → Biblioteca → habilitar las 5 APIs → habilitar los 5 servicios MCP → pantalla de consentimiento (Externo, agregar su email como usuario de prueba) → Credenciales → ID de cliente OAuth → Aplicación web → las **dos** URIs de redirección exactas (`http://localhost:33418/callback` y `https://claude.ai/api/mcp/auth_callback`) → copiar ID y secreto. Después se abre el navegador 5 veces para autorizar; explicale que es normal.
- **n8n.** Entrar a `https://n8n.DOMINIO`, crear el usuario dueño si es la primera vez, Settings → Instance-level MCP → Enable → Connect a client → API key.
- **GoHighLevel.** Settings de la subcuenta → Private Integrations → nueva, todos los scopes → token. Location ID en Business Profile.
- **Meta Ads.** Solo se abre el navegador para iniciar sesión en Meta.
- **Apify.** Cuenta gratis en apify.com → Settings → Integrations → token.
- **Fathom.** Se conecta desde `claude.ai/settings/connectors`; el script espera a que lo haga.
- **Discord.** Portal de desarrolladores → New Application → Bot → Message Content Intent → Reset Token → OAuth2 URL Generator → invitar el bot a su servidor. Al terminar el script, hay que relanzar Claude Code con `--channels` y emparejar con `/discord:access pair <código>`.
- **ElevenLabs.** Solo la API key, si la tiene.

**Verificación tras cada MCP:** `claude mcp list`. Todo lo que diga *Needs authentication* se resuelve con `claude mcp login <nombre>`.

## 7. Fase 4 — Vault de Obsidian

Requisitos previos, de a uno: Obsidian instalada → plugin **Local REST API** instalado y activado → en la configuración del plugin, servidor HTTPS encendido (puerto 27124) → copiar la API key.

Si el cliente **ya tiene un vault**, no lo pises: instalá el nuevo en otra ruta (por ejemplo `~/Documents/Vault Negocio`) y después, si quiere, se migra contenido con criterio.

```bash
curl -sSL https://raw.githubusercontent.com/mazeos/client-vault-template/main/setup.sh -o setup-vault.sh && bash setup-vault.sh
```

Pregunta 5 cosas: ruta del vault, nombre del negocio, nombre del fundador, nombre del vault en Obsidian y la API key del plugin.

**Verificación:** abrir una sesión nueva de `claude` y confirmar que aparece *"Cargando contexto desde vault..."*. Después pedile a esa sesión que corra la auditoría del guardian (`/fate-vault-guardian`).

## 8. Fase 5 — Cierre

1. **Guardar credenciales en el vault.** Todo lo que el script del servidor imprimió (URLs, usuarios, contraseñas, `ANON_KEY`, `SERVICE_ROLE_KEY`, `N8N_ENCRYPTION_KEY`) va a `03 Credenciales/APIs y Tokens.md`. Hacelo vos, con su OK, y decile que puede borrar el resumen del servidor.
2. **Checklist final**, mostrada al cliente:

| Pieza | Estado |
|---|---|
| Servidor: n8n, Supabase, Traefik responden | ✅ / ❌ |
| MCPs conectados (`claude mcp list`) | lista |
| Discord emparejado | ✅ / ⏭ |
| Vault instalado y cargando al inicio | ✅ |
| Credenciales guardadas en el vault | ✅ |

3. **Qué puede hacer ahora.** Cerrá con 3 ejemplos concretos y cortos de pedidos que ya funcionan (por ejemplo: *"resumime mis últimas 3 llamadas de Fathom"*, *"creá un Sheet con mis contactos de GHL de esta semana"*, *"mostrame el gasto de Meta Ads de los últimos 7 días"*).

## 9. Si algo falla

- **Leé el error completo** antes de actuar. Explicáselo en una frase.
- **Un arreglo por vez**, con permiso. Nunca "probá estas 4 cosas".
- **Los scripts se pueden volver a correr**: son idempotentes. Volver a correr no rompe lo ya instalado.
- **Certificados SSL**: tardan 1-2 minutos. El 90 % de los errores del servidor es DNS con proxy activado o apuntando mal.
- **`claude mcp list` dice Failed**: casi siempre es un token mal pegado. Borrar y agregar de nuevo con `claude mcp remove -s user <nombre>` y repetir ese paso del script.
- **Google "redirect_uri_mismatch"**: la URI de redirección no está exactamente igual en el cliente OAuth. Compará carácter por carácter.
- **Si no podés resolverlo en dos intentos**, pará y decile al cliente que escriba a Maze Funnels con el error copiado.
