# Fase 4: Monitoreo específico de Active Directory

> **Fecha:** _AAAA-MM-DD_ · **Estado:** ⬜

## 1. Objetivo

Ir más allá de CPU y disco: vigilar lo que hace que un dominio funcione (servicios de AD, replicación, hora, LDAP y DNS) con una **plantilla propia** reutilizable en ambos Domain Controllers.

## 2. Conceptos clave

- **Plantilla propia:** agrupa los items y triggers del rol "Domain Controller". Si mañana hay un tercer DC, basta enlazar la plantilla.
- **Plantillas anidadas:** la plantilla propia enlaza `Windows by Zabbix agent active` e `ICMP Ping`, de modo que un solo enlace por host trae todo. Además permite crear **dependencias** entre triggers (fase 5).
- **UserParameter:** permite al agente ejecutar un script propio y devolver un valor como item.
- **Contadores de rendimiento (`perf_counter_en`):** métricas de Windows específicas de AD, DNS y DHCP, leídas por nombre en inglés.
- **`fuzzytime`:** función de Zabbix que compara la hora del equipo con la del servidor. Sirve para detectar desfases que romperían Kerberos (tolerancia de 5 minutos).

## 3. Requisitos previos

- [ ] Fase 3 completada: AD-1 y AD-2 reportando
- [ ] Módulo `ActiveDirectory` en los DC (viene con la herramienta de administración de AD DS)

## 4. Procedimiento

### 4.1 Crear la plantilla `Lab - AD Domain Controller`

**Data collection → Templates → Create template:**
- Nombre: `Lab - AD Domain Controller`
- Grupo de plantillas: `Templates/Lab` (créalo si no existe)
- **Templates** (enlazar): `Windows by Zabbix agent active` y `ICMP Ping`
- Descripción: "Servicios, replicación, hora y chequeos de red para un DC de lab.local"

### 4.2 Servicios críticos de AD (items)

Dentro de la plantilla → **Items → Create item**. Tipo: **Zabbix agent (active)**; tipo de información: *Numeric (unsigned)*; intervalo: `1m`; historial: `14d`; tendencias: `365d`; valor mapeado: *Windows service state* (si existe en tu instalación).

| Nombre | Clave |
|---|---|
| Servicio AD DS (NTDS) | `service.info[NTDS,state]` |
| Servicio DNS Server | `service.info[DNS,state]` |
| Servicio Netlogon | `service.info[Netlogon,state]` |
| Servicio Kerberos KDC | `service.info[Kdc,state]` |
| Servicio replicación DFSR | `service.info[DFSR,state]` |
| Servicio hora (W32Time) | `service.info[W32Time,state]` |
| Servicio DHCP Server _(si lo instalaste)_ | `service.info[DHCPServer,state]` |

Códigos de estado: `0` en ejecución, `1` pausado, `2..5` transiciones, `6` **detenido**, `7` desconocido, `255` el servicio no existe.

Comprueba cada clave antes de crear el item (en el DC):

```powershell
Get-Service NTDS,DNS,Netlogon,Kdc,DFSR,W32Time | Format-Table Name,Status
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" -c "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf" -t "service.info[NTDS,state]"
```

### 4.3 Fallos de replicación (script + UserParameter)

