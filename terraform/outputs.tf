output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "container_app_fqdn" {
  value = module.container_app.fqdn
}

output "container_app_url" {
  value = "https://${module.container_app.fqdn}"
}
