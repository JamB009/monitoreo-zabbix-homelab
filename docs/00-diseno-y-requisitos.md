# Fase 0: Diseño, requisitos y plan de red

> **Fecha:** 2026-11-02 · **Estado:** 🟡 en curso

## 1. Objetivo

Decidir **qué se monitorea, desde dónde y cómo se comunican las piezas** antes de instalar nada. En monitoreo, el error más común es no pensar en la red: el servidor tiene que alcanzar (o ser alcanzado por) los agentes.

## 2. Conceptos clave

- **Servidor Zabbix:** recibe datos, evalúa *triggers* y envía alertas.
- **Agente (Agent 2):** programa en cada equipo que recoge métricas.
  - **Pasivo:** el servidor consulta al agente (puerto 10050 en el agente).
  - **Activo:** el agente envía los datos al servidor (puerto 10051 en el servidor). Es más cómodo cuando el servidor no puede iniciar conexiones hacia el agente.
- **Host / Item / Trigger / Template:** un *host* es lo monitoreado; un *item* es una métrica; un *trigger* es una condición de problema; una *plantilla* agrupa items y triggers reutilizables.
- **Acción:** qué hacer cuando un trigger se activa (por ejemplo, enviar un mensaje a Telegram).

## 3. Versión de Zabbix a usar

| Opción | Recomendación |
|---|---|
| **Zabbix 7.0 LTS** | **Usar esta.** Versión LTS estable, con soporte completo hasta junio de 2027 y limitado hasta junio de 2029. |
| Zabbix 8.0 LTS | Planificada para el cuarto trimestre de 2026. Si al comenzar ya está publicada como estable, es válida, pero algunas rutas y comandos cambian (por ejemplo, la ubicación de los scripts SQL). Antes de instalar, revisa la página oficial de descargas y la política de ciclo de vida. |

Regla del proyecto: **documenta la versión exacta** (`zabbix_server -V`) en el README y en cada captura relevante.

## 4. Requisitos

### Servidor de monitoreo

| Recurso | Mínimo de laboratorio | Recomendado |
|---|---|---|
| CPU | 2 núcleos | 2 a 4 núcleos |
| RAM | 4 GB | 8 GB |
| Disco | 30 GB | 60 GB (el histórico crece con el tiempo) |
| SO | Ubuntu Server 22.04 o 24.04 LTS | 24.04 LTS |

Un laptop antiguo con Ubuntu Server sirve para un laboratorio pequeño (pocos hosts, intervalos razonables). Para cuidar recursos: no habilites plantillas que no uses, usa intervalos de 1 a 5 minutos, y revisa la cola de Zabbix (*Administration → Queue*).

### Cuentas externas (gratuitas)

- **Telegram:** cuenta personal para crear un bot con `@BotFather`.
- **Correo:** una cuenta con SMTP (por ejemplo Gmail con verificación en dos pasos y una *contraseña de aplicación*).

## 5. Decisión clave: dónde vive el servidor y cómo llegan los agentes

Tu laboratorio de AD está en máquinas virtuales (red interna). Tu servidor Ubuntu es otro equipo (el laptop). Hay que elegir una topología:

| Opción | Descripción | Ventajas | Desventajas |
|---|---|---|---|
| **A. Servidor en el laptop Ubuntu (recomendada)** | Las VMs de Windows reciben una **segunda tarjeta de red en modo puente (bridged)** hacia tu red doméstica; el laptop está en esa misma red. | No gasta RAM del equipo donde corren las VMs; se parece a un entorno real (servidor de monitoreo separado). | El modo puente por Wi-Fi puede dar problemas en algunos hipervisores; usar cable si es posible. |
| **B. Servidor como VM en el mismo hipervisor** | Una VM `ZBX-SRV` en la red interna del laboratorio. | Todo queda aislado y simple. | Consume RAM; con AD-2 ya lento puede empeorar. |

> **Esta guía describe la opción A.** Si usas la B, solo cambia el direccionamiento (ZBX-SRV en `192.168.10.0/24`).

### Cómo verificar que la opción A es viable (antes de seguir)

1. En el hipervisor, agrega a AD-1, AD-2 y CLIENTE-01 un **segundo adaptador** en modo puente.
2. Dale IP en tu red doméstica (ejemplo: `192.168.1.0/24`).
3. Desde el laptop: `ping <IP_de_AD-1>`; desde AD-1: `ping <IP_del_laptop>`.
4. Si no responde, revisa el firewall de Windows (ICMP) y el modo del adaptador.