1. Copia [`scripts/windows/Get-ADReplFailures.ps1`](../scripts/windows/Get-ADReplFailures.ps1) a `C:\Program Files\Zabbix Agent 2\scripts\` en **AD-1 y AD-2**.
2. Agrega al final de `zabbix_agent2.conf` el contenido de [`config/zabbix_agent2-ad.conf.snippet`](../config/zabbix_agent2-ad.conf.snippet).
3. Reinicia el agente y prueba:

```powershell
Restart-Service "Zabbix Agent 2"
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" -c "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf" -t ad.repl.failures
```

Resultado esperado: `[s|0]` (cero fallos). Si devuelve `-1`, revisa que el módulo `ActiveDirectory` exista y que el script corra a mano.

4. En la plantilla crea el item:

| Campo | Valor |
|---|---|
| Nombre | Fallos de replicación de AD |
| Tipo | Zabbix agent (active) |
| Clave | `ad.repl.failures` |
| Tipo de información | Numeric (integer) (permite negativos) |
| Intervalo | `5m` |
| Historial | `30d` |

> **Por qué cada 5 minutos:** PowerShell cuesta recursos y los problemas de replicación no cambian en segundos. Si el script tarda más que `Timeout`, el item queda *no soportado*: sube `Timeout` (máx. 30 s).

### 4.4 Hora del equipo (Kerberos)

Item en la plantilla:

| Campo | Valor |
|---|---|
| Nombre | Hora local del equipo |
| Tipo | Zabbix agent (active) |
| Clave | `system.localtime` |
| Tipo de información | Numeric (unsigned) |
| Intervalo | `1m` |
| Historial | `7d` |

En la fase 5 se compara con la hora del servidor mediante `fuzzytime`.

### 4.5 Contadores de rendimiento de AD y DNS

Primero, **descubre qué contadores existen** en tu DC:

```powershell
typeperf -q NTDS | Select-Object -First 20
typeperf -q DNS | Select-Object -First 20
```

Crea items **Zabbix agent (active)**, tipo *Numeric (float)*, intervalo `1m`, historial `14d`. Ejemplos (valida que cada nombre aparezca en la salida de `typeperf`):

| Nombre | Clave |
|---|---|
| LDAP: búsquedas/seg | `perf_counter_en["\NTDS\LDAP Searches/sec"]` |
| LDAP: sesiones de cliente | `perf_counter_en["\NTDS\LDAP Client Sessions"]` |
| Replicación: sincronizaciones pendientes | `perf_counter_en["\NTDS\DRA Pending Replication Synchronizations"]` |
| DNS: consultas recibidas/seg | `perf_counter_en["\DNS\Total Query Received/sec"]` |

Prueba:

```powershell
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" -c "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf" -t 'perf_counter_en["\NTDS\LDAP Searches/sec"]'
```

### 4.6 Chequeos de red desde el servidor (LDAP y DNS)

Items de tipo **Simple check** (los ejecuta Zabbix server hacia el DC; usa la IP de la interfaz del host):

| Nombre | Clave | Tipo de información |
|---|---|---|
| Puerto LDAP (389) responde | `net.tcp.service[ldap,,389]` | Numeric (unsigned) |
| Puerto DNS (53/TCP) responde | `net.tcp.service[tcp,,53]` | Numeric (unsigned) |

Resultado: `1` = responde, `0` = no responde. Intervalo: `1m`.

### 4.7 Enlazar la plantilla a los DC

En **AD-1** y **AD-2** (*Hosts → editar → Templates*):
1. **Quita** `Windows by Zabbix agent active` e `ICMP Ping` enlazadas directamente (ya vienen anidadas dentro de la plantilla propia).
2. **Agrega** `Lab - AD Domain Controller`.

Confirma en *Monitoring → Latest data* que aparecen los items nuevos y que no hay duplicados.

### 4.8 Plantilla para el cliente

Para `CLIENTE-01` deja `Windows by Zabbix agent active` + `ICMP Ping` (no es un DC). Opcional: crea `Lab - Windows Client` con la misma lógica de anidamiento.

### 4.9 Exportar la plantilla para versionarla

**Data collection → Templates → seleccionar `Lab - AD Domain Controller` → Export** (YAML). Guarda el archivo en `assets/exports/lab-ad-domain-controller.yaml`. Revísalo antes de subirlo: no debe contener secretos.

## 5. Verificación

| Prueba | Comando / acción | Resultado esperado |
|---|---|---|
| Servicios detectados | *Latest data* de AD-1 | 6 o 7 items de servicio con valor `0` |
| Replicación | Item `ad.repl.failures` | `0` |
| Hora | Item `system.localtime` | Valor reciente y creciente |
| LDAP/DNS | Items simples | `1` |
| Contadores | LDAP Searches/sec | Valores numéricos |
| Plantilla exportada | Archivo en `assets/exports/` | Presente, sin secretos |

Captura: `assets/fase4/01-latest-data-ad1.png`. Snapshot: `fase-4-zabbix-ad`.

## 6. Problemas encontrados

| Síntoma | Causa | Solución |
|---|---|---|
| `ad.repl.failures` → *Not supported* / timeout | PowerShell lento al arrancar | `Timeout=30` y subir intervalo |
| Devuelve `-1` | Falta el módulo AD o excepción | Ejecutar el script a mano para ver el error |
| Contador *Not supported* | Nombre no existe en tu SO | Comprobar con `typeperf -q <objeto>` |
| `service.info[...]` devuelve `255` | Nombre de servicio incorrecto | Usar el nombre corto (`Get-Service`, columna Name) |
| Items simples en `0` | Firewall de Windows bloquea desde el servidor | Permitir 389 y 53 desde la IP de `zbx-srv` |

## 7. Lo que aprendí

- _(completar)_

## 8. Siguiente paso

[Fase 5: Triggers y alertas](05-triggers-y-alertas.md)
