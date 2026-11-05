# Fase 2: Instalar Zabbix server (PostgreSQL + Nginx)

> **Fecha:** _AAAA-MM-DD_ · **Estado:** ⬜

## 1. Objetivo

Instalar Zabbix 7.0 LTS con base de datos PostgreSQL y frontend con Nginx, y dejar el servidor monitoreándose a sí mismo.

## 2. Conceptos clave

- **Componentes:** `zabbix-server` (procesa y alerta), `frontend` (interfaz web en PHP), base de datos (PostgreSQL), `zabbix-agent2` (agente local).
- **Repositorio oficial:** se instala desde el repositorio de Zabbix, no desde el de Ubuntu (que trae versiones distintas).
- **Versión:** esta guía usa **7.0 LTS**. Las URLs y rutas se generan en la página oficial de descargas (`zabbix.com/download`); **cópialas desde allí** eligiendo tu versión de Zabbix, tu Ubuntu, base de datos PostgreSQL y servidor web Nginx, porque pueden cambiar con las versiones.

## 3. Requisitos previos

- [ ] Fase 1 completada (IP fija, hora, UFW)
- [ ] Contraseña para el usuario `zabbix` de la base de datos (generar con el gestor de contraseñas; no la subas al repo)

## 4. Procedimiento

> Los comandos siguientes corresponden a **Ubuntu 24.04 + Zabbix 7.0 + PostgreSQL + Nginx**. Para Ubuntu 22.04 cambia `ubuntu24.04` por `ubuntu22.04` y `php8.3` por `php8.1`.

### 4.1 Instalar PostgreSQL

```bash
sudo apt install -y postgresql
sudo systemctl status postgresql --no-pager
```

### 4.2 Agregar el repositorio de Zabbix

```bash
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb
sudo apt update
```

> Si la URL no existe, entra a `zabbix.com/download`, elige tu combinación y copia el enlace que muestra la página.

### 4.3 Instalar servidor, frontend y agente

```bash
sudo apt install -y zabbix-server-pgsql zabbix-frontend-php php8.3-pgsql \
  zabbix-nginx-conf zabbix-sql-scripts zabbix-agent2 zabbix-get
```

Anota la versión instalada:

```bash
zabbix_server -V | head -1
```

### 4.4 Crear la base de datos

```bash
sudo -u postgres createuser --pwprompt zabbix
sudo -u postgres createdb -O zabbix zabbix
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql zabbix
```

Verifica que se crearon las tablas:

```bash
sudo -u zabbix psql zabbix -c '\dt' | head -15
```

> En Zabbix 8.0 el script SQL está en `/usr/share/zabbix/sql-scripts/`. Si algo no existe, busca con: `dpkg -L zabbix-sql-scripts`.

### 4.5 Configurar el servidor

```bash
sudo nano /etc/zabbix/zabbix_server.conf
```

Descomenta y define:

```
DBPassword=<PASSWORD_DB>
```

(Deja `DBHost`, `DBName=zabbix`, `DBUser=zabbix` por defecto.)

### 4.6 Configurar Nginx

```bash
sudo nano /etc/zabbix/nginx.conf
```

Descomenta y ajusta (usa el puerto 80 para empezar; en la fase 8 pasarás a HTTPS):

```
listen 80;
server_name zbx-srv;
```

Quita el sitio por defecto de Nginx, que si no responde en su lugar:

```bash
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
```

### 4.7 Configurar el agente local

```bash
sudo nano /etc/zabbix/zabbix_agent2.conf
```

Verifica:

```
Server=127.0.0.1
ServerActive=127.0.0.1
Hostname=zbx-srv
```

### 4.8 Iniciar y habilitar

```bash
sudo systemctl restart zabbix-server zabbix-agent2 nginx php8.3-fpm
sudo systemctl enable zabbix-server zabbix-agent2 nginx php8.3-fpm
systemctl status zabbix-server --no-pager
```

### 4.9 Asistente web

1. Abre `http://192.168.1.20/` desde tu PC.
2. Idioma: Español (o English; las capturas del repo deben ser coherentes).
3. Verifica los prerrequisitos (todo en OK).
4. Base de datos: PostgreSQL, host `localhost`, puerto `0` (por defecto), BD `zabbix`, usuario `zabbix`, contraseña.
5. Nombre del servidor: `zbx-srv`; zona horaria `America/Santiago`.
6. Finalizar. Usuario inicial: `Admin`; contraseña inicial: `zabbix`.

> **Cambia inmediatamente la contraseña de `Admin`.** (Se hace en el siguiente paso.)

### 4.10 Primer endurecimiento de la interfaz

En **Users → Users**:
1. Cambia la contraseña de `Admin` por una larga y única.
2. Crea tu usuario personal (por ejemplo `tunombre`) con rol **Super admin role** y úsalo a diario; deja `Admin` para emergencias.
3. Deshabilita el usuario `guest` (agrégalo al grupo *Disabled*).

### 4.11 Verificar el host `zbx-srv`

En **Data collection → Hosts** debería aparecer **Zabbix server** (host por defecto). Edítalo:
- Nombre del host: `zbx-srv` (debe coincidir con `Hostname` del agente).
- Interfaz de agente: `127.0.0.1:10050`.
- Plantillas: *Zabbix server health* y *Linux by Zabbix agent*.

En **Monitoring → Latest data**, filtra por `zbx-srv` y espera 1 a 2 minutos a que aparezcan valores.

## 5. Verificación

| Prueba | Comando / acción | Resultado esperado |
|---|---|---|
| Servicios activos | `systemctl is-active zabbix-server zabbix-agent2 nginx postgresql php8.3-fpm` | 5 × `active` |
| Puertos | `sudo ss -tlnp \| grep -E '10050\|10051\|:80'` | Escuchando |
| Log del servidor | `sudo tail -n 20 /var/log/zabbix/zabbix_server.log` | Sin errores de BD |
| Agente responde | `zabbix_get -s 127.0.0.1 -k agent.ping` | `1` |
| Interfaz web | `http://192.168.1.20/` | Panel de Zabbix |
| Disponibilidad del host | *Hosts* → columna ZBX | Verde |
| Cola | *Administration → Queue* | Sin elementos retrasados |

Captura sugerida: `assets/fase2/01-hosts-zbx-srv-verde.png`, `assets/fase2/02-latest-data.png`.

Respaldo: haz una copia de seguridad de la base recién instalada (ver script en la [fase 8](08-seguridad-y-respaldo.md)); así tienes un punto de retorno.

## 6. Problemas encontrados

| Síntoma | Causa | Solución |
|---|---|---|
| Aparece la página de Nginx por defecto | Sitio `default` activo | `sudo rm /etc/nginx/sites-enabled/default` y `sudo systemctl restart nginx` |
| 502 Bad Gateway | PHP-FPM no corre o versión distinta | `systemctl status php8.3-fpm`; revisar `fastcgi_pass` en `/etc/zabbix/nginx.conf` |
| El asistente dice "no se puede conectar a la BD" | Contraseña distinta o falta `php8.3-pgsql` | Probar `psql -h localhost -U zabbix zabbix`; instalar el paquete |
| `zabbix-server` no arranca | `DBPassword` vacía | Editar `/etc/zabbix/zabbix_server.conf` y reiniciar |

## 7. Lo que aprendí

- _(completar)_

## 8. Siguiente paso

[Fase 3: Agentes en Linux y Windows](03-agentes-linux-y-windows.md)
