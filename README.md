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
.env.example              # Template de configuracion
.env                      # Configuracion local (gitignored)
builder-config.yaml       # Componentes a compilar en el binario (OCB manifest)
collector-config.yaml     # Configuracion de runtime del collector (local)
Dockerfile                # Build multi-stage: certs -> Go build -> distroless
docker-compose.yml        # Orquestacion con variables de .env (local)
install.sh                # Script de instalacion local
status.sh                 # Script de estado local
stop.sh                   # Script de parada local
terraform/                # Infraestructura como codigo (Azure)
collector-configs/        # Configuraciones del collector por ambiente
.github/                  # CI/CD pipelines (GitHub Actions)
```

## Enviar datos de prueba

Con el collector corriendo, puedes enviar datos de prueba via HTTP (puerto 4318):

### Enviar traces

```bash
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [
          { "key": "service.name", "value": { "stringValue": "mi-servicio-test" } },
          { "key": "service.version", "value": { "stringValue": "1.0.0" } }
        ]
      },
      "scopeSpans": [{
        "scope": { "name": "test-scope" },
        "spans": [{
          "traceId": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4",
          "spanId": "b1c2d3e4f5a6b1c2",
          "name": "GET /api/users",
          "kind": 2,
          "startTimeUnixNano": "1700000000000000000",
          "endTimeUnixNano": "1700000000500000000",
          "attributes": [
            { "key": "http.method", "value": { "stringValue": "GET" } },
            { "key": "http.status_code", "value": { "intValue": "200" } },
            { "key": "http.url", "value": { "stringValue": "https://api.example.com/users" } }
          ],
          "status": { "code": 1 }
        }]
      }]
    }]
  }'
```

### Enviar metricas

```bash
curl -X POST http://localhost:4318/v1/metrics \
  -H "Content-Type: application/json" \
  -d '{
    "resourceMetrics": [{
      "resource": {
        "attributes": [
          { "key": "service.name", "value": { "stringValue": "mi-servicio-test" } }
        ]
      },
      "scopeMetrics": [{
        "scope": { "name": "test-scope" },
        "metrics": [{
          "name": "http.request.duration",
          "unit": "ms",
          "gauge": {
            "dataPoints": [{
              "asDouble": 125.5,
              "timeUnixNano": "1700000000000000000",
              "attributes": [
                { "key": "http.method", "value": { "stringValue": "GET" } },
                { "key": "http.route", "value": { "stringValue": "/api/users" } }
              ]
            }]
          }
        }]
      }]
    }]
  }'
```

### Enviar logs

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [
          { "key": "service.name", "value": { "stringValue": "mi-servicio-test" } }
        ]
      },
      "scopeLogs": [{
        "scope": { "name": "test-scope" },
        "logRecords": [{
          "timeUnixNano": "1700000000000000000",
          "severityNumber": 9,
          "severityText": "INFO",
          "body": { "stringValue": "Usuario login exitoso: user_id=12345, ip=192.168.1.100" },
          "attributes": [
            { "key": "event.name", "value": { "stringValue": "user.login" } },
            { "key": "user.id", "value": { "stringValue": "12345" } }
          ]
        }]
      }]
    }]
  }'
```

Los datos recibidos apareceran en los logs del collector con detalle completo (`bash status.sh`).

> **Tip:** Para enviar datos via gRPC (puerto 4317), usa cualquier SDK de OpenTelemetry apuntando a `localhost:4317`.

## Despliegue automatico en Azure

El proyecto incluye Terraform y GitHub Actions para desplegar automaticamente en **Azure Container Apps** con tres ambientes: dev, qa y prod, usando GitFlow.

### Arquitectura

```
feature/* ──► develop ──► release/* ──► main
                │              │           │
              CI+CD          CI+CD       CI+CD
                │              │           │
              ┌─▼─┐        ┌──▼──┐     ┌──▼──┐
              │DEV│        │ QA  │     │PROD │ (approval)
              └───┘        └─────┘     └─────┘
```

Cada ambiente tiene su propio ACR, Container App y Log Analytics Workspace.

### Paso 1: Prerequisitos

- Repositorio en GitHub con permisos de administrador
- Una suscripcion de Azure activa

> **No se necesita instalar Terraform ni Azure CLI localmente.** Todo se ejecuta desde GitHub Actions.

