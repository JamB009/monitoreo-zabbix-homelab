# RB-002: Fallos de replicación de Active Directory

| Campo | Valor |
|---|---|
| **Trigger** | `{HOST.NAME}: fallos de replicación de AD` |
| **Severidad** | High |
| **Impacto** | Los cambios (usuarios, contraseñas, GPO) no llegan a todos los DC; riesgo de inconsistencias |
| **Última revisión** | _AAAA-MM-DD_ |

## 1. Qué significa

Un DC no consigue replicar con su socio de replicación. El item `ad.repl.failures` devuelve un valor mayor que 0.

## 2. Verificación rápida (2 minutos)

```powershell
repadmin /replsummary
repadmin /showrepl
Get-ADReplicationFailure -Target $env:COMPUTERNAME -Scope Server
```

Si `ad.repl.failures` vale `-1`, el problema es del chequeo (revisar el script), no de AD: ver [TROUBLESHOOTING](../TROUBLESHOOTING.md).

## 3. Causas probables

1. El otro DC está apagado o inalcanzable (en el laboratorio, lo más común).
2. DNS incorrecto en alguno de los DC.
3. Hora desfasada entre DC (Kerberos).
4. Firewall bloqueando puertos de replicación.

## 4. Solución

1. Confirmar que ambos DC están encendidos y se ven: `Test-Connection <IP_del_otro_DC>`.
2. Revisar DNS: `nslookup -type=SRV _ldap._tcp.lab.local`.
3. Revisar hora: `w32tm /query /status` y corregir con `w32tm /resync`.
4. Forzar sincronización cuando todo esté sano: `repadmin /syncall /AdeP`.
5. Diagnóstico completo: `dcdiag /v`.

## 5. Cómo confirmar que se resolvió

- `repadmin /replsummary` sin fallos.
- `ad.repl.failures` = 0 en Zabbix y alerta resuelta.

## 6. Si no se resuelve

- Revisar los registros *Directory Service* y *DFS Replication*.
- Considerar el procedimiento de recuperación del laboratorio de AD (restauración desde respaldo).

## 7. Prevención

- Encender AD-1 antes que AD-2 y esperar el arranque completo.
- Mantener hora sincronizada.
