output "fqdn" {
  value = azurerm_container_app.this.ingress[0].fqdn
}

output "container_app_id" {
  value = azurerm_container_app.this.id
}

output "container_app_environment_id" {
  value = azurerm_container_app_environment.this.id
}
