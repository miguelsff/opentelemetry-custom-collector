variable "resource_group_name" {
  description = "Resource group for Terraform state storage"
  type        = string
  default     = "rg-otelcol-tfstate"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "storage_account_name" {
  description = "Storage account name for Terraform state (must be globally unique)"
  type        = string
  default     = "stotelcoltfstate"
}
