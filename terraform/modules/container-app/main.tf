resource "azurerm_container_app_environment" "this" {
  name                       = "cae-otelcol-${var.environment}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = var.log_analytics_workspace_id
}

resource "azurerm_user_assigned_identity" "this" {
  name                = "id-otelcol-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_container_app" "this" {
  name                         = "ca-otelcol-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }

  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.this.id
  }

  ingress {
    external_enabled = true
    target_port      = 4317
    transport        = "http2"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "otelcol-custom"
      image  = "${var.acr_login_server}/otelcol-custom:${var.image_tag}"
      cpu    = var.cpu
      memory = var.memory

      env {
        name  = "OTLP_EXPORT_ENDPOINT"
        value = var.otlp_export_endpoint
      }

      env {
        name  = "DEBUG_VERBOSITY"
        value = var.debug_verbosity
      }

      env {
        name        = "OTLP_BEARER_TOKEN"
        secret_name = "otlp-bearer-token"
      }

      liveness_probe {
        transport = "HTTP"
        port      = 13133
        path      = "/"
      }

      readiness_probe {
        transport = "HTTP"
        port      = 13133
        path      = "/"
      }

      startup_probe {
        transport = "HTTP"
        port      = 13133
        path      = "/"
      }
    }

  }

  secret {
    name  = "otlp-bearer-token"
    value = var.otlp_bearer_token
  }

  depends_on = [azurerm_role_assignment.acr_pull]
}
