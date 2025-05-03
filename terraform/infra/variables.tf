// ───────────────────────────────────────────────────────────────────
// Required inputs
// ───────────────────────────────────────────────────────────────────
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for GKE & node-pools"
  type        = string
  default     = "europe-west4"
}

variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "mathsgpt-gpu-cluster"
}

// ───────────────────────────────────────────────────────────────────
// Cluster reuse flag
// ───────────────────────────────────────────────────────────────────
variable "cluster_exists" {
  description = "If true, will reuse an existing cluster instead of creating a new one"
  type        = bool
  default     = false
}

// ───────────────────────────────────────────────────────────────────
// Node-pool sizing
// ───────────────────────────────────────────────────────────────────
variable "gke_cpu_machine_type" {
  description = "Machine type for the CPU node-pool"
  type        = string
  default     = "e2-small"
}

variable "gke_gpu_machine_type" {
  description = "Machine type for the GPU node-pool"
  type        = string
  default     = "n1-standard-4"
}

variable "gke_gpu_type" {
  description = "GPU accelerator to attach"
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gke_gpu_max_nodes" {
  description = "Maximum size for the GPU node-pool"
  type        = number
  default     = 1
}

