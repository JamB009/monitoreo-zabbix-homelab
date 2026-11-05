# Roadmap

Actualizar al terminar cada fase (y marcar el tag de Git y el post de LinkedIn).

Leyenda: ✅ terminado · 🟡 en curso · ⬜ pendiente

| Fase | Entregable | Estado | Tag Git | Publicación LinkedIn |
|---|---|---|---|---|
| 0 | Diseño, requisitos y plan de red | 🟡 | `fase-0` | Post 1 |
| 1 | Ubuntu Server base (IP fija, hora, firewall, SSH) | ⬜ | `fase-1` | (se une al post 2) |
| 2 | Zabbix server funcionando (web, DB, agente local) | ⬜ | `fase-2` | Post 2 |
| 3 | Agentes en Windows y Linux, hosts y plantillas | ⬜ | `fase-3` | Post 3 |
| 4 | Monitoreo de AD: replicación, servicios, contadores | ⬜ | `fase-4` | Post 4 |
| 5 | Triggers, dependencias y alertas Telegram/correo | ⬜ | `fase-5` | Post 5 |
| 6 | Logs y eventos de seguridad (4625, 4740, auth.log) | ⬜ | `fase-6` | Post 6 |
| 7 | Dashboards, mapa y SLA | ⬜ | `fase-7` | Post 7 |
| 8 | Seguridad (HTTPS, PSK, roles) y respaldo | ⬜ | `fase-8` | Post 8 |
| 9 | Simulacro de incidentes y métricas de detección | ⬜ | `fase-9` | Post 9 y cierre (Post 10) |
| 10 | Grafana (opcional) | ⬜ | `fase-10` | Extra |

## Ideas para una versión 2

- Monitoreo por SNMP del router o de un switch
- Monitoreo de contenedores Docker
- Verificación web (HTTP) de un sitio propio con alerta de caída y de certificado por vencer
- Autodescubrimiento y autorregistro de agentes
- Proxy de Zabbix para una segunda red
- Integración de alertas con un canal de equipo (Slack/Teams) en lugar de Telegram

## Registro de cambios

| Fecha | Cambio |
|---|---|
| _AAAA-MM-DD_ | Creación del repositorio |
