# Fase 7: Dashboards, mapas y SLA

> **Fecha:** _AAAA-MM-DD_ · **Estado:** ⬜

## 1. Objetivo

Mostrar el estado del laboratorio de un vistazo: un panel para operación, un mapa de la infraestructura y un SLA mensual del servicio "Dominio lab.local".

## 2. Conceptos clave

- **Dashboard:** conjunto de *widgets* (problemas, gráficos, valores, disponibilidad).
- **Mapa:** diagrama de hosts con su estado en color y enlaces.
- **Servicio y SLA:** un servicio de negocio (por ejemplo "Autenticación del dominio") se compone de otros servicios y se mide contra un objetivo (SLO), por ejemplo 99 % mensual.
- **Un buen panel responde preguntas:** ¿hay algo roto?, ¿qué es lo más urgente?, ¿hay tendencias preocupantes?

## 3. Requisitos previos

- [ ] Fases 3 a 6 completadas con datos acumulados de al menos 1 a 2 días

## 4. Procedimiento

### 4.1 Dashboard "Estado del laboratorio"

**Dashboards → Create dashboard** → `Estado del laboratorio`. Widgets sugeridos (nombres según tu versión):

| Widget | Configuración | Para qué |
|---|---|---|
| **Problems** | Mostrar abiertos, severidad Warning o más, grupos `Lab/*` | Lo urgente |
| **Host availability** | Todos los hosts | Estado de agentes |
| **Top hosts** | Columnas: CPU, memoria libre, disco libre | Quién está más cargado |
| **Graph** | CPU de AD-1 y AD-2 (últimas 6 h) | Tendencia |
| **Item value** | `ad.repl.failures` de AD-1 y AD-2 | Replicación en un número |
| **Item value** | Servicios DNS/NTDS (valor mapeado) | Estado de servicios críticos |
| **Graph** | Latencia ICMP (`icmppingsec`) | Calidad de red |
| **Clock** | Hora de Santiago | Referencia visual |

Buenas prácticas: máximo 8 a 10 widgets; sin scroll excesivo; títulos claros; mismos colores que la severidad.

### 4.2 Dashboard de seguridad

`Seguridad del laboratorio`:
- **Problems** filtrados por tag `capa:seguridad`.
- **Graph** o tabla de eventos de las últimas 24 h.
- **Top hosts** por intentos fallidos (si agregas un item numérico calculado).

### 4.3 Mapa de la infraestructura

**Monitoring → Maps → Create map** → `Laboratorio`:
1. Agrega `zbx-srv`, `AD-1`, `AD-2`, `CLIENTE-01` como elementos de tipo *Host*.
2. Une con enlaces (links) y, si quieres, agrega un indicador por trigger (por ejemplo, el enlace se pone rojo si `Unavailable by ICMP ping` está activo).
3. Etiquetas con nombre e IP.
4. Usa un fondo simple (imagen opcional) y deja el mapa legible.

### 4.4 Servicios y SLA

**Services → Services → Create service:**

```
Dominio lab.local
├── Autenticación (AD-1 o AD-2)
│   ├── AD-1: servicios de AD
│   └── AD-2: servicios de AD
├── Resolución DNS
└── Replicación de AD
```

- Define reglas por *Problem tags* (por ejemplo `servicio:ad`) para que los triggers etiquetados afecten al servicio.
- Para "Autenticación", configura la **regla de estado**: el servicio solo cae si **ambos** hijos están en problema (concepto de redundancia).

**Services → SLA → Create SLA:** `Disponibilidad lab.local`, SLO `99%`, periodo mensual, horario 24x7. Asócialo al servicio raíz.

Tras unos días, revisa **Services → SLA report** y captura el resultado.

### 4.5 Presentación (modo kiosko)

Abre el dashboard y usa el modo de pantalla completa (kiosk). Úsalo para capturas limpias y para grabar un GIF corto de 10 segundos para LinkedIn.

### 4.6 Exportar para versionar

Exporta las plantillas propias y, si tu versión lo permite, la definición del dashboard/mapa; guárdalas en `assets/exports/`. Si no puedes exportar un widget, deja capturas numeradas en `assets/fase7/`.

## 5. Verificación

| Prueba | Resultado esperado |
|---|---|
| Panel con datos reales | Sin widgets vacíos |
| Apagar AD-2 | El panel muestra el problema y el mapa cambia de color |
| Servicio "Autenticación" | Sigue en verde con un DC caído; rojo solo si caen ambos |
| SLA | Porcentaje calculado y coherente con los incidentes reales |

Capturas: `assets/fase7/01-dashboard-estado.png`, `assets/fase7/02-mapa.png`, `assets/fase7/03-sla.png`.

## 6. Problemas encontrados

| Síntoma | Causa | Solución |
|---|---|---|
| Widget "Top hosts" vacío | Items sin datos recientes o clave distinta | Revisar nombres de items y filtros por grupo |
| El servicio no cambia de estado | Falta etiquetar los triggers | Agregar tags y reglas del servicio |
| SLA en 100 % siempre | Sin vincular triggers | Revisar reglas de problema del servicio |

## 7. Lo que aprendí

- _(completar)_

## 8. Siguiente paso

[Fase 8: Seguridad y respaldo de Zabbix](08-seguridad-y-respaldo.md)
