terraform {
  backend "azurerm" {
    resource_group_name  = "rg-otelcol-tfstate"
    storage_account_name = "stotelcoltfstate"
    container_name       = "tfstate"
    key                  = "default.tfstate" # Overridden per env via -backend-config="key={env}.tfstate"
  }
}

provider "azurerm" {
  features {}
}
