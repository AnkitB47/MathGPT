variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Run & Helm"
  type        = string
  default     = "europe-west4"
}

variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "mathsgpt-gpu-cluster"
}

variable "use_exec_plugin" {
  description = "Whether to use gcloud exec plugin for Kubernetes auth"
  type        = bool
  default     = true
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "mathsgpt"
}

variable "container_image_cpu" {
  description = "Image for Cloud Run CPU service"
  type        = string
  default     = "docker.io/ankitb47/maths-gpt:general_v1"
}

variable "cpu" {
  description = "vCPU for Cloud Run"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory for Cloud Run"
  type        = string
  default     = "2Gi"
}

variable "coding_assistant_ip" {
  description = "Static IP for the GPU assistant LoadBalancer"
  type        = string
}

# Remote state reference
variable "infra_state_bucket" {
  description = "GCS bucket for infra state"
  type        = string
  default     = "mathgpt-tf-state"
}

variable "infra_state_prefix" {
  description = "Prefix for infra state"
  type        = string
  default     = "terraform/state/infra"
}