### Paso 2: Configurar GitHub Environments y Secrets

En tu repositorio de GitHub, ve a **Settings > Environments** y crea tres environments:

| Environment | Proteccion |
|---|---|
| `dev` | Sin restricciones |
| `qa` | Opcional: restringir a ramas `release/*` |
| `prod` | **Required reviewers** (aprobacion manual obligatoria) |

En cada environment, configura estos **secrets**:

| Secret | Descripcion | Ejemplo |
|---|---|---|
| `AZURE_CLIENT_ID` | App ID de la App Registration | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_TENANT_ID` | Tenant ID de Azure AD | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_SUBSCRIPTION_ID` | ID de la suscripcion Azure | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `ACR_LOGIN_SERVER` | Login server del ACR del ambiente | `acrotelcoldev.azurecr.io` |
| `OTLP_EXPORT_ENDPOINT` | Endpoint OTLP destino | `https://otlp.example.com:4317` |
| `TLS_CLIENT_CERT` | Certificado TLS del cliente (base64) | Contenido de `client.crt` en base64 |
| `TLS_CLIENT_KEY` | Clave privada TLS del cliente (base64) | Contenido de `client.key` en base64 |
| `TLS_CA_CERT` | Certificado CA para verificacion TLS (base64) | Contenido de `ca.crt` en base64 |

> Para obtener `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` y `AZURE_SUBSCRIPTION_ID`, puedes ejecutar el workflow **"Setup Azure OIDC"** (ver paso 3).

### Paso 3: Configurar Azure AD (OIDC) desde GitHub Actions

El workflow `setup-azure-oidc.yml` crea automaticamente la App Registration con federated credentials. **No necesitas Azure CLI local.**

1. Ve a **Actions > Setup Azure OIDC** en tu repositorio
2. Click en **Run workflow**
3. Ingresa tu repositorio en formato `owner/repo` (ej: `miguelsff/opentelemetry-custom-collector`)
4. Click en **Run workflow**

El workflow creara:
- App Registration en Azure AD
- Service Principal con rol Contributor
- Federated credentials para las ramas `develop`, `release/*` y `main`

Al finalizar, revisa los logs del workflow para obtener los valores de `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` y `AZURE_SUBSCRIPTION_ID` que debes configurar como secrets en el paso 2.

> **Nota:** Para la primera ejecucion necesitas tener al menos un secret `AZURE_CLIENT_ID` temporal con permisos de Azure AD admin. Despues puedes reemplazarlo con el valor generado.

### Paso 4: Crear la infraestructura desde GitHub Actions

El workflow `bootstrap.yml` crea toda la infraestructura de Azure sin necesidad de herramientas locales:

1. Ve a **Actions > Bootstrap Infrastructure** en tu repositorio
2. Click en **Run workflow**
3. Selecciona:
   - **action**: `apply`
   - **environment**: `all` (o un ambiente especifico)
4. Click en **Run workflow**

Esto crea automaticamente para cada ambiente:
- Storage Account para Terraform state (solo la primera vez)
- Resource Group
- Azure Container Registry (ACR)
- Log Analytics Workspace
- Container Apps Environment
- Container App con health probes y managed identity

Para destruir la infraestructura, ejecuta el mismo workflow con action `destroy`.

### Paso 5: Crear la rama develop

```bash
git checkout -b develop
git push -u origin develop
```

### Paso 6: Flujo GitFlow

#### Desarrollo (feature -> dev)

```bash
# Crear feature branch
git checkout develop
git checkout -b feature/mi-cambio

# ... hacer cambios, commits ...

# Merge a develop (dispara deploy a dev)
git checkout develop
git merge feature/mi-cambio
git push origin develop
```

El push a `develop` ejecuta automaticamente el pipeline `CI/CD: Dev`:
1. **Preparation** - Metadata y trazabilidad
2. **Build & Test** - Lint (Hadolint + Terraform fmt) + Docker build + health check
3. **SAST Analysis** - Escaneo de seguridad estatico (Fortify)
4. **QA Analysis** - Calidad de codigo (SonarQube)
5. **Upload Artifacts** - Build y push a ACR
6. **SCA Analysis** - Analisis de dependencias (JFrog Xray)
7. **Deploy** - `terraform apply` con `dev.tfvars`