## 6. Plan de direccionamiento

| Equipo | Rol | IP de monitoreo | Agente |
|---|---|---|---|
| `zbx-srv` | Zabbix server (Ubuntu, laptop físico) | 192.168.1.20 (reserva DHCP en el router ✅) | Agent 2 local |
| `AD-1` | DC + DNS | 192.168.1.201 | Agent 2 (activo) |
| `AD-2` | DC + DNS | 192.168.1.202 | Agent 2 (activo) |
| `CLIENTE-01` | Estación | 192.168.1.203 | Agent 2 (activo) |

> **Rango DHCP del router (cambiado el 2026-11-02):** antes repartía `.2–.254`; ahora `.2–.199`. El bloque **`.200–.254` queda para IPs fijas del laboratorio** (fuera del pool, sin riesgo de conflicto). `zbx-srv` (.20) y el PC (.10) usan reserva DHCP; los Windows usan IP fija configurada en cada VM. Lista de clientes DHCP revisada: ninguno en .200 o más.

### Entorno real (relevado el 2026-11-02)

Topología elegida: **A** (servidor en laptop físico; VMs en el PC principal con bridge hacia la LAN).

| Equipo | Detalle |
|---|---|
| Router | 192.168.1.1, red 192.168.1.0/24 |
| `zbx-srv` (laptop) | Ubuntu Server 26.04.1 LTS, kernel 7.0.0-38, 4 núcleos, 3,3 GB RAM + 3,8 GB swap, disco 458 GB. Cable `enp9s0`, MAC `78:84:3c:af:22:77`, **192.168.1.20** por reserva DHCP. Wi-Fi apagada |
| PC principal | CachyOS, 16 hilos, ~15 GB RAM, cable `enp6s0`, MAC `04:42:1a:09:e6:d0`, **192.168.1.10** por reserva DHCP. QEMU/KVM + libvirt para las VMs de Windows |
| AD-1 / AD-2 / CLIENTE-01 | Pendientes de crear (bridge `br0` en el PC) |

Servicios que ya existían en el laptop: nginx (sitio `mi-sitio.conf` en el puerto 80), Glances web, servidor NFS, Docker (sin contenedores), Tailscale, chrony.

**Limpieza (2026-11-02).** Se revisó cada servicio antes de decidir:

| Servicio | Qué era | Decisión |
|---|---|---|
| `mi-sitio.conf` (nginx :80) | Ejercicio anterior: la raíz daba 403 (sin `index.html`) y `/status/` hacía de proxy a Glances | Desactivado (se borró solo el enlace de `sites-enabled`). nginx sigue instalado para Zabbix, que usará el **puerto 80** |
| Glances web (:61208) | Monitor de recursos; lo reemplaza Zabbix | `systemctl disable --now glances` |
| Servidor NFS | Exportaba `/srv/almacenamiento` a `*` con `rw,no_root_squash` (riesgo: cualquier equipo de la LAN podía escribir como root) y `/srv/nfs/repositorio_ti`. Sin clientes conectados | `systemctl disable --now nfs-server`. Los datos siguen en `/srv` |
| Docker | Sin imágenes; quedan volúmenes `n8n_automatizacion_n8n_data`, `owncloud_ocis-config`, `owncloud_ocis-data` | `disable --now docker docker.socket containerd`. **Volúmenes conservados** en `/var/lib/docker/volumes/` |
| Tailscale | VPN de acceso remoto | Se mantiene |

RAM usada: 626 MiB → 584 MiB (2,7 GiB disponibles). Reactivar algo: `sudo systemctl enable --now <servicio>`.

La RAM (3,3 GB) está por debajo del mínimo recomendado (4 GB): se compensa ajustando PostgreSQL y usando pocas plantillas.

### Problemas encontrados

