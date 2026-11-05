# Fase 6: Logs y eventos de seguridad

> **Fecha:** _AAAA-MM-DD_ · **Estado:** ⬜

## 1. Objetivo

Detectar eventos de seguridad relevantes leyendo logs: intentos fallidos de inicio de sesión, bloqueos de cuenta y borrado de registros en Windows; y accesos SSH fallidos en Linux.

## 2. Conceptos clave

- **Item de log:** el agente lee un archivo o registro de eventos y envía solo las líneas nuevas. Requiere **agente activo**.
- **Modo `skip`:** al iniciar, ignora el contenido antiguo y procesa solo lo nuevo.
- **Eventos de seguridad de Windows:** dependen de la política de auditoría del DC.

| ID | Qué indica |
|---|---|
| 4625 | Inicio de sesión fallido |
| 4740 | Cuenta bloqueada |
| 4720 | Cuenta de usuario creada |
| 4728 / 4732 / 4756 | Miembro agregado a un grupo de seguridad |
| 4672 | Sesión con privilegios especiales |
| 1102 | **Registro de auditoría borrado** (siempre sospechoso) |

## 3. Requisitos previos

- [ ] Fases 3 a 5 completadas
- [ ] Auditoría avanzada habilitada en los DC (inicio de sesión, administración de cuentas). Si hiciste el laboratorio de AD, corresponde a la fase de hardening/auditoría; verifica con `auditpol /get /category:*`.

## 4. Procedimiento: Windows

### 4.1 Verificar que se generan los eventos

En AD-1, falla a propósito el inicio de sesión de un usuario de prueba (contraseña mala, 2 veces) y comprueba:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625} -MaxEvents 3 |
  Select TimeCreated, Id
