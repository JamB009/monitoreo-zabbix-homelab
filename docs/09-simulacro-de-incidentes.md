# Fase 9: Simulacro de incidentes y métricas

> **Fecha:** _AAAA-MM-DD_ · **Estado:** ⬜

## 1. Objetivo

Comprobar con **pruebas reales** que el monitoreo funciona: provocar fallas controladas, medir cuánto tarda en llegar la alerta y cuánto tarda en resolverse, y mejorar lo que no funcione como esperabas.

## 2. Conceptos clave

- **MTTD (tiempo medio de detección):** desde que ocurre la falla hasta que llega la alerta.
- **MTTR (tiempo medio de resolución):** desde la alerta hasta que el servicio vuelve a la normalidad.
- **Falso negativo:** pasó algo y no hubo alerta (lo más grave en monitoreo).
- **Falso positivo:** hubo alerta y no pasaba nada (genera fatiga).
- **Simulacro:** prueba planificada, con un plan de reversión.

## 3. Requisitos previos

- [ ] Fases 3 a 8 completadas
- [ ] Snapshots de las VMs y respaldo de Zabbix recientes
- [ ] Regla de oro: **nunca provoques fallas en ambos DC a la vez** ni en el servidor de monitoreo sin un plan de vuelta atrás
- [ ] Un reloj (o el teléfono) para anotar horas exactas

## 4. Método

Para cada prueba, registra en la tabla del apartado 6:
1. **Hora de inicio** de la falla (T0).
2. **Hora de la alerta** en Telegram (T1). MTTD = T1 − T0.
3. **Hora de resolución** (T2). MTTR = T2 − T1.
4. Qué trigger se activó y con qué severidad.
5. Si hubo alertas de más o de menos.
6. Evidencia: captura de Telegram y del evento en *Monitoring → Problems*.

## 5. Escenarios

| # | Escenario | Cómo provocarlo | Alerta esperada | Notas |
|---|---|---|---|---|
| 1 | Servicio DNS detenido en AD-2 | `Stop-Service DNS` en AD-2 | `AD-2: servicio DNS detenido` (High) | Recuperar: `Start-Service DNS` |
| 2 | Servicio Netlogon detenido en AD-2 | `Stop-Service Netlogon` | Alerta High | Reiniciar el servicio después |
| 3 | AD-2 apagado | Apagar la VM | `Unavailable by ICMP ping` y agente no disponible; **sin** alertas de servicios | Prueba de dependencias |
| 4 | Fallos de inicio de sesión | 6 intentos fallidos en CLIENTE-01 | Fuerza bruta (High) y posible cuenta bloqueada | Solo cuenta de laboratorio |
| 5 | Hora desfasada | En CLIENTE-01 no aplica; en AD-2: `w32tm /config /syncfromflags:manual` y cambiar hora con cuidado, **solo con snapshot** | `hora desfasada` (Average) | Restaurar con `w32tm /resync` |
| 6 | Disco casi lleno (Linux) | `fallocate -l 5G /var/tmp/relleno.img` (ajusta el tamaño al % libre) | Trigger de espacio libre | Borrar el archivo después |
| 7 | CPU alta (Linux) | `sudo apt install -y stress-ng && stress-ng --cpu 2 --timeout 10m` | `High CPU utilization` | Se detiene solo |
| 8 | Intentos SSH fallidos | 6 conexiones con credenciales erróneas desde otro equipo | Alerta SSH (High) | Requiere el item de log |
| 9 | Pérdida de conectividad del agente | `Stop-Service "Zabbix Agent 2"` en AD-1 | `Zabbix agent is not available` | Prueba del `nodata` |
| 10 | Caída de Zabbix server | `sudo systemctl stop zabbix-server` | **No habrá alerta** (el servidor es quien alerta) | Ver conclusión en el apartado 7 |

> Para el escenario 6, no llenes el disco al 100 %: ajusta el tamaño para cruzar el umbral Warning (por ejemplo 80 % usado) y mantén margen.

## 6. Tabla de resultados (completar)

| # | T0 | T1 (alerta) | MTTD | T2 (resuelto) | MTTR | Severidad | Ruido (alertas extra) | Observaciones |
|---|---|---|---|---|---|---|---|---|
| 1 | | | | | | | | |
| 2 | | | | | | | | |
| 3 | | | | | | | | |
| 4 | | | | | | | | |
| 5 | | | | | | | | |
| 6 | | | | | | | | |
| 7 | | | | | | | | |
| 8 | | | | | | | | |
| 9 | | | | | | | | |
| 10 | | | | | | | | |

## 7. Análisis

1. **¿Qué MTTD es razonable?** Depende de los intervalos y de la histéresis: con `1m` y `#2`, esperas 2 a 3 minutos. Si necesitas menos, baja el intervalo o la cantidad de mediciones, y evalúa el costo en ruido.
2. **Falsos negativos encontrados:** lista cada caso y cómo lo corregiste.
3. **Caída del propio Zabbix:** un monitoreo no se vigila a sí mismo. Opciones: un chequeo externo gratuito (un servicio de *heartbeat*), un segundo Zabbix mínimo, o al menos un script en otro equipo que avise por Telegram si el servidor no responde. Documenta qué decidiste y por qué.
4. **Mejoras aplicadas:** umbrales, dependencias, descripciones de trigger y runbooks.
5. **Reflexión:** ¿qué aprendiste de operar con alertas reales?

> Opcional (pequeño): crea un script en tu PC que haga `curl` al puerto/URL de Zabbix cada 5 minutos y envíe un mensaje por la API de Telegram si falla. Es un monitor del monitor.

## 8. Runbooks

Para cada alerta que probaste, comprueba que su **runbook** existe y sirve (carpeta [`runbooks/`](../runbooks/)). Siguiendo el runbook, otra persona debería poder resolver el problema. Anota qué faltó y corrígelo.

## 9. Cierre del proyecto

- [ ] Tabla de resultados completa
- [ ] Capturas de alertas y de los eventos
- [ ] Runbooks revisados
- [ ] README y ROADMAP actualizados
- [ ] Release `v1.0` en GitHub
- [ ] Post de cierre en LinkedIn con 2 o 3 métricas reales (MTTD, cantidad de alertas de ruido eliminadas, SLA medido)
- [ ] Guion de entrevista practicado

## 10. Siguiente paso

Opcional: [Fase 10: Grafana](10-grafana-opcional.md)
