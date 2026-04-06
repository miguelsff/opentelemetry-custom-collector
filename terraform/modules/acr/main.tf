resource "azurerm_container_registry" "this" {
  name                = "acrotelcol${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = false
}
