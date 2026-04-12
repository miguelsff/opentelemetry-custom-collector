variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Environment must be dev, qa, or prod."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
}

variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Basic"
}

variable "cpu" {
  description = "CPU cores for the container app"
  type        = number
  default     = 0.25
}

variable "memory" {
  description = "Memory for the container app (e.g., 0.5Gi)"
  type        = string
  default     = "0.5Gi"
}

variable "min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "Maximum number of replicas"
  type        = number
  default     = 1
}

variable "otlp_export_endpoint" {
  description = "OTLP exporter endpoint URL"
  type        = string
  default     = ""
}

variable "otlp_bearer_token" {
  description = "Bearer token for OTLP exporter authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "debug_verbosity" {
  description = "Debug exporter verbosity level"
  type        = string
  default     = "detailed"
}
