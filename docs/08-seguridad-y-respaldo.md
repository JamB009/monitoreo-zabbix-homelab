# Fase 8: Seguridad y respaldo de Zabbix

> **Fecha:** _AAAA-MM-DD_ · **Estado:** ⬜

## 1. Objetivo

Proteger la plataforma de monitoreo (porque conoce toda tu infraestructura y guarda tokens y contraseñas) y comprobar que se puede **restaurar**.

## 2. Conceptos clave

- **Superficie de ataque:** interfaz web, puerto 10051, base de datos y archivos de configuración.
- **HTTPS:** cifra el acceso a la interfaz (usuario y contraseña viajan por la red). En una LAN sin dominio público se usa un certificado **autofirmado** o de una CA propia.
- **PSK (clave precompartida):** cifra y autentica la comunicación entre agente y servidor.
- **Roles y mínimo privilegio:** no todos los usuarios deben ser *Super admin*.
- **Respaldo útil:** el que se probó restaurando.

## 3. Requisitos previos

- [ ] Fases 2 a 7 funcionando
- [ ] Espacio en disco para respaldos (idealmente un disco o equipo distinto)

## 4. Procedimiento

### 4.1 HTTPS con certificado autofirmado

```bash
sudo mkdir -p /etc/ssl/zabbix
sudo openssl req -x509 -nodes -days 825 -newkey rsa:4096 \
  -keyout /etc/ssl/zabbix/zbx.key -out /etc/ssl/zabbix/zbx.crt \
  -subj "/CN=zbx-srv" -addext "subjectAltName=DNS:zbx-srv,IP:192.168.1.20"
sudo chmod 600 /etc/ssl/zabbix/zbx.key
```

Edita `/etc/zabbix/nginx.conf`:

```nginx
server {
    listen 443 ssl;
    server_name zbx-srv;
    ssl_certificate     /etc/ssl/zabbix/zbx.crt;
    ssl_certificate_key /etc/ssl/zabbix/zbx.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    # ...resto de la configuración existente de Zabbix (root, location, fastcgi)...
}

server {
    listen 80;
    server_name zbx-srv;
    return 301 https://$host$request_uri;
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

> El navegador mostrará una advertencia por ser autofirmado. Acepta la excepción en tu PC o importa el `.crt` como confiable. **No subas el `.key` al repo.**

Actualiza UFW: permite 443 desde tu PC y **elimina** la regla del puerto 80 si ya no la necesitas:

```bash
sudo ufw status numbered
sudo ufw delete <numero_de_regla_80>
```

### 4.2 Cifrado PSK entre agente y servidor (por host)

En el servidor, genera una clave para AD-1:

```bash
openssl rand -hex 32
```

Guárdala en tu gestor (una por host). En **AD-1** crea el archivo de clave con permisos restringidos:

```powershell
$psk = "<PEGAR_CLAVE_HEX>"
Set-Content -Path "C:\Program Files\Zabbix Agent 2\psk.key" -Value $psk -NoNewline
icacls "C:\Program Files\Zabbix Agent 2\psk.key" /inheritance:r /grant:r "SYSTEM:R" "Administrators:R"
```

Agrega en `zabbix_agent2.conf`:

```
TLSConnect=psk
TLSAccept=psk
TLSPSKIdentity=PSK-AD-1
TLSPSKFile=C:\Program Files\Zabbix Agent 2\psk.key
```

```powershell
Restart-Service "Zabbix Agent 2"
```

En la interfaz: **Hosts → AD-1 → Encryption**: *Connections to host* y *Connections from host* en **PSK**, identidad `PSK-AD-1` y la clave. Repite para AD-2 y CLIENTE-01 (cada uno con su propia clave).

> Para un agente **activo**, `TLSConnect=psk` es el parámetro que aplica. Verifica en el log del agente y en la interfaz que el host sigue disponible y que el icono de cifrado aparece.

### 4.3 Usuarios y roles

- **Users → User roles → Create:** crea un rol de solo lectura (`Lectura-Lab`) con acceso a monitoreo y sin permisos de configuración.
- Crea un usuario `invitado-lab` con ese rol (útil para mostrar el panel en entrevistas sin exponer la configuración).
- Mantén **Admin** con contraseña larga y úsalo solo en emergencias.
- Activa en lo posible autenticación en dos pasos si tu versión lo ofrece (TOTP).

### 4.4 Endurecer el servidor

```bash
# Permisos de los archivos de configuración
sudo ls -l /etc/zabbix/zabbix_server.conf        # debe ser legible solo por root y grupo zabbix
sudo chmod 640 /etc/zabbix/zabbix_server.conf

