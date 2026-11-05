# Fase 3: Agentes en Linux y Windows

> **Fecha:** _AAAA-MM-DD_ · **Estado:** ⬜

## 1. Objetivo

Instalar Zabbix Agent 2 en AD-1, AD-2 y CLIENTE-01, registrarlos como hosts con las plantillas correctas y confirmar que llegan métricas.

## 2. Conceptos clave

- **Agente activo:** el agente consulta al servidor qué métricas debe recoger y envía los resultados al puerto 10051. Funciona aunque el servidor no pueda iniciar la conexión.
- **Hostname:** en el modo activo, el servidor identifica al agente por el `Hostname` del archivo de configuración. Debe ser **idéntico** al nombre del host en la interfaz.
- **Plantillas:** `Windows by Zabbix agent active` (agente activo) y `Linux by Zabbix agent`. Si usas agente activo en Windows, usa la plantilla *active*.
- **Versión del agente:** usa la misma serie (7.0) que el servidor.

## 3. Requisitos previos

- [ ] Fase 2 completada
- [ ] Conectividad servidor ↔ VMs verificada ([fase 0](00-diseno-y-requisitos.md#cómo-verificar-que-la-opción-a-es-viable-antes-de-seguir))
- [ ] Reglas de UFW para 10051 desde cada agente

## 4. Procedimiento

### 4.1 Descargar el agente para Windows

1. Entra a la sección de descargas de agentes en `zabbix.com` y elige: **Zabbix Agent 2**, versión **7.0 LTS**, Windows, `amd64`, **MSI**, con **OpenSSL** (permite cifrado PSK).
2. Verifica el hash SHA-256 publicado antes de instalar:

```powershell
Get-FileHash .\zabbix_agent2-7.0.*-windows-amd64-openssl.msi -Algorithm SHA256
```

3. Copia el MSI a las VMs (carpeta compartida o descarga directa en cada una).

### 4.2 Instalar en AD-1 (PowerShell como administrador)

```powershell
$msi = "C:\Temp\zabbix_agent2-7.0.X-windows-amd64-openssl.msi"   # ajusta el nombre exacto
msiexec /i $msi /qn /l*v C:\Temp\zabbix-install.log `
  SERVER=192.168.1.20 `
  SERVERACTIVE=192.168.1.20 `
  HOSTNAME=AD-1 `
  ENABLEPATH=1 `
  ADDLOCAL=ALL
```

> Si prefieres el asistente gráfico, ejecuta el MSI y completa los mismos campos: Hostname, Zabbix server IP y Server active.

Verifica el servicio y la configuración:

```powershell
Get-Service "Zabbix Agent 2"
Select-String -Path "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf" -Pattern '^(Server|ServerActive|Hostname)='
```

Repite en **AD-2** (`HOSTNAME=AD-2`) y **CLIENTE-01** (`HOSTNAME=CLIENTE-01`) con las IPs que correspondan.

### 4.3 Firewall de Windows (solo si usas agente pasivo)

El agente activo solo necesita salida hacia 10051 (permitida por defecto). Si además quieres consultas pasivas (útiles para pruebas con `zabbix_get`):

```powershell
New-NetFirewallRule -DisplayName "Zabbix Agent 2 (desde zbx-srv)" -Direction Inbound `
  -Protocol TCP -LocalPort 10050 -RemoteAddress 192.168.1.20 -Action Allow
```

La regla solo permite conexiones desde la IP del servidor. Si usas pasivo, recuerda que en el host de Zabbix la interfaz del agente debe apuntar a esa IP.

### 4.4 Probar el agente localmente (en Windows)

```powershell
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" -c "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf" -t agent.ping
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" -c "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf" -t system.cpu.util
Test-NetConnection 192.168.1.20 -Port 10051
```

Resultado esperado: `agent.ping` = 1 y `TcpTestSucceeded : True`.

### 4.5 Crear los grupos de hosts

En **Data collection → Host groups → Create host group**:
- `Lab/Windows-AD`
- `Lab/Windows-Clientes`
- `Lab/Linux`

Mueve `zbx-srv` a `Lab/Linux`.

### 4.6 Crear los hosts en la interfaz

**Data collection → Hosts → Create host** (uno por equipo):

| Campo | AD-1 | AD-2 | CLIENTE-01 |
|---|---|---|---|
| Host name | `AD-1` | `AD-2` | `CLIENTE-01` |
| Templates | `Windows by Zabbix agent active` | igual | igual |
| Host groups | `Lab/Windows-AD` | `Lab/Windows-AD` | `Lab/Windows-Clientes` |
| Interfaz Agent | IP `192.168.1.201`, puerto 10050 | `.202` | `.203` |

Agrega también la plantilla **`ICMP Ping`** para medir disponibilidad por ping (requiere `fping`, ya instalado en la fase 1; verifica la ruta con `which fping`).

### 4.7 Confirmar recepción de datos

1. **Monitoring → Hosts**: la columna de disponibilidad debe ponerse verde en 1 a 3 minutos.
2. **Monitoring → Latest data**: filtra por host y revisa valores de CPU, memoria y disco.
3. **Data collection → Hosts → AD-1 → Items**: busca items en estado *Not supported* y corrige (ver sección 6).

### 4.8 Ajustes importantes de las plantillas de Windows

La plantilla de Windows descubre servicios automáticos y puede alertar de servicios detenidos que son normales (por ejemplo, servicios de inicio retrasado). Revisa los **macros** del host (*Macros → Inherited and host macros*), en particular los relacionados con la lista de servicios a monitorear, y documenta qué cambiaste y por qué.

### 4.9 Linux: agregar otro equipo (opcional)

Si tienes otro Linux (una VM o el mismo laptop ya está), instala el agente:

```bash
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb
sudo apt update && sudo apt install -y zabbix-agent2
sudo sed -i 's/^Server=.*/Server=192.168.1.20/; s/^ServerActive=.*/ServerActive=192.168.1.20/; s/^Hostname=.*/Hostname=mi-linux/' /etc/zabbix/zabbix_agent2.conf
sudo systemctl enable --now zabbix-agent2
```

## 5. Verificación

| Prueba | Comando / acción | Resultado esperado |
|---|---|---|
| Agente activo en cada VM | `Get-Service "Zabbix Agent 2"` | `Running` |
| Conectividad | `Test-NetConnection 192.168.1.20 -Port 10051` | `True` |
| Consulta pasiva (si abriste 10050) | En el servidor: `zabbix_get -s 192.168.1.201 -k agent.ping` | `1` |
| Disponibilidad en la web | *Monitoring → Hosts* | 3 hosts + `zbx-srv` en verde |
| Datos | *Latest data* de AD-1 | CPU, memoria, discos, red |
| Latencia | Gráfico de *ICMP response time* | Valores normales |

Captura sugerida: `assets/fase3/01-hosts-disponibles.png`. Snapshot de las VMs: `fase-3-zabbix-agent`.

## 6. Problemas encontrados

| Síntoma | Causa | Solución |
|---|---|---|
| Host en rojo / sin datos | `Hostname` distinto al de la interfaz | Igualarlos (mayúsculas incluidas) y reiniciar el agente |
| Agente activo no reporta | 10051 bloqueado o `ServerActive` mal | `Test-NetConnection`; log del agente |
| Items *Not supported* | Contadores de rendimiento en otro idioma | Usar la variante `perf_counter_en[...]` (nombres en inglés) |
| Alertas por servicios que no importan | Descubrimiento amplio de servicios | Ajustar macros de servicios en el host o plantilla |
| ICMP sin datos | `fping` no encontrado | `sudo apt install fping`; revisar `FpingLocation` en `zabbix_server.conf` |

## 7. Lo que aprendí

- _(completar)_

## 8. Siguiente paso

[Fase 4: Monitoreo específico de Active Directory](04-monitoreo-active-directory.md)
