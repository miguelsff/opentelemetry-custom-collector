# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Local development commands

```bash
# Setup and run
cp .env.example .env
bash install.sh       # build Docker image and start container

# Operate
bash status.sh        # health check, resource usage, recent logs
bash stop.sh          # stop and remove container

# Send test telemetry (collector must be running)
curl -X POST http://localhost:4318/v1/traces -H "Content-Type: application/json" -d '{...}'
# (see README for full payloads)
```

There is no test suite. Validation is done via health check (`curl http://localhost:13133`) and by sending OTLP payloads and observing the debug exporter output in `bash status.sh`.

## Terraform commands

```bash
cd terraform

# Bootstrap state storage (once per project lifetime)
cd bootstrap && terraform init && terraform apply -auto-approve && cd ..

# Per-environment usage
terraform init -backend-config="key=dev.tfstate"
terraform plan -var-file=environments/dev.tfvars -var="image_tag=dev-abc1234" \
  -var="otlp_export_endpoint=..." -var="otlp_bearer_token=..." ...
terraform apply tfplan
```

Terraform state lives in Azure Blob Storage (`stotelcoltfstate` / `tfstate` container). Each environment has its own key: `dev.tfstate`, `qa.tfstate`, `prod.tfstate`.

## Architecture

### Two deployment paths

**Local (development iteration):**
`.env` → `docker-compose.yml` → uses `collector-config.yaml` (debug exporter, no OTLP export)

**Cloud (CI/CD):**
GitHub Actions → builds Docker image → pushes to Azure Container Registry → Terraform deploys to Azure Container Apps using environment-specific config from `collector-configs/{env}.yaml`

The key difference: `collector-config.yaml` (root) is the local/fallback config. `collector-configs/dev|qa|prod.yaml` are the cloud configs — the `docker-build-push` action copies the right one to `collector-config.yaml` before building the image for cloud deployment.

### GitHub Actions: 3-layer architecture

```
Dispatchers (ci-cd-docker-*.yml)
  → Reusable workflows (_*.yml, called via workflow_call)
    → Composite actions (.github/actions/*/action.yml)
```

- **Dispatchers** hold triggers and wire secrets/inputs between jobs. They never contain logic.
- **Reusable workflows** represent pipeline stages. They accept secrets via `workflow_call` and call composite actions.
- **Composite actions** contain the actual shell logic. Reusable across workflows.

### Pipeline stages per environment

| Stage | Dev | QA (release/*) | Prod (main) |
|---|---|---|---|
| Prepare | ✓ | ✓ | ✓ |
| Start Release | — | ✓ creates RC tag | — |
| Build & Test | ✓ | ✓ | — (skipped) |
| SAST / QA / SCA | ✓ | ✓ | — (skipped) |
| Upload to ACR | ✓ `dev-{sha}` | ✓ `qa-{sha}` | — |
| Promote | — | — | ✓ retags `qa-latest` → `prod-{sha}` |
| Deploy (Terraform) | ✓ | ✓ | ✓ |

Prod never rebuilds — it promotes the already-validated QA image via retag.

### Terraform module structure

```
terraform/
  bootstrap/           # One-time: creates Azure Blob Storage for TF state
  modules/
    acr/               # Azure Container Registry
    monitoring/        # Log Analytics Workspace (30-day dev/qa, 90-day prod)
    container-app/     # Container App + managed identity + ACR pull role + Bearer token secret + health probes
  environments/
    dev|qa|prod.tfvars # Per-env sizing (CPU/memory/replicas)
```

`main.tf` at root wires the three modules together. State backend is configured at `providers.tf` but the key is always overridden via `-backend-config="key={env}.tfstate"` at `terraform init` time.

### Azure authentication

All workflows use **client secret** authentication (`azure/login@v2` with `client-id`, `client-secret`, `tenant-id`, `subscription-id`). OIDC/federated credentials are **not used**. The `id-token: write` permission is not present in any workflow.

Each GitHub Environment (`dev`, `qa`, `prod`) holds its own set of Azure secrets for the corresponding Service Principal (`SVPROTELAPPDES01`, `SVPROTELAPPCER01`, `SVPROTELAPPPRO01`).

### Mocked/placeholder integrations

These composite actions are stubs — they generate fake JSON reports but do no real scanning:
- `.github/actions/sast-fortify/` — placeholder for Fortify SCA
- `.github/actions/qa-sonarqube/` — placeholder for SonarQube
- `.github/actions/sca-xray/` — placeholder for JFrog Xray
- `.github/actions/vault-secrets/` — placeholder for HashiCorp Vault (currently falls back to GitHub Secrets)

When integrating real tools, replace the shell logic in these actions without changing the input/output interface.

### OCI image labels and traceability

The `prepare` action extracts `commit-sha`, `short-sha`, `branch`, `author`, `timestamp`, `project`, and `application` from Git. These flow through every dispatcher job as outputs and are:
1. Attached as OCI labels on pushed Docker images (via `docker-build-push` action)
2. Written to `$GITHUB_STEP_SUMMARY` by the `summary` job at the end of each dispatcher

### Key configuration files

| File | Purpose |
|---|---|
| `builder-config.yaml` | OCB manifest: which OTel components to compile into the binary |
| `collector-config.yaml` | Runtime config for local Docker (debug exporter only) |
| `collector-configs/{env}.yaml` | Runtime config for cloud (Bearer token OTLP export + debug, except prod which is OTLP only) |
| `terraform/environments/{env}.tfvars` | Infra sizing per environment |