# PostgreSQL solo local
sudo ss -tlnp | grep 5432                        # debe escuchar en 127.0.0.1 / ::1
```

Instala Fail2ban para la interfaz web si no lo tienes (opcional) y activa actualizaciones automáticas (ya hecho en la fase 1).

### 4.5 Script de respaldo

Usa [`scripts/backup-zabbix.sh`](../scripts/backup-zabbix.sh):

```bash
sudo mkdir -p /var/backups/zabbix
sudo cp scripts/backup-zabbix.sh /usr/local/sbin/backup-zabbix.sh
sudo chmod 750 /usr/local/sbin/backup-zabbix.sh
sudo /usr/local/sbin/backup-zabbix.sh
ls -lh /var/backups/zabbix
```

El script guarda:
- Un volcado de la base **sin los datos históricos** (items, hosts, triggers, acciones y usuarios sí se respaldan).
- Una copia de `/etc/zabbix` y de la configuración de Nginx.
- Rotación: conserva los últimos 7 respaldos.

Programación con cron (todos los días 02:30):

```bash
echo '30 2 * * * root /usr/local/sbin/backup-zabbix.sh >> /var/log/backup-zabbix.log 2>&1' | sudo tee /etc/cron.d/backup-zabbix
```

Copia periódicamente los respaldos a **otro equipo** (por ejemplo con `rsync` por SSH a tu PC). Un respaldo en el mismo disco no protege de un fallo del disco.

> Los respaldos contienen el token de Telegram, credenciales SMTP y la configuración completa. Protégelos con permisos `600` y **no los subas a GitHub**.

### 4.6 Exportar configuración versionable

En la interfaz exporta a YAML las plantillas propias (`Lab - ...`) y guárdalas en `assets/exports/`. Esos archivos sí pueden versionarse (revisa que no incluyan secretos).

### 4.7 Prueba de restauración (la parte importante)

En una VM o en el mismo servidor con otro nombre de base de datos:

```bash
# 1) Crear una BD temporal
sudo -u postgres createdb -O zabbix zabbix_restore

# 2) Restaurar el volcado más reciente
sudo -u postgres pg_restore -d zabbix_restore /var/backups/zabbix/zabbix-db-AAAAMMDD-HHMM.dump

# 3) Comprobar que hay hosts y triggers
sudo -u postgres psql zabbix_restore -c "SELECT count(*) AS hosts FROM hosts;"
sudo -u postgres psql zabbix_restore -c "SELECT count(*) AS triggers FROM triggers;"

# 4) Limpiar
sudo -u postgres dropdb zabbix_restore
```

Documenta los tiempos y el resultado. Una restauración **completa** (reinstalar el servidor y cargar la BD) puede hacerse una vez en una VM para cerrar el ciclo.

### 4.8 Actualizaciones

- Antes de actualizar Zabbix: respaldo + leer notas de la versión.
- Actualización de parches dentro de la misma serie (7.0.x): `sudo apt update && sudo apt upgrade` (revisa antes qué paquetes cambian).
- Cambio de versión mayor (7.0 → 8.0): sigue la documentación oficial de *upgrade*; hazlo primero en una copia.

## 5. Verificación

| Prueba | Resultado esperado |
|---|---|
| `https://zbx-srv/` | Carga con advertencia aceptada; HTTP redirige a HTTPS |
| `ss -tlnp` | Nginx 443 y 80 (redirección), PostgreSQL solo local |
| Hosts con PSK | Disponibles, con icono de cifrado |
| Usuario de solo lectura | Ve paneles pero no configuración |
| Respaldo diario | Archivo nuevo cada día; rotación funcionando |
| Restauración de prueba | Conteo de hosts/triggers coherente |

Capturas: `assets/fase8/01-https.png`, `assets/fase8/02-hosts-psk.png`, `assets/fase8/03-restauracion.png`.

## 6. Problemas encontrados

| Síntoma | Causa | Solución |
|---|---|---|
| Host en rojo tras activar PSK | Identidad o clave no coinciden | Comparar identidad y clave en ambos lados; sin espacios finales |
| `nginx -t` falla | Bloque `server` duplicado | Quitar la configuración antigua de `listen 80` |
| `pg_restore` con errores de roles | Dueños distintos | Restaurar con `--no-owner --role=zabbix` |

## 7. Lo que aprendí

- _(completar)_

## 8. Siguiente paso

[Fase 9: Simulacro de incidentes y métricas](09-simulacro-de-incidentes.md)
