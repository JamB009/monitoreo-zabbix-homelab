# Fase 5: Triggers y alertas (Telegram y correo)

> **Fecha:** _AAAA-MM-DD_ · **Estado:** ⬜

## 1. Objetivo

Convertir los datos en **alertas útiles**: triggers bien diseñados (sin ruido), dependencias, notificaciones por Telegram y correo, escalamiento y enlace a un procedimiento de respuesta (runbook).

## 2. Conceptos clave

- **Trigger:** expresión que define cuándo hay un *problema*. Pasa de `OK` a `PROBLEM` y vuelve a `OK`.
- **Histéresis:** evitar que una alerta aparezca y desaparezca continuamente. Se logra exigiendo varios valores consecutivos o usando una expresión de recuperación distinta. *Es el mismo concepto que el diferencial de un termostato o de un relé de protección.*
- **Dependencias:** si el equipo está caído, no tiene sentido recibir 15 alertas de sus servicios. Los triggers hijos dependen del trigger "equipo no disponible".
- **Severidad:** Not classified, Information, Warning, Average, High, Disaster (ver [política de severidades](00-diseno-y-requisitos.md#8-política-de-severidades-se-usará-en-la-fase-5)).
- **Acción:** regla *si [condiciones] entonces [operaciones]*. Incluye pasos de escalamiento y de recuperación.
- **Fatiga de alertas:** si todo alerta, nada se atiende. Una alerta debe ser **accionable**.

## 3. Requisitos previos

- [ ] Fase 4 completada
- [ ] Salida a internet desde `zbx-srv` (Telegram y SMTP)

## 4. Procedimiento

### 4.1 Triggers de la plantilla `Lab - AD Domain Controller`

En la plantilla → **Triggers → Create trigger**. Sintaxis de Zabbix 7.0 (el nombre entre barras es la plantilla):

| Nombre | Expresión | Severidad |
|---|---|---|
| `{HOST.NAME}: servicio AD DS (NTDS) detenido` | `min(/Lab - AD Domain Controller/service.info[NTDS,state],#2)<>0` | Disaster |
| `{HOST.NAME}: servicio DNS detenido` | `min(/Lab - AD Domain Controller/service.info[DNS,state],#2)<>0` | High |
| `{HOST.NAME}: servicio Netlogon detenido` | `min(/Lab - AD Domain Controller/service.info[Netlogon,state],#2)<>0` | High |
| `{HOST.NAME}: servicio Kerberos KDC detenido` | `min(/Lab - AD Domain Controller/service.info[Kdc,state],#2)<>0` | High |
| `{HOST.NAME}: servicio DFSR detenido` | `min(/Lab - AD Domain Controller/service.info[DFSR,state],#2)<>0` | Average |
| `{HOST.NAME}: servicio de hora (W32Time) detenido` | `min(/Lab - AD Domain Controller/service.info[W32Time,state],#2)<>0` | Average |
| `{HOST.NAME}: fallos de replicación de AD` | `min(/Lab - AD Domain Controller/ad.repl.failures,#2)>0` | High |
| `{HOST.NAME}: el chequeo de replicación no funciona` | `last(/Lab - AD Domain Controller/ad.repl.failures)<0` | Warning |
| `{HOST.NAME}: hora desfasada más de 2 min respecto a Zabbix` | `fuzzytime(/Lab - AD Domain Controller/system.localtime,120s)=0` | Average |
| `{HOST.NAME}: LDAP (389) no responde` | `max(/Lab - AD Domain Controller/net.tcp.service[ldap,,389],#3)=0` | High |
| `{HOST.NAME}: DNS (53/TCP) no responde` | `max(/Lab - AD Domain Controller/net.tcp.service[tcp,,53],#3)=0` | High |

**Cómo leer `min(...,#2)<>0`:** toma los **2 últimos valores** del item y se queda con el menor; es distinto de 0 solo si ambos fueron distintos de 0. Es decir, el problema se declara tras **dos mediciones malas seguidas** (≈ 2 minutos), no por un valor aislado.

**Cómo leer `max(...,#3)=0`:** el mayor de los últimos 3 valores es 0 solo si los 3 fueron 0.

En cada trigger completa:
- **Descripción:** qué significa y primer paso de diagnóstico.
- **URL:** enlace al runbook en tu repositorio (por ejemplo `https://github.com/TU_USUARIO/monitoreo-zabbix-homelab/blob/main/runbooks/RB-001-dns-detenido.md`).
- **Etiquetas (tags):** `servicio:ad`, `servicio:dns`, `capa:disponibilidad` según corresponda.
- **Expresión de recuperación (opcional):** por ejemplo, para disco puedes alertar al 80 % y recuperar al 75 %.

### 4.2 Dependencias

Aún en la plantilla, abre cada trigger de servicio/replicación/LDAP → pestaña **Dependencies → Add** y elige:
- `Unavailable by ICMP ping` (plantilla `ICMP Ping`)
- `Zabbix agent is not available (for {$AGENT.NODATA_TIMEOUT})` (plantilla de Windows activa)

Resultado: con el servidor caído recibes **una** alerta (equipo no disponible), no una por servicio.

> Si un trigger dependiente no aparece en la lista, es porque la plantilla que lo contiene no está enlazada a `Lab - AD Domain Controller` (ver fase 4, paso 4.1).

### 4.3 Triggers de recursos (ajustar, no duplicar)

La plantilla de Windows ya incluye triggers de CPU y disco. **No los dupliques**: ajusta sus umbrales con macros en la plantilla propia o en el host (*Macros → Inherited*). Revisa los nombres exactos de los macros de tu versión (por ejemplo `{$CPU.UTIL.CRIT}`, `{$VFS.FS.PFREE.MIN.WARN}`, `{$VFS.FS.PFREE.MIN.CRIT}`) y documenta tus valores.

### 4.4 Crear el bot de Telegram

1. En Telegram, abre `@BotFather` y envía `/newbot`. Elige nombre y usuario (termina en `bot`).
2. BotFather entrega un **token** del tipo `123456:ABC...`. Guárdalo en tu gestor de contraseñas. **No lo subas a GitHub ni lo muestres en capturas.**
3. Envía un mensaje cualquiera a tu bot (o agrégalo a un grupo y escribe en él).
4. Obtén tu `chat_id` desde el servidor:

```bash
curl -s "https://api.telegram.org/bot<TOKEN_DEL_BOT>/getUpdates" | python3 -m json.tool | grep -A3 '"chat"'
```

El campo `id` es tu `chat_id` (los grupos tienen ID negativo).

> **Alternativa sin token:** en un chat privado, el `chat_id` es tu id de usuario. Escríbele a `@userinfobot` en Telegram y te lo devuelve (campo `Id`). Así lo obtuve en este lab (ver T-004).

5. Prueba el envío directo (esto valida la salida a internet del servidor):

```bash
curl -s -X POST "https://api.telegram.org/bot<TOKEN_DEL_BOT>/sendMessage" \
  -d chat_id=<CHAT_ID> -d text="Prueba desde zbx-srv"
```

### 4.5 Configurar el tipo de medio Telegram en Zabbix

**Alerts → Media types → Telegram** (viene incluido en Zabbix 7.0):
1. En *Parameters*, pega el token en `Token`. Mantén `To` = `{ALERT.SENDTO}`, `Subject` = `{ALERT.SUBJECT}`, `Message` = `{ALERT.MESSAGE}`. `ParseMode` déjalo vacío si el texto tiene caracteres especiales.
2. Marca **Enabled** y guarda.
3. Usa el botón **Test** con tu `chat_id` en "Send to". Debe llegar el mensaje al teléfono.

Luego, **Users → tu usuario → Media → Add**: tipo `Telegram`, *Send to* = tu `chat_id`, severidades: Average o superior, periodo 24x7.

> El token queda guardado en la base de datos de Zabbix. Por eso los respaldos de la BD **no se suben** al repositorio (ver [fase 8](08-seguridad-y-respaldo.md)).

### 4.6 Configurar el correo (SMTP)

1. En tu cuenta de correo activa la **verificación en dos pasos** y crea una **contraseña de aplicación**.
2. **Alerts → Media types → Email → Edit:**

| Campo | Valor (ejemplo con Gmail) |
|---|---|
| SMTP server | `smtp.gmail.com` |
| SMTP server port | `587` |
| SMTP helo | `gmail.com` |
| SMTP email | `tu.correo@gmail.com` |
| Connection security | `STARTTLS` |
| Authentication | `Username and password` |
| Username | `tu.correo@gmail.com` |
| Password | _contraseña de aplicación_ |

3. **Test** con tu correo. En tu usuario agrega el medio *Email* con severidad High o superior.

### 4.7 Acción de notificación

**Alerts → Actions → Trigger actions → Create action:** `Lab - Notificar problemas`.

**Condiciones:**
- *Tag name* `servicio` **equals**… (opcional, para segmentar)
- *Trigger severity* **is greater than or equals** `Average`
- *Host group* **equals** `Lab/Windows-AD` o `Lab/Linux`

**Operaciones (con escalamiento):**

| Paso | Cuándo | Acción |
|---|---|---|
| 1 | Inmediato | Enviar mensaje a tu usuario por **Telegram** |
| 2 | Tras 10 min si el evento **no está reconocido** (*Event is not acknowledged*) | Enviar por **Email** |

**Operaciones de recuperación:** enviar mensaje por Telegram ("Resuelto").

**Plantilla del mensaje** (pestaña de operaciones → *Default message*):

```
Problema: {EVENT.NAME}
Host: {HOST.NAME} ({HOST.IP})
Severidad: {EVENT.SEVERITY}
Inicio: {EVENT.TIME} del {EVENT.DATE}
Dato operativo: {EVENT.OPDATA}
Procedimiento: {TRIGGER.URL}
ID de evento: {EVENT.ID}
```

Para la recuperación usa `Resuelto: {EVENT.NAME}` con duración `{EVENT.DURATION}`.

### 4.8 Ventanas de mantenimiento

**Data collection → Maintenance → Create:** `Parcheo semanal` (por ejemplo domingos 03:00 a 04:00), tipo *With data collection*, grupos `Lab/Windows-AD`. Evita alertas durante reinicios planificados.

### 4.9 Reconocimiento de eventos

Practica el flujo operativo: cuando llegue una alerta, ve a **Monitoring → Problems**, abre el evento, **Acknowledge** con un comentario ("En revisión según RB-001"). Eso detiene el escalamiento del paso 2.

## 5. Verificación

| Prueba | Acción | Resultado esperado |
|---|---|---|
| Telegram | *Media types → Test* | Mensaje en el teléfono |
| Correo | *Media types → Test* | Correo recibido (revisar spam la primera vez) |
| Alerta real | En AD-2 (nunca en ambos DC a la vez): `Stop-Service DNS` y espera 2 a 3 min | Alerta High por Telegram con enlace al runbook |
| Recuperación | `Start-Service DNS` | Mensaje "Resuelto" |
| Dependencias | Apagar la VM AD-2 | **Una** alerta de host no disponible; sin alertas de servicios |
| Escalamiento | No reconocer el evento 10 min | Llega el correo |
| Registro | *Reports → Action log* | Entradas con estado *Sent* |

Capturas: `assets/fase5/01-alerta-telegram.png` (**oculta** datos sensibles), `assets/fase5/02-trigger-dependencias.png`.

## 6. Problemas encontrados

| Síntoma | Causa | Solución |
|---|---|---|
| Test de Telegram falla | Token o `chat_id` mal; sin salida a internet | Repetir las pruebas con `curl` del paso 4.4 |
| `chat_id` no aparece en `getUpdates` | No hay mensajes recientes al bot | Escribirle al bot y repetir |
| Correo rechazado | Contraseña normal en vez de contraseña de aplicación | Crear la contraseña de aplicación |
| Alerta repetida y desaparece | Falta histéresis | Usar `#N` o expresión de recuperación |
| No llegan alertas aunque el trigger está en PROBLEM | La acción no coincide (severidad/grupo) o el usuario no tiene el medio | Revisar condiciones y *Media* del usuario; *Action log* |

## 7. Lo que aprendí

- _(completar: ¿cuántas alertas "de ruido" eliminaste y cómo?)_

## 8. Siguiente paso

[Fase 6: Logs y eventos de seguridad](06-logs-y-eventos.md)
