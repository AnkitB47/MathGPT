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
  description = "Name of the GKE cluster"
}

variable "cluster_exists" {
  type        = bool
  default     = false
  description = "false = create new cluster; true = import an existing one"
}

variable "gke_machine_type" {
  type        = string
  default     = "n1-standard-4"
  description = "Machine type for the non-GPU node pool"
}

variable "gke_gpu_type" {
  type        = string
  default     = "nvidia-tesla-t4"
  description = "GPU accelerator type"
}

variable "gke_gpu_max_nodes" {
  type        = number
  default     = 1
  description = "Max number of GPU nodes in the GPU node pool"
}

variable "gke_gpu_zones" {
  type        = list(string)
  default     = ["europe-west4-a"]
  description = "Zones in which to create GPU nodes"
}
