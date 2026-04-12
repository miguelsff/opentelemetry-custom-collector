variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "acr_login_server" {
  description = "ACR login server URL"
  type        = string
}

variable "acr_id" {
  description = "ACR resource ID for role assignment"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  type        = string
}

variable "cpu" {
  description = "CPU cores"
  type        = number
  default     = 0.25
}

variable "memory" {
  description = "Memory allocation"
  type        = string
  default     = "0.5Gi"
}

variable "min_replicas" {
  description = "Minimum replicas"
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "Maximum replicas"
  type        = number
  default     = 1
}

variable "otlp_export_endpoint" {
  description = "OTLP exporter endpoint"
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
  description = "Debug exporter verbosity"
  type        = string
  default     = "detailed"
}
