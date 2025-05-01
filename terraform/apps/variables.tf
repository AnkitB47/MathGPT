variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  default     = "europe-west4"
  description = "GCP region for Cloud Run and Helm"
}

variable "service_name" {
  type        = string
  default     = "mathsgpt"
  description = "Cloud Run service name"
}

variable "container_image_cpu" {
  type        = string
  default     = "docker.io/ankitb47/maths-gpt:general_v1"
  description = "Container image for the CPU (Cloud Run) deployment"
}

variable "cpu" {
  type        = string
  default     = "1"
  description = "vCPU allocation for Cloud Run"
}

variable "memory" {
  type        = string
  default     = "2Gi"
  description = "Memory allocation for Cloud Run"
}

variable "gke_cluster_name" {
  type        = string
  default     = "mathsgpt-gpu-cluster"
  description = "Name of the GKE cluster for GPU workloads"
}

variable "use_exec_plugin" {
  type        = bool
  default     = true
  description = "Whether to use gcloud exec plugin for Kubernetes auth"
}
