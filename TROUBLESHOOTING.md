# Troubleshooting

Registro de problemas reales del proyecto. Formato: **síntoma → diagnóstico → causa → solución → prevención**.

## Índice

- [T-001 Plantilla](#t-001-plantilla)
- [T-002 El router no deja reservar la IP actual](#t-002-el-router-no-deja-reservar-la-ip-actual)
- [T-003 'xterm-kitty': unknown terminal type por SSH](#t-003-xterm-kitty-unknown-terminal-type-por-ssh)
- [Referencia rápida de diagnóstico](#referencia-rápida-de-diagnóstico)
- [Problemas frecuentes](#problemas-frecuentes)

---

## T-001 Plantilla

- **Fase:**
- **Síntoma:**
- **Diagnóstico:** (comandos usados y qué mostraron)
- **Causa:**
- **Solución:**
- **Prevención:**
- **Estado:**

---

## T-002 El router no deja reservar la IP actual

- **Fase:** 0
- **Síntoma:** al crear la reserva en *LAN Settings → DHCP Static IP Settings* (MAC `78:84:3c:af:22:77` → `192.168.1.19`), el router muestra "IP address is already in use".
- **Diagnóstico:** `ip -br addr` en el laptop mostraba la .19 obtenida por DHCP (`proto dhcp` en `ip route`); la IP estaba prestada en ese momento al propio laptop.
- **Causa:** el router valida que la IP de la reserva no esté asignada en un préstamo activo, aunque sea al mismo equipo.
- **Solución:** reservar otra IP libre (`192.168.1.50`) para la misma MAC y reiniciar el laptop (`sudo reboot`) para que pida un préstamo nuevo. Verificado con `ping 192.168.1.50` y `ip -br addr show enp9s0`.
- **Prevención:** planificar las IPs de servidores antes de conectarlos y reservarlas en una zona que no se use para equipos de la casa.
- **Recurrencia (mismo día):** al reservar la .2 del PC salió el mismo error. Además, por error se **editó** la fila de la reserva del laptop (.50) en vez de pulsar *Add*, y la reserva se perdió. No se pudo recrear: el router conserva el préstamo de la .50 hasta que vence (24 h) aunque el laptop se desconecte (`networkctl down enp9s0` durante 2 min no lo liberó), y el laptop lo renueva solo mientras está encendido.
  - **Solución final:** reservar IPs libres: laptop `78:84:3c:af:22:77` → **192.168.1.20**, PC `04:42:1a:09:e6:d0` → **192.168.1.10**. Después, reiniciar el laptop y en el PC ejecutar `nmcli connection down/up "Conexión cableada 1"`. Verificado: `ip -br addr show enp6s0` → `192.168.1.10/24`; `ping 192.168.1.20` responde. Docs actualizados (.50 → .20, .2 → .10).
  - **Regla para este router:** reservar siempre una IP que **nadie esté usando** (revisar *DHCP Clients List*), y después renovar el préstamo del equipo. Para agregar una reserva, usar **Add**; no editar una fila existente.
- **Estado:** resuelto (2026-11-02).

---

## T-003 'xterm-kitty': unknown terminal type por SSH

- **Fase:** 0
- **Síntoma:** al ejecutar `clear` en el laptop por SSH aparece `'xterm-kitty': unknown terminal type.`
- **Diagnóstico:** el PC usa la terminal kitty, que envía `TERM=xterm-kitty`; el servidor no tiene esa definición terminfo.
- **Causa:** falta la entrada terminfo de kitty en Ubuntu Server.
- **Solución:** conectarse con `kitten ssh sultan@192.168.1.20` (copia el terminfo automáticamente) o con `TERM=xterm-256color ssh …`.
- **Prevención:** usar siempre `kitten ssh` desde kitty.
- **Estado:** resuelto (2026-11-02).

---

## T-004 getUpdates de Telegram no devuelve nada

- **Fase:** 0 (preparación de la fase 5)
- **Síntoma:** `curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates" | ... | grep -A3 '"chat"'` no muestra nada, aunque el bot recibió `/start` y varios mensajes (✓✓ en el chat).
- **Diagnóstico:** sin el `grep`, la respuesta también estaba vacía. `echo ${#TOKEN}` → `3` (un token mide unos 46 caracteres). Red descartada: `curl -sv https://api.telegram.org` resuelve el DNS e inicia el TLS, y `ping 1.1.1.1` responde.
- **Causa:** el token no llegó a la variable al pegarlo en `read -rsp` (en la terminal, Ctrl+V no pega; kitty usa **Ctrl+Shift+V**). Con la URL `bot<3 caracteres>/getUpdates`, `curl -s` no muestra nada útil.
- **Solución:** obtener el `chat_id` con `@userinfobot` en Telegram, sin usar el token. La prueba de envío se hará en la fase 5 desde *Media types → Test*.
- **Prevención:** antes de usar una variable con un secreto, comprobar su longitud con `echo ${#TOKEN}` y su formato con `[[ $TOKEN =~ ^[0-9]+:[A-Za-z0-9_-]{30,}$ ]]`. Quitar el `grep` cuando "no sale nada", para ver la respuesta completa.
- **Estado:** resuelto (2026-11-04).

---

## Referencia rápida de diagnóstico

### En el servidor (Ubuntu)

| Qué revisar | Comando |
|---|---|
| Estado de los servicios | `systemctl status zabbix-server zabbix-agent2 nginx postgresql` |
| Servicio PHP-FPM (ajustar versión) | `systemctl status php8.3-fpm` |
| Log del servidor | `sudo tail -n 100 /var/log/zabbix/zabbix_server.log` |
| Log del agente local | `sudo tail -n 100 /var/log/zabbix/zabbix_agent2.log` |
| Puertos en escucha | `sudo ss -tlnp \| grep -E '10050\|10051\|80\|443\|8080'` |
| Probar configuración de Nginx | `sudo nginx -t` |
| Log de Nginx | `sudo tail -n 50 /var/log/nginx/error.log` |
| Conexión a la base de datos | `sudo -u postgres psql -c '\l'` |
| Reglas del firewall | `sudo ufw status numbered` |
| Hora y sincronización | `timedatectl` |
| Consultar un item desde el servidor | `zabbix_get -s <IP_AGENTE> -k agent.ping` (instalar `zabbix-get`) |

### En un agente Windows

| Qué revisar | Comando (PowerShell) |
|---|---|
| Servicio | `Get-Service "Zabbix Agent 2"` |
| Log del agente | `Get-Content "C:\Program Files\Zabbix Agent 2\zabbix_agent2.log" -Tail 50` |
| Probar un item local | `& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" -c "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf" -t agent.ping` |
| Conectividad al servidor | `Test-NetConnection <IP_ZBX> -Port 10051` |
| Reiniciar agente | `Restart-Service "Zabbix Agent 2"` |

## Problemas frecuentes

| Síntoma | Causa habitual | Solución |
|---|---|---|
| Host en rojo (ZBX) en la interfaz | El servidor no llega al agente (modo pasivo) o el nombre no coincide | Revisar IP/puerto 10050, firewall; el `Hostname` del agente debe ser idéntico al del host en Zabbix |
| Agente activo sin datos | Puerto 10051 bloqueado o `ServerActive` mal escrito | `Test-NetConnection <IP_ZBX> -Port 10051`; revisar log del agente |
| Pantalla de Nginx por defecto en vez de Zabbix | El sitio `default` sigue activo | `sudo rm /etc/nginx/sites-enabled/default` y reiniciar Nginx |
| Error 502 Bad Gateway | PHP-FPM detenido o socket distinto | `systemctl status php8.3-fpm`; revisar el socket en `/etc/zabbix/nginx.conf` |
| El asistente web no conecta a la BD | Contraseña distinta o falta `php-pgsql` | Verificar `DBPassword` y el paquete del driver |
| Items "no soportados" | Clave mal escrita o permisos insuficientes | Ver el mensaje de error del item en *Data collection → Hosts → Items* |
| UserParameter devuelve "timeout" | PowerShell tarda en arrancar | Subir `Timeout` del agente y del item; ver fase 4 |
| No llegan alertas de Telegram | Token/chat ID incorrectos o sin salida a internet desde el servidor | Probar con `curl` desde el servidor; revisar *Reports → Action log* |
| No llegan correos | App password incorrecta, o puerto/STARTTLS mal configurado | Revisar el *Action log*; usar contraseña de aplicación |
| Tormenta de alertas | Sin dependencias entre triggers | Ver fase 5: dependencias e histéresis |
| Reloj desfasado | NTP sin sincronizar | `timedatectl`; revisar `systemd-timesyncd` |
