# Monitoreo y alertas de un homelab con Zabbix

Sistema de monitoreo para un laboratorio de infraestructura: servidor **Zabbix 7.0 LTS** sobre Ubuntu Server, agentes en Windows Server (Active Directory) y Linux, alertas por **Telegram y correo**, monitoreo de logs y eventos de seguridad, paneles y simulacros de incidentes con tiempos medidos.

> **Objetivo:** demostrar con evidencia que sé instalar, configurar y operar una plataforma de monitoreo: detectar fallas antes que el usuario, reducir ruido de alertas y dejar procedimientos (runbooks) para responder.

**Autor:** _tu nombre_ · Técnico en Electrónica y Electricidad Industrial · En transición a IT (Soporte / SysAdmin)
**LinkedIn:** _tu enlace_
**Estado:** 🟡 En progreso (ver [ROADMAP](ROADMAP.md))

---

## Arquitectura

```
  Tu PC (navegador)
        │ HTTPS 443
        ▼
 ┌───────────────────────────┐   Telegram API / SMTP (salida a internet)
 │  ZBX-SRV  (Ubuntu Server) │ ─────────────────────────────────────────►  📱 Telegram / 📧 correo
 │  Zabbix Server 7.0 LTS    │
 │  PostgreSQL · Nginx · PHP │
 └─────────────▲─────────────┘
               │ 10051/tcp  (agentes activos envían datos)
   ┌───────────┼───────────────────┬────────────────────┐
┌──┴───┐   ┌───┴───┐          ┌────┴──────┐        ┌────┴─────┐
│ AD-1 │   │ AD-2  │          │ CLIENTE-01│        │ ZBX-SRV  │
│ Win  │   │ Win   │          │ Windows   │        │ (se vigila│
│Agent2│   │Agent2 │          │ Agent 2   │        │ a sí mismo)
└──────┘   └───────┘          └───────────┘        └──────────┘
```

> Dibuja tu diagrama real (draw.io) y guárdalo en `assets/diagramas/`. La conectividad entre el servidor y las VMs depende de tu red; ver [Fase 0](docs/00-diseno-y-requisitos.md).

## Stack

| Componente | Detalle |
|---|---|
| Servidor de monitoreo | Ubuntu Server 24.04 LTS (o la versión que tengas; ver Fase 0) |
| Zabbix | 7.0 LTS: server, frontend web, Agent 2 |
| Base de datos | PostgreSQL |
| Servidor web | Nginx + PHP-FPM |
| Objetivos | AD-1, AD-2 (Windows Server), CLIENTE-01 (Windows), el propio servidor Ubuntu |
| Alertas | Telegram (bot) y correo SMTP |
| Opcional | Grafana con el plugin de Zabbix |

## Contenido

| Fase | Documento | Estado |
|---|---|---|
| 0 | [Diseño, requisitos y plan de red](docs/00-diseno-y-requisitos.md) | 🟡 |
| 1 | [Preparar el Ubuntu Server](docs/01-preparar-ubuntu-server.md) | ⬜ |
| 2 | [Instalar Zabbix server](docs/02-instalar-zabbix.md) | ⬜ |
| 3 | [Agentes en Linux y Windows](docs/03-agentes-linux-y-windows.md) | ⬜ |
| 4 | [Monitoreo específico de Active Directory](docs/04-monitoreo-active-directory.md) | ⬜ |
| 5 | [Triggers y alertas (Telegram y correo)](docs/05-triggers-y-alertas.md) | ⬜ |
| 6 | [Logs y eventos de seguridad](docs/06-logs-y-eventos.md) | ⬜ |
| 7 | [Dashboards, mapas y SLA](docs/07-dashboards-y-sla.md) | ⬜ |
| 8 | [Seguridad y respaldo de Zabbix](docs/08-seguridad-y-respaldo.md) | ⬜ |
| 9 | [Simulacro de incidentes y métricas](docs/09-simulacro-de-incidentes.md) | ⬜ |
| 10 | [Opcional: Grafana](docs/10-grafana-opcional.md) | ⬜ |

Scripts en [`scripts/`](scripts/) · Configuraciones en [`config/`](config/) · Procedimientos de respuesta en [`runbooks/`](runbooks/) · Capturas en [`assets/`](assets/) · Problemas resueltos en [TROUBLESHOOTING](TROUBLESHOOTING.md) · Plantilla en [`docs/_plantilla.md`](docs/_plantilla.md)

Material de apoyo: [Guía de GitHub](GUIA-GITHUB.md)

## Qué demuestra este proyecto

- Instalación y puesta a punto de Zabbix (PostgreSQL, Nginx, agentes)
- Monitoreo de infraestructura Windows/AD y Linux con plantillas y chequeos propios
- Diseño de alertas con severidades, dependencias y sin ruido innecesario
- Notificaciones por Telegram y correo
- Detección de eventos de seguridad (intentos fallidos de acceso, bloqueos)
- Dashboards y SLA para mostrar el estado del servicio
- Seguridad y respaldo de la propia plataforma de monitoreo
- Medición del tiempo de detección en incidentes simulados
- Documentación operativa (runbooks)

## Cómo reproducirlo

Requisitos y decisiones de red en [docs/00-diseno-y-requisitos.md](docs/00-diseno-y-requisitos.md). Sigue las fases en orden: cada una termina con una verificación antes de pasar a la siguiente.

## Licencia

MIT. Uso educativo. Los tokens, claves y contraseñas **nunca** se suben al repositorio; todos los valores sensibles en los documentos son marcadores de posición.
