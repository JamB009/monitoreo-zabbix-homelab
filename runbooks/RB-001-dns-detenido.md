# RB-001: Servicio DNS detenido en un Domain Controller

| Campo | Valor |
|---|---|
| **Trigger** | `{HOST.NAME}: servicio DNS detenido` |
| **Severidad** | High |
| **Impacto** | Los clientes que usan este DC como DNS dejan de resolver; si es el único activo, el dominio queda inutilizable |
| **Responsable** | Administrador del laboratorio |
| **Última revisión** | _AAAA-MM-DD_ |

## 1. Qué significa

El servicio `DNS` del DC no está en ejecución. Active Directory depende de DNS para que los equipos encuentren controladores de dominio.

## 2. Verificación rápida (2 minutos)

En el DC afectado:

```powershell
Get-Service DNS
```

- `Stopped` → problema real.
- `Running` pero Zabbix alerta → revisar el agente y la hora del equipo (falso positivo posible).

Desde un cliente: `Resolve-DnsName lab.local -Server <IP_del_DC>`.

## 3. Causas probables

1. El servicio se detuvo por una actualización o reinicio incompleto.
2. Error en una zona DNS o en la base de datos.
3. Falta de recursos (el equipo del laboratorio está justo de RAM).

## 4. Solución

```powershell
Start-Service DNS
Get-Service DNS
Get-WinEvent -LogName "DNS Server" -MaxEvents 20 | Format-Table TimeCreated, Id, LevelDisplayName, Message -Wrap
```

Si no inicia:
1. Revisar el visor de eventos (*DNS Server*, *System*).
2. Comprobar espacio en disco: `Get-PSDrive C`.
3. Verificar el DC compañero: `Resolve-DnsName lab.local -Server <IP_del_otro_DC>` (los clientes deberían seguir funcionando con el DNS alternativo).

## 5. Cómo confirmar que se resolvió

- `Get-Service DNS` → `Running`.
- `dcdiag /test:dns` sin errores críticos.
- En Zabbix el problema pasa a *Resuelto* y llega el mensaje de recuperación.

## 6. Si no se resuelve

- Reiniciar el DC en una ventana controlada, **solo si el otro DC está sano**.
- Revisar replicación: `repadmin /replsummary`.

## 7. Prevención

- Mantener DNS redundante en los clientes (opción 006 de DHCP).
- Más RAM o menos VMs simultáneas.
