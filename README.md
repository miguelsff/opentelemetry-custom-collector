# OpenTelemetry Custom Collector

Custom OpenTelemetry Collector built with [OCB](https://opentelemetry.io/docs/collector/extend/ocb/) (OpenTelemetry Collector Builder), empaquetado en Docker con imagen distroless minimal.

## Requisitos previos

- [Docker](https://docs.docker.com/get-docker/) (con Docker Compose V2)
- [curl](https://curl.se/) (para el health check en `status.sh`)
- Bash (Git Bash en Windows)

## Inicio rapido

```bash
# 1. Clonar el repositorio
git clone https://github.com/miguelsff/opentelemetry-custom-collector.git
cd opentelemetry-custom-collector

# 2. Crear el archivo de configuracion
cp .env.example .env

# 3. (Opcional) Editar .env para cambiar puertos, versiones, etc.

# 4. Construir y levantar el collector
bash install.sh

# 5. Verificar que esta corriendo
bash status.sh

# 6. Cuando quieras pararlo
bash stop.sh
```

## Configuracion (.env)

Toda la configuracion se maneja desde el archivo `.env`:

| Variable | Default | Descripcion |
|---|---|---|
| `COLLECTOR_NAME` | `otelcol-custom` | Nombre del binario |
| `COLLECTOR_IMAGE_NAME` | `otelcol-custom` | Nombre de la imagen Docker |
| `COLLECTOR_CONTAINER_NAME` | `otelcol-custom` | Nombre del contenedor |
| `GO_VERSION` | `1.25.8` | Version de Go para compilar |
| `OCB_VERSION` | `0.148.0` | Version del builder OCB |
| `OTEL_CORE_VERSION` | `0.148.0` | Version de modulos core de OTel |
| `OTEL_CONFMAP_VERSION` | `1.48.0` | Version de confmap providers |
| `OTEL_GRPC_PORT` | `4317` | Puerto gRPC (host) |
| `OTEL_HTTP_PORT` | `4318` | Puerto HTTP (host) |
| `OTEL_HEALTH_PORT` | `13133` | Puerto health check (host) |
| `DEBUG_VERBOSITY` | `detailed` | Nivel de detalle del debug exporter |

## Componentes incluidos

Definidos en `builder-config.yaml`:

| Tipo | Componente | Descripcion |
|---|---|---|
| Receiver | `otlpreceiver` | Recibe traces, metricas y logs via OTLP (gRPC + HTTP) |
| Processor | `batchprocessor` | Agrupa datos en lotes para envio eficiente |
| Exporter | `debugexporter` | Imprime datos en los logs del collector |
| Exporter | `otlpexporter` | Reenvia datos via OTLP a otro backend |
| Extension | `healthcheckextension` | Endpoint HTTP de salud en puerto 13133 |

## Agregar componentes

1. Editar `builder-config.yaml` y agregar el modulo bajo la seccion correspondiente:

```yaml
receivers:
  - gomod: go.opentelemetry.io/collector/receiver/otlpreceiver v0.148.0
  # Agregar nuevo receiver:
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/prometheusreceiver v0.148.0
```

2. Configurar el componente en `collector-config.yaml`:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
  # Configurar el nuevo receiver:
  prometheus:
    config:
      scrape_configs:
        - job_name: 'my-app'
          static_configs:
            - targets: ['app:8080']
```

3. Reconstruir: `bash stop.sh && bash install.sh`

El catalogo completo de componentes esta en el [OpenTelemetry Registry](https://opentelemetry.io/ecosystem/registry/?language=collector).

## Scripts

| Script | Descripcion |
|---|---|
| `install.sh` | Verifica puertos disponibles, construye la imagen Docker y levanta el collector |
| `status.sh` | Muestra estado del contenedor, salud, endpoints, uso de recursos y logs recientes |
| `stop.sh` | Detiene y elimina el contenedor |

## Estructura del proyecto

```
.env.example           # Template de configuracion
.env                   # Configuracion local (gitignored)
builder-config.yaml    # Componentes a compilar en el binario (OCB manifest)
collector-config.yaml  # Configuracion de runtime del collector
Dockerfile             # Build multi-stage: certs -> Go build -> distroless
docker-compose.yml     # Orquestacion con variables de .env
install.sh             # Script de instalacion
status.sh              # Script de estado
stop.sh                # Script de parada
```

## Enviar datos de prueba

Con el collector corriendo, puedes enviar traces de prueba:

```bash
# Via gRPC (puerto 4317)
# Usa cualquier SDK de OpenTelemetry apuntando a localhost:4317

# Via HTTP (puerto 4318)
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[]}'
```

Los datos recibidos apareceran en los logs del collector (`bash status.sh`).