- El router no permitió reservar la IP actual del laptop (.19) porque estaba prestada por DHCP → se reservó la .50 y se reinició el laptop. Ver [T-002](../TROUBLESHOOTING.md#t-002-el-router-no-deja-reservar-la-ip-actual).
- `'xterm-kitty': unknown terminal type` al usar `clear` por SSH → ver [T-003](../TROUBLESHOOTING.md#t-003-xterm-kitty-unknown-terminal-type-por-ssh).

### Puertos a abrir

| Origen → Destino | Puerto | Para qué |
|---|---|---|
| Agentes → `zbx-srv` | 10051/tcp | Envío de datos de agentes activos |
| `zbx-srv` → agentes | 10050/tcp | Solo si usas agente pasivo |
| Tu PC → `zbx-srv` | 443/tcp (o 80/8080 al inicio) | Interfaz web |
| Tu PC → `zbx-srv` | 22/tcp | SSH |
| `zbx-srv` → internet | 443/tcp, 587/tcp | API de Telegram y SMTP |

## 7. Qué se va a monitorear (inventario)

| Capa | Qué | Cómo |
|---|---|---|
| Disponibilidad | ¿El equipo responde? | ICMP y `agent.ping` |
| Recursos | CPU, memoria, disco, red | Plantillas de Zabbix |
| Servicios de AD | NTDS, DNS, Netlogon, KDC, DFSR, W32Time | `service.info[...]` |
| Salud de AD | Fallos de replicación, hora, LDAP/DNS | Script + UserParameter |
| Seguridad | Fallos de inicio de sesión, bloqueos, logs borrados | Eventos de Windows y `auth.log` |
| Plataforma | Salud del propio Zabbix | Plantilla *Zabbix server health* |

## 8. Política de severidades (se usará en la fase 5)

| Severidad | Cuándo | Cómo se notifica |
|---|---|---|
| Information | Cambios no críticos | Solo panel |
| Warning | Tendencia preocupante (disco 80 %) | Panel |
| Average | Degradación (servicio no esencial caído) | Telegram |
| High | Servicio crítico caído (DNS/AD en un DC) | Telegram + correo |
| Disaster | Pérdida de ambos DC o del servidor | Telegram + correo, repetido |

## 9. Convenciones

- Nombres de host en Zabbix **idénticos** al `Hostname` del agente.
- Grupos de hosts: `Lab/Windows-AD`, `Lab/Windows-Clientes`, `Lab/Linux`.
- Etiquetas (tags) en triggers: `servicio:ad`, `servicio:dns`, `capa:seguridad`.
- Plantillas propias con prefijo `Lab - `.
- Secretos en un gestor de contraseñas; **nunca** en el repositorio.

## 10. Checklist previo

- [x] Servidor (laptop) con Ubuntu Server accesible por SSH
- [ ] Topología elegida (A o B) y conectividad probada con `ping`
- [ ] IPs definidas y reservadas (zbx-srv ✅ .20, PC ✅ .10; VMs .201–.203 fijas al crearlas)
- [x] Bot de Telegram creado (token guardado en el gestor, `chat_id` obtenido con `@userinfobot`; la prueba de envío queda para la fase 5)
- [ ] Repositorio de GitHub creado ([guía](../GUIA-GITHUB.md))
- [ ] Diagrama de red en `assets/diagramas/`

## 11. Lo que aprendí

- Una reserva DHCP asocia una IP a la MAC del equipo en el router: el servidor mantiene la IP sin configurarla fija en el propio Ubuntu.
- Algunos routers no dejan reservar una IP que ya está prestada; hay que elegir otra libre y renovar (reiniciar) el equipo.
- La IPv6 SLAAC (EUI-64) contiene la MAC: `fe80::7a84:3cff:feaf:2277` → `78:84:3c:af:22:77`.
- Antes de instalar, revisar qué servicios y puertos ya hay (`ss -tlnp`): encontré nginx ocupando el puerto 80.
- Desactivar un sitio de nginx = borrar el enlace en `sites-enabled`; la config queda en `sites-available`. Sin sitios activos, nginx corre pero no escucha en ningún puerto.
- `systemctl disable --now` para y quita el arranque automático en un paso. Con Docker también hay que desactivar `docker.socket`, o el servicio se vuelve a levantar a la primera petición.
- Revisar `/etc/exports`: `*` + `no_root_squash` comparte la carpeta con toda la red y con privilegios de root.
- En la terminal se pega con **Ctrl+Shift+V**, no con Ctrl+V; `echo ${#VAR}` muestra la longitud de un secreto sin revelarlo.
- El `chat_id` de un chat privado con un bot es tu propio id de usuario (`@userinfobot`).
- _(completar)_

## 12. Siguiente paso

[Fase 1: Preparar el Ubuntu Server](01-preparar-ubuntu-server.md)
