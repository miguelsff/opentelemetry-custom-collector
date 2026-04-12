resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

module "monitoring" {
  source = "./modules/monitoring"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}

module "acr" {
  source = "./modules/acr"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.acr_sku
}

module "container_app" {
  source = "./modules/container-app"

  environment                = var.environment
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  acr_login_server           = module.acr.login_server
  acr_id                     = module.acr.id
  image_tag                  = var.image_tag
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  cpu                        = var.cpu
  memory                     = var.memory
  min_replicas               = var.min_replicas
  max_replicas               = var.max_replicas
  otlp_export_endpoint       = var.otlp_export_endpoint
  otlp_bearer_token          = var.otlp_bearer_token
  debug_verbosity            = var.debug_verbosity
}
