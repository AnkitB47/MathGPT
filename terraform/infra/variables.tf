variable "cluster_exists" {
  type        = bool
  default     = false
  description = "Set to true when importing an existing cluster"
}

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  default     = "europe-west4"
  description = "GCP region for GKE"
}

variable "gke_cluster_name" {
  type        = string
  default     = "mathsgpt-gpu-cluster"
  description = "Name of the GKE cluster for GPU workloads"
}

variable "gke_machine_type" {
  type        = string
  default     = "n1-standard-4"
  description = "Machine type for GPU node pool"
}

variable "gke_gpu_type" {
  type        = string
  default     = "nvidia-tesla-t4"
  description = "GPU accelerator type"
}

variable "gke_gpu_max_nodes" {
  type        = number
  default     = 2
  description = "Max number of GPU nodes in the pool"
}

variable "gke_gpu_zones" {
  type        = list(string)
  default     = ["europe-west4-a"]
  description = "Zones in which GPUs are available"
}
