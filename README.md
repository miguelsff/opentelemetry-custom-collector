# OpenTelemetry Custom Collector

Custom OpenTelemetry Collector built with [OCB](https://opentelemetry.io/docs/collector/extend/ocb/) (OpenTelemetry Collector Builder), empaquetado en Docker con imagen distroless minimal.

## Requisitos previos

- [Docker](https://docs.docker.com/get-docker/) (con Docker Compose V2)
- [curl](https://curl.se/) (para el health check en `status.sh`)
- Bash (Git Bash en Windows)

## Inicio rapido

```bash
# 1. Clonar el repositorio
git clone https://github.com/NOMBRE_ORGANIZACION/opentelemetry-custom-collector.git
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

### Como funciona

Cada vez que haces push a ciertas ramas, GitHub Actions ejecuta el pipeline automaticamente:

```
feature/* ──► develop ──► release/* ──► main
                │              │           │
              CI+CD          CI+CD       CI+CD
                │              │           │
              ┌─▼─┐        ┌──▼──┐     ┌──▼──┐
              │DEV│        │ QA  │     │PROD │ (requiere aprobacion)
              └───┘        └─────┘     └─────┘
```

El pipeline por cada ambiente corre estos stages en orden:
1. **Preparation** - Registra metadata (autor, rama, commit, fecha)
2. **Build & Test** - Compila la imagen Docker y verifica que arranque
3. **SAST** - Escaneo de seguridad del codigo fuente (Fortify)
4. **QA** - Analisis de calidad del codigo (SonarQube)
5. **Upload** - Sube la imagen a Azure Container Registry
6. **SCA** - Escaneo de vulnerabilidades en dependencias (JFrog Xray)
7. **Deploy** - Despliega la infraestructura y la imagen en Azure

Cada ambiente tiene su propio ACR, Container App y Log Analytics Workspace.

---

### Configuracion inicial (solo la primera vez)

Antes de que los pipelines funcionen, necesitas conectar GitHub con tu cuenta de Azure. Esto se hace **una sola vez** siguiendo estos pasos en orden.

#### Paso 1: Crear los Service Principals en Azure

Se crea una identidad (Service Principal) por cada ambiente para que GitHub Actions pueda autenticarse en Azure. Siguiendo la nomenclatura organizacional:

| Campo | Significado |
|---|---|
| `SVPR` | Prefijo fijo para Service Principals |
| `OTEL` | Codigo del aplicativo (OTel Collector) |
| `APP` | Identidad de aplicacion |
| `DES / CER / PRO` | Ambiente (desarrollo / certificacion / produccion) |
| `01` | Numero correlativo |

Los tres Service Principals que vas a crear son:

| Ambiente | Nombre | Rama de GitHub |
|---|---|---|
| Dev | `SVPROTELAPPDES01` | `develop` |
| QA | `SVPROTELAPPCER01` | `release/*` |
| Prod | `SVPROTELAPPPRO01` | `main` |

Usa **Azure Cloud Shell** — el terminal que viene integrado en el portal web, no necesitas instalar nada en tu computadora.

**Como abrir Azure Cloud Shell:**
1. Ve a [portal.azure.com](https://portal.azure.com) e inicia sesion
2. Click en el icono `>_` en la barra superior (o presiona `Ctrl+~`)
3. Selecciona **Bash** si te pregunta el tipo de terminal

Ejecuta el script **3 veces**, cambiando las variables al inicio en cada ejecucion:

```bash
# ============================================================
# Ejecutar en Azure Cloud Shell (portal.azure.com > icono >_)
# Cambiar estas 3 variables en cada ejecucion:
# ============================================================
servicePrincipalName="SVPROTELAPPDES01"  # DES01 | CER01 | PRO01
years=2
secretName="${servicePrincipalName}_secret"     # _secret por ambiente
# ============================================================

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# Crea el Service Principal
servicePrincipalAppId=$(az ad sp create-for-rbac \
  --name "$servicePrincipalName" \
  --skip-assignment \
  --years $years \
  --query appId -o tsv)

sleep 5

# Crea el secreto con nombre identificable
servicePrincipalSecret=$(az ad app credential reset \
  --id "$servicePrincipalAppId" \
  --years $years \
  --display-name "$secretName" \
  --query password -o tsv)

# Asigna permisos Contributor en la suscripcion
az role assignment create \
  --assignee "$servicePrincipalAppId" \
  --role Contributor \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

echo ""
echo "=== Guarda estos valores para GitHub Secrets ==="
echo "AZURE_CLIENT_ID:       $servicePrincipalAppId"
echo "AZURE_CLIENT_SECRET:   $servicePrincipalSecret"
echo "AZURE_TENANT_ID:       $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
```

Al terminar debes tener anotados estos valores para cada ambiente:

| | Dev | QA | Prod |
|---|---|---|---|
| `AZURE_CLIENT_ID` | ID de `SVPROTELAPPDES01` | ID de `SVPROTELAPPCER01` | ID de `SVPROTELAPPPRO01` |
| `AZURE_CLIENT_SECRET` | Secreto de `SVPROTELAPPDES01` | Secreto de `SVPROTELAPPCER01` | Secreto de `SVPROTELAPPPRO01` |
| `AZURE_TENANT_ID` | (mismo en los 3) | (mismo en los 3) | (mismo en los 3) |
| `AZURE_SUBSCRIPTION_ID` | (mismo en los 3) | (mismo en los 3) | (mismo en los 3) |

#### Paso 2: Guardar las credenciales en GitHub

GitHub necesita esos valores para poder hablarle a Azure cuando corra los pipelines. Se guardan como secrets dentro de cada "environment" (dev, qa, prod).

1. Ve a tu repositorio en GitHub
2. Click en **Settings** (arriba a la derecha)
3. En el menu izquierdo, click en **Environments**
4. Crea tres environments: `dev`, `qa`, `prod`
   - Para `prod`: activa **Required reviewers** y agrega tu usuario — esto hace que los deploys a produccion requieran aprobacion manual
5. Entra a cada environment y agrega estos secrets:

| Secret | De donde viene |
|---|---|
| `AZURE_CLIENT_ID` | El valor `AZURE_CLIENT_ID` del paso anterior |
| `AZURE_CLIENT_SECRET` | El valor `AZURE_CLIENT_SECRET` del paso anterior |
| `AZURE_TENANT_ID` | El valor `AZURE_TENANT_ID` del paso anterior |
| `AZURE_SUBSCRIPTION_ID` | El valor `AZURE_SUBSCRIPTION_ID` del paso anterior |
| `ACR_LOGIN_SERVER` | Lo obtendras despues del paso 3 (ej: `acrotelcoldev.azurecr.io`) |
| `OTLP_EXPORT_ENDPOINT` | URL de tu backend OTLP (ej: `https://otlp.tubackend.com:4317`) |
| `OTLP_BEARER_TOKEN` | Token de autenticacion Bearer para el backend OTLP |

> Por ahora agrega los primeros cuatro (`AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`). Los demas los agregas despues del paso 3.

#### Paso 3: Crear la infraestructura en Azure

Con las credenciales ya configuradas en GitHub, el workflow `bootstrap.yml` crea todos los recursos de Azure automaticamente (sin que necesites hacer nada en el portal de Azure ni instalar Terraform).

1. Ve a tu repositorio en GitHub
2. Click en **Actions**
3. En el menu izquierdo busca **Bootstrap Infrastructure**
4. Click en **Run workflow** (boton azul a la derecha)
5. Selecciona:
   - **action**: `apply`
   - **environment**: `all`
6. Click en **Run workflow**

Espera a que termine (tarda 5-10 minutos). Esto crea en Azure:
- Storage Account para guardar el estado de Terraform
- Resource Group por ambiente
- Azure Container Registry (ACR) — aqui se guardaran las imagenes Docker
- Log Analytics Workspace — para ver los logs de la aplicacion
- Container Apps Environment y Container App — donde corre el collector

Al terminar, busca en los logs el valor de `ACR_LOGIN_SERVER` para cada ambiente y agregalo como secret en el paso 2.

> Para encontrarlo: en el Portal de Azure busca "Container registries", entra al ACR del ambiente y copia el valor de **Login server**.

#### Paso 4: Crear la rama develop

```bash
git checkout -b develop
git push -u origin develop
```

> Esta rama es obligatoria: es el punto de entrada para el pipeline de dev.

### Paso 5: Flujo GitFlow

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

### Autenticacion Bearer token

El collector se autentica con el backend OTLP usando un Bearer token en el header `Authorization`. Tu proveedor OTLP (Grafana Cloud, Honeycomb, Datadog, etc.) te proporciona este token desde su panel de configuracion.

Guardalo como secret en cada GitHub Environment:

| Secret | Valor |
|---|---|
| `OTLP_BEARER_TOKEN` | El token tal cual lo proporciona tu backend (sin base64) |

Terraform lo inyecta automaticamente como variable de entorno dentro del Container App.

### Configuracion del collector por ambiente

Los archivos `collector-configs/{dev,qa,prod}.yaml` leen la configuracion desde variables de entorno que Terraform inyecta en el Container App:

```yaml
exporters:
  otlp:
    endpoint: ${env:OTLP_EXPORT_ENDPOINT}
    headers:
      Authorization: "Bearer ${env:OTLP_BEARER_TOKEN}"
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
    bootstrap.yml                   # Crea/destruye infra completa
collector-configs/
  dev.yaml               # Config con env vars para dev
  qa.yaml                # Config con env vars para qa
  prod.yaml              # Config con env vars para prod
```