```

Si no aparecen, revisa la política de auditoría (*Logon* → *Failure*).

### 4.2 Items de log en la plantilla

En `Lab - AD Domain Controller` → **Items → Create item**. Tipo **Zabbix agent (active)**, tipo de información **Log**, intervalo `1m`, historial `14d`.

| Nombre | Clave |
|---|---|
| Seguridad: inicios de sesión fallidos (4625) | `eventlog[Security,,,,^4625$,,skip]` |
| Seguridad: cuentas bloqueadas (4740) | `eventlog[Security,,,,^4740$,,skip]` |
| Seguridad: registro de auditoría borrado (1102) | `eventlog[Security,,,,^1102$,,skip]` |
| Seguridad: altas en grupos privilegiados (4728/4732/4756) | `eventlog[Security,,,,^(4728\|4732\|4756)$,,skip]` |

Parámetros de la clave `eventlog[nombre,<regexp>,<severidad>,<origen>,<id de evento>,<máx. líneas>,<modo>]`: aquí se filtra solo por **ID de evento** (5.º parámetro) y se usa `skip`.

> Un item de log **no es un número**: no se puede graficar. Para contar intentos en el tiempo se usa un trigger con `count()`.

### 4.3 Triggers

| Nombre | Expresión | Severidad |
|---|---|---|
| `{HOST.NAME}: posible fuerza bruta (5 o más fallos en 5 min)` | `count(/Lab - AD Domain Controller/eventlog[Security,,,,^4625$,,skip],5m)>=5` | High |
| `{HOST.NAME}: cuenta bloqueada` | `count(/Lab - AD Domain Controller/eventlog[Security,,,,^4740$,,skip],10m)>=1` | Average |
| `{HOST.NAME}: se borró el registro de auditoría` | `count(/Lab - AD Domain Controller/eventlog[Security,,,,^1102$,,skip],1h)>=1` | High |
| `{HOST.NAME}: alta en grupo de seguridad` | `count(/Lab - AD Domain Controller/eventlog[Security,,,,^(4728\|4732\|4756)$,,skip],10m)>=1` | Warning |

Configura **"Allow manual close"** en los triggers por evento (cuenta bloqueada, alta en grupo) para poder cerrarlos tras revisarlos, y en **PROBLEM event generation mode** elige *Multiple* en los de evento puntual si quieres un aviso por cada ocurrencia.

> Los triggers basados en logs no "se recuperan" por sí solos como los numéricos: el problema se resuelve cuando la ventana de tiempo de `count()` deja de contener eventos. Documenta qué significa para ti "resuelto" en cada caso.

### 4.4 Probar

1. En CLIENTE-01 intenta iniciar sesión **6 veces** con contraseña incorrecta para un usuario de prueba.
2. Observa en *Monitoring → Latest data* los eventos 4625 y 4740 (el 4740 llega si la política de bloqueo lo activa).
3. Verifica la alerta por Telegram.

> Solo hazlo con cuentas **de tu laboratorio**.

## 5. Procedimiento: Linux (SSH)

### 5.1 Permitir que el agente lea el log

```bash
sudo usermod -aG adm zabbix
sudo systemctl restart zabbix-agent2
sudo -u zabbix head -n 3 /var/log/auth.log      # debe poder leer
```

### 5.2 Item de log

En el host `zbx-srv` (o en una plantilla `Lab - Linux Server`): tipo **Zabbix agent (active)**, información **Log**:

| Nombre | Clave |
|---|---|
| SSH: intentos fallidos | `log[/var/log/auth.log,"Failed password\|Invalid user",,,skip]` |

### 5.3 Trigger

| Nombre | Expresión | Severidad |
|---|---|---|
| `{HOST.NAME}: posibles ataques SSH (5 o más en 5 min)` | `count(/zbx-srv/log[/var/log/auth.log,"Failed password\|Invalid user",,,skip],5m)>=5` | High |

> Si tienes Fail2ban (proyecto de hardening), esto complementa su trabajo: Fail2ban **bloquea**, Zabbix **avisa y registra**.

### 5.4 Probar

Desde **otro equipo tuyo**, intenta 6 conexiones SSH con contraseña incorrecta (o con un usuario inexistente) hacia `zbx-srv` y observa la alerta. Si desactivaste el acceso por contraseña, el log igualmente registra los intentos rechazados.

## 6. Cuidado con el volumen

- Los items de log pueden generar muchos datos. Usa filtros (regexp) y retención corta (7 a 14 días).
- La plantilla de Windows **no** envía todo el log de seguridad; solo lo que filtras tú.

## 7. Verificación

| Prueba | Resultado esperado |
|---|---|
| Items de log creados en la plantilla | Aparecen en *Latest data* |
| 6 fallos de inicio de sesión | Trigger de fuerza bruta + alerta |
| Log de auditoría | Evento 1102 detectado al borrar el log de pruebas (solo en laboratorio: `wevtutil cl Security`) |
| 6 intentos SSH fallidos | Alerta de SSH |

> `wevtutil cl Security` **borra** el registro de seguridad del equipo. Hazlo únicamente en una VM de laboratorio, después de tomar un snapshot.

Capturas: `assets/fase6/01-latest-data-eventlog.png`, `assets/fase6/02-alerta-fuerza-bruta.png`.

## 8. Problemas encontrados

| Síntoma | Causa | Solución |
|---|---|---|
| El item de log queda sin datos | Agente pasivo o permisos | Usar tipo *active*; en Linux agregar a `zabbix` al grupo `adm` |
| El trigger no se activa | `count()` con patrón distinto al de la clave | Comparar la expresión con la clave exacta del item |
| No hay eventos 4625 | Auditoría desactivada | Activar auditoría de inicio de sesión (fallos) en el DC |
| Muchas alertas por un mismo ataque | Modo *Multiple* | Usar modo *Single* y la ventana de `count()` |

## 9. Lo que aprendí

- _(completar)_

## 10. Siguiente paso

[Fase 7: Dashboards, mapas y SLA](07-dashboards-y-sla.md)
