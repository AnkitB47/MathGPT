# Project & region
variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region for GKE"
  default     = "europe-west4"
}

variable "gke_cluster_name" {
  type        = string
  description = "Name of the GKE cluster"
  default     = "mathsgpt-gpu-cluster"
}

# CPU node-pool sizing
variable "gke_cpu_machine_type" {
  type        = string
  description = "Machine type for the CPU node-pool"
  default     = "e2-small"
}

variable "gke_cpu_max_nodes" {
  type        = number
  description = "Max nodes in CPU pool"
  default     = 3
}

# GPU node-pool sizing
variable "gke_gpu_machine_type" {
  type        = string
  description = "Machine type for the GPU node-pool"
  default     = "n1-standard-4"
}

variable "gke_gpu_type" {
  type        = string
  description = "GPU accelerator to attach"
  default     = "nvidia-tesla-t4"
}

variable "gke_gpu_max_nodes" {
  type        = number
  description = "Max nodes in GPU pool"
  default     = 1
}

variable "gke_gpu_zones" {
  type        = list(string)
  description = "Zones to place GPU nodes in"
  default     = ["europe-west4-c"]
}