#### QA (release -> qa)

```bash
# Crear release branch desde develop
git checkout develop
git checkout -b release/1.0.0
git push -u origin release/1.0.0
```

El push a `release/*` ejecuta el pipeline `CI/CD: Cert (QA)`, que ademas crea un tag de release candidate (RC-) antes de los stages CI/CD.

#### Produccion (main -> prod)

```bash
# Merge release a main
git checkout main
git merge release/1.0.0
git push origin main
```

El push a `main` ejecuta el pipeline `CI/CD: Prod`, que **promueve la imagen de QA** (retag, sin rebuild) y despliega a produccion. Requiere **aprobacion manual** via GitHub Environment protection rules.

### Configuracion por ambiente

Los recursos de cada ambiente se configuran en `terraform/environments/`:

| Recurso | dev | qa | prod |
|---|---|---|---|
| CPU | 0.25 cores | 0.5 cores | 1.0 cores |
| Memoria | 0.5 Gi | 1 Gi | 2 Gi |
| Replicas min | 0 | 1 | 2 |
| Replicas max | 1 | 2 | 5 |
| ACR SKU | Basic | Basic | Standard |

### Configuracion del collector por ambiente

Los archivos `collector-configs/{dev,qa,prod}.yaml` usan variables de entorno como placeholders:

```yaml
exporters:
  otlp:
    endpoint: ${env:OTLP_EXPORT_ENDPOINT}
    tls:
      cert_file: /certs/client.crt
      key_file: /certs/client.key
      ca_file: /certs/ca.crt
```

Los certificados mTLS se montan como volumen de secrets en el Container App via Terraform. Los valores se configuran como secrets base64 en los GitHub Environments.

Para generar los valores base64 de los certificados:

```bash
base64 -w 0 client.crt  # -> usar como TLS_CLIENT_CERT
base64 -w 0 client.key  # -> usar como TLS_CLIENT_KEY
base64 -w 0 ca.crt      # -> usar como TLS_CA_CERT
```

### Estructura del despliegue

```
terraform/
  bootstrap/             # Setup unico: storage para TF state
  modules/
    acr/                 # Azure Container Registry por ambiente
    monitoring/          # Log Analytics Workspace
    container-app/       # Container App + Identity + Health probes
  environments/
    dev.tfvars           # Sizing para dev
    qa.tfvars            # Sizing para qa
    prod.tfvars          # Sizing para prod
.github/
  actions/                          # Composite actions por stage
    prepare/                        # Checkout + metadata trazabilidad
    docker-build-test/              # Build image + health check test
    docker-build-push/              # Build + push a ACR (con OCI labels)
    sast-fortify/                   # SAST scan (Fortify placeholder)
    qa-sonarqube/                   # QA analysis (SonarQube placeholder)
    sca-xray/                       # SCA scan (JFrog Xray placeholder)
    terraform-deploy/               # Terraform init + plan + apply
    vault-secrets/                  # Secret retrieval (Vault placeholder)
  workflows/
    # Reusable workflows (llamados via workflow_call)
    _prepare.yml                    # Stage: Preparation
    _build-test.yml                 # Stage: Build & Unit Test
    _sast-analysis.yml              # Stage: SAST Analysis
    _qa-analysis.yml                # Stage: QA Analysis
    _upload-artifacts.yml           # Stage: Upload Artifacts (push a ACR)
    _sca-analysis.yml               # Stage: SCA Analysis
    _deploy.yml                     # Stage: Deploy (Terraform)
    _start-release.yml              # Stage: Start Release (RC tag)
    _promote-release.yml            # Stage: Promote Release (retag qa->prod)
    # Dispatchers (orquestadores con triggers)
    ci-docker-pr.yml                # PR validation (CI stages only)
    ci-cd-docker-dev.yml            # develop -> dev (CI + CD)
    ci-cd-docker-cert.yml           # release/* -> qa (CI + CD)
    ci-cd-docker-prod.yml           # main -> prod (promote + CD)
    # Setup (manuales, una vez)
    setup-azure-oidc.yml            # Configura Azure AD + OIDC
    bootstrap.yml                   # Crea/destruye infra completa
collector-configs/
  dev.yaml               # Config con env vars para dev
  qa.yaml                # Config con env vars para qa
  prod.yaml              # Config con env vars para prod
```
