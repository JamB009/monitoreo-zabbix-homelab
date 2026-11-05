# Fase 1: Preparar el Ubuntu Server

> **Fecha:** _AAAA-MM-DD_ · **Estado:** ⬜

## 1. Objetivo

Dejar el servidor en una base estable y segura antes de instalar Zabbix: versión conocida, IP fija, hora correcta, firewall con reglas mínimas y acceso por llaves SSH.

## 2. Conceptos clave

- **IP fija:** si cambia la IP del servidor, los agentes dejan de encontrarlo.
- **Hora (NTP):** los gráficos, triggers y registros dependen de la hora. Con la hora mal, las alertas se desordenan.
- **Mínima exposición:** solo se abren los puertos necesarios, y solo desde las IPs necesarias.

## 3. Requisitos previos

- [ ] Fase 0 completada
- [ ] Acceso al laptop con Ubuntu Server (por SSH o teclado)
- [ ] Copia de seguridad de lo importante que ya tenga el laptop

> Si ya hiciste el proyecto de hardening del Ubuntu Server (SSH por llaves, UFW, Fail2ban), este paso es solo verificar y ajustar las reglas de UFW.

## 4. Procedimiento

### 4.1 Identificar la versión

```bash
lsb_release -a
uname -r
hostnamectl
```

| Versión | Paquete de repositorio de Zabbix (ver fase 2) | Servicio PHP-FPM |
|---|---|---|
| Ubuntu 24.04 | `ubuntu24.04` | `php8.3-fpm` |
| Ubuntu 22.04 | `ubuntu22.04` | `php8.1-fpm` |

Anota la versión en `README.md`. Captura: `assets/fase1/01-lsb-release.png`.

### 4.2 Actualizar el sistema

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget vim ufw chrony fping snmp
sudo reboot
```

### 4.3 Nombre del equipo

```bash
sudo hostnamectl set-hostname zbx-srv
hostnamectl
```

Edita `/etc/hosts` para que `zbx-srv` apunte a su IP:

```bash
sudo nano /etc/hosts
# 192.168.1.20  zbx-srv
```

### 4.4 IP fija con Netplan

Primero identifica el nombre de la interfaz:

```bash
ip -br a
ls /etc/netplan/
```

Ejemplo para cable (ajustar nombres e IPs; **haz copia del archivo original**):

```bash
sudo cp /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.bak
sudo nano /etc/netplan/50-cloud-init.yaml
```

```yaml
network:
  version: 2
  ethernets:
    enp3s0:                 # tu interfaz
      dhcp4: false
      addresses: [192.168.1.20/24]
      routes:
        - to: default
          via: 192.168.1.1  # tu router
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
```

```bash
sudo netplan try      # aplica con reversión automática si pierdes conexión
sudo netplan apply
ip -br a
ping -c 3 1.1.1.1
```

> Si el laptop usa Wi-Fi, el archivo requiere la sección `wifis:` con SSID y contraseña. Usa cable siempre que sea posible. **No subas ese archivo al repositorio.**

### 4.5 Zona horaria y sincronización de hora

```bash
sudo timedatectl set-timezone America/Santiago
timedatectl
sudo systemctl enable --now chrony
chronyc tracking
```

Resultado esperado: `System clock synchronized: yes`.

### 4.6 Acceso SSH por llaves

Desde tu PC:

```bash
ssh-keygen -t ed25519 -C "zbx-srv"
ssh-copy-id usuario@192.168.1.20
ssh usuario@192.168.1.20   # debe entrar sin contraseña
```

Luego, en el servidor, desactiva la contraseña **solo después de comprobar que la llave funciona**:

```bash
sudo nano /etc/ssh/sshd_config.d/10-hardening.conf
```

```
PasswordAuthentication no
PermitRootLogin no
```

```bash
sudo sshd -t && sudo systemctl reload ssh
```

### 4.7 Firewall (UFW) con reglas mínimas

Reemplaza las IPs por las tuyas. **Mantén abierta otra sesión SSH mientras lo haces.**

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH solo desde tu PC
sudo ufw allow from 192.168.1.10 to any port 22 proto tcp

# Interfaz web solo desde tu PC (se ajustará en la fase 2/8)
sudo ufw allow from 192.168.1.10 to any port 80 proto tcp
sudo ufw allow from 192.168.1.10 to any port 443 proto tcp

# Agentes activos hacia el servidor (puerto 10051), una regla por agente
sudo ufw allow from 192.168.1.201 to any port 10051 proto tcp
sudo ufw allow from 192.168.1.202 to any port 10051 proto tcp
sudo ufw allow from 192.168.1.203 to any port 10051 proto tcp

sudo ufw enable
sudo ufw status numbered
```

### 4.8 Actualizaciones de seguridad automáticas

```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

## 5. Verificación

| Prueba | Comando | Resultado esperado |
|---|---|---|
| Versión de Ubuntu | `lsb_release -d` | Anotada en el README |
| IP fija | `ip -br a` | `192.168.1.20/24` |
| Salida a internet | `curl -sI https://api.telegram.org \| head -1` | `HTTP/2 302` o similar (hay conexión) |
| Hora sincronizada | `timedatectl` | `synchronized: yes`, zona Santiago |
| SSH por llaves | Intentar con contraseña desde otro equipo | Rechazado |
| Firewall | `sudo ufw status` | Activo con las reglas definidas |

Snapshot o respaldo: si el laptop no es virtual, copia `/etc/netplan`, `/etc/ssh/sshd_config.d` y `ufw status` a una nota privada (no al repo).

## 6. Problemas encontrados

| Síntoma | Causa | Solución |
|---|---|---|
| Perdí la conexión SSH tras `ufw enable` | Regla de SSH con IP equivocada | Acceder por teclado y corregir: `sudo ufw allow from <IP> to any port 22` |
| `netplan apply` rompe la red | YAML con espacios mal | Usar `netplan try`; restaurar el `.bak` |

## 7. Lo que aprendí

- _(completar)_

## 8. Siguiente paso

[Fase 2: Instalar Zabbix server](02-instalar-zabbix.md)
