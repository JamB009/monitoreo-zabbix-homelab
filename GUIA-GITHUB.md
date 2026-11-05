# Guía de GitHub para este proyecto

## 1. Crear y conectar el repositorio

1. En GitHub: **New repository** → nombre sugerido `monitoreo-zabbix-homelab` → público → sin README (ya existe).
2. En tu máquina, dentro de la carpeta del proyecto:

```bash
git init
git branch -M main
git add .
git commit -m "docs: estructura inicial del proyecto de monitoreo con Zabbix"
git remote add origin https://github.com/TU_USUARIO/monitoreo-zabbix-homelab.git
git push -u origin main
```

3. **Topics** sugeridos: `zabbix`, `monitoring`, `homelab`, `sysadmin`, `ubuntu-server`, `active-directory`, `telegram-bot`, `postgresql`, `nginx`, `powershell`.
4. Descripción: "Monitoreo de un homelab con Zabbix 7.0 LTS: Windows/AD y Linux, alertas por Telegram y correo, logs, dashboards y simulacros de incidentes."

## 2. Flujo de trabajo por fase

```bash
git checkout -b fase-3-agentes
# trabajar y documentar la fase
git add docs/03-agentes-linux-y-windows.md assets/fase3/ config/
git commit -m "docs(fase-3): agentes en Linux y Windows con plantillas"
git checkout main
git merge fase-3-agentes
git tag fase-3
git push origin main --tags
```

## 3. Convención de commits

| Prefijo | Uso |
|---|---|
| `docs:` | Documentación nueva o corregida |
| `feat:` | Script o configuración nueva |
| `fix:` | Corrección de un script o paso |
| `chore:` | Orden, renombrados, `.gitignore` |

## 4. Qué NO subir (muy importante en un proyecto de monitoreo)

- ❌ **Token del bot de Telegram** y chat ID reales
- ❌ **Contraseñas** de la base de datos, de Zabbix, del correo SMTP o de la app de Gmail
- ❌ **Claves PSK** (`*.psk`), certificados privados (`*.key`, `*.pem`)
- ❌ Dumps de la base de datos (`*.dump`, `*.sql.gz`): contienen configuración y hosts
- ❌ Capturas con IPs públicas, tu correo personal o tokens visibles en la URL/campos
- ✅ Valores de ejemplo como `<TOKEN_DEL_BOT>`, `<PASSWORD_DB>`, `192.168.x.x` de laboratorio

Si alguna vez subes un secreto por error: **revócalo inmediatamente** (en Telegram con BotFather → `/revoke`; cambia contraseñas). Borrar el commit no basta, porque queda en el historial.

Activa en el repositorio: **Settings → Code security → Secret scanning**.

## 5. Capturas

Convención: `assets/faseN/NN-descripcion-corta.png`. Recorta a lo relevante y oculta campos sensibles (token, correo, IP pública). Se recomienda también guardar en `assets/` un export en YAML de las plantillas y trigger propios (ver fase 8): se puede versionar sin secretos.

## 6. Presentación del perfil

- Fija este repositorio en tu perfil de GitHub.
- Enlázalo en LinkedIn (sección **Destacados**) y en el CV.
- Al terminar, publica un **Release v1.0** con el resumen y las lecciones aprendidas.
