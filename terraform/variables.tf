variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  default     = "europe-north1"
  description = "GCP region for Cloud Run"
}

variable "service_name" {
  type        = string
  default     = "mathsgpt"
  description = "Cloud Run service name"
}

variable "container_image" {
  type        = string
  description = "The public Docker image to deploy"
}

variable "cpu" {
  type        = string
  default     = "1"
  description = "vCPU to allocate"
}

variable "memory" {
  type        = string
  default     = "1Gi"
  description = "Memory to allocate"
}
