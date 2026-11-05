# RB-003: Poco espacio libre en disco (Linux)

| Campo | Valor |
|---|---|
| **Trigger** | `Free disk space is less than ...` (plantilla Linux) |
| **Severidad** | Warning / Average |
| **Impacto** | Si el disco se llena, la base de datos de Zabbix y los logs dejan de escribir: se pierde el monitoreo |
| **Última revisión** | _AAAA-MM-DD_ |

## 1. Qué significa

El espacio libre de una partición bajó del umbral. En `zbx-srv` el mayor consumo suele ser la base de datos (histórico) y los logs.

## 2. Verificación rápida

```bash
df -h
sudo du -xh / --max-depth=2 2>/dev/null | sort -hr | head -15
```

## 3. Causas probables

1. Histórico de Zabbix creciendo.
2. Logs sin rotar (por ejemplo `zabbix_server.log`).
3. Respaldos acumulados en el mismo disco.
4. Paquetes y kernels antiguos.

## 4. Solución

```bash
# Paquetes y caché
sudo apt autoremove --purge -y
sudo apt clean

# Logs del sistema
sudo journalctl --vacuum-time=7d

# Respaldos antiguos (la rotación del script conserva 7)
ls -lh /var/backups/zabbix
```

Si el problema es la base de datos: reducir la retención del histórico en *Administration → Housekeeping* y ajustar el historial de items poco útiles.

## 5. Cómo confirmar que se resolvió

- `df -h` muestra el porcentaje libre por encima del umbral.
- Alerta resuelta en Zabbix.

## 6. Prevención

- Revisar la tendencia semanal en el dashboard.
- Copiar respaldos a otro equipo y no dejarlos solo en el mismo disco.
