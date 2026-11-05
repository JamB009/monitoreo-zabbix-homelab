# Fase 10 (opcional): Grafana con Zabbix

> **Fecha:** _AAAA-MM-DD_ · **Estado:** ⬜
>
> **Aviso:** esta fase es opcional y los pasos de instalación de Grafana cambian entre versiones. Antes de ejecutar, revisa la documentación oficial de Grafana (instalación en Debian/Ubuntu y plugin de Zabbix) y adapta lo que haga falta. Si tu laptop ya va justo de recursos, sáltala.

## 1. Objetivo

Visualizar los datos de Zabbix con Grafana para paneles más flexibles y para mostrar compatibilidad con un stack de observabilidad muy utilizado.

## 2. Conceptos clave

- **Grafana:** herramienta de visualización; no recoge datos por sí misma, los lee de *data sources*.
- **Plugin de Zabbix para Grafana:** conecta Grafana con la API de Zabbix para leer items, triggers y problemas.
- **Cuenta de API de solo lectura:** Grafana debe usar un usuario de Zabbix con permisos mínimos.

## 3. Requisitos previos

- [ ] Fases 1 a 8 completadas
- [ ] RAM libre suficiente (Grafana usa en torno a 100 a 300 MB; revisa con `free -h`)
- [ ] Usuario de Zabbix de solo lectura (fase 8: `invitado-lab` o uno específico `grafana-ro`)

## 4. Procedimiento (resumen)

### 4.1 Instalar Grafana OSS

Sigue la guía oficial para Ubuntu (repositorio APT de Grafana). A modo de referencia:

```bash
sudo apt install -y apt-transport-https software-properties-common wget
sudo mkdir -p /etc/apt/keyrings
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt update
sudo apt install -y grafana
sudo systemctl enable --now grafana-server
```

Por defecto escucha en el puerto `3000`. Permite el acceso **solo desde tu PC**:

```bash
sudo ufw allow from 192.168.1.10 to any port 3000 proto tcp
```

Primer acceso: `http://192.168.1.20:3000/` (usuario `admin`, contraseña inicial `admin`; cámbiala de inmediato).

### 4.2 Instalar el plugin de Zabbix

```bash
sudo grafana cli plugins install alexanderzobnin-zabbix-app
sudo systemctl restart grafana-server
```

En Grafana: **Administration → Plugins → Zabbix → Enable**.

### 4.3 Conectar con Zabbix

**Connections → Data sources → Add → Zabbix:**
- URL de la API: `https://zbx-srv/api_jsonrpc.php` (o `http://` si aún no activaste HTTPS)
- Usuario y contraseña del usuario de solo lectura (o token de API)
- Si usas certificado autofirmado, habilita la opción de omitir verificación **solo** para el laboratorio y documéntalo

### 4.4 Paneles sugeridos

1. Uso de CPU y memoria de AD-1 y AD-2.
2. Latencia ICMP.
3. Estado de servicios críticos (stat con *value mappings*).
4. Tabla de problemas activos.

Exporta el dashboard como JSON a `assets/exports/grafana-lab.json` (sin credenciales).

## 5. Verificación

| Prueba | Resultado esperado |
|---|---|
| Data source | "Zabbix API version" correcta al guardar |
| Panel de CPU | Datos del último periodo |
| Tabla de problemas | Coincide con *Monitoring → Problems* |

## 6. Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| Error de conexión a la API | URL o HTTPS autofirmado | Revisar URL; usar la opción de certificado solo en laboratorio |
| Sin permisos | Usuario sin acceso a los grupos de hosts | Dar lectura a `Lab/*` al usuario |

## 7. Lo que aprendí

- _(completar)_
