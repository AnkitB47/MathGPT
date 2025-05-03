// ───────────────────────────────────────────────────────────────────
// Required (no defaults) — must be provided via CLI, env, or tfvars
// ───────────────────────────────────────────────────────────────────
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
}

// ───────────────────────────────────────────────────────────────────
// Cloud Run defaults
// ───────────────────────────────────────────────────────────────────
variable "region" {
  description = "GCP region for Cloud Run and Helm"
  type        = string
  default     = "europe-west4"
}

variable "container_image_cpu" {
  description = "Container image for the CPU (Cloud Run) deployment"
  type        = string
  default     = "docker.io/ankitb47/maths-gpt:general_v1"
}

variable "cpu" {
  description = "vCPU allocation for Cloud Run"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory allocation for Cloud Run"
  type        = string
  default     = "2Gi"
}

// ───────────────────────────────────────────────────────────────────
// GKE cluster settings
// ───────────────────────────────────────────────────────────────────
variable "gke_cluster_name" {
  description = "Name of the GKE cluster for GPU workloads"
  type        = string
  default     = "mathsgpt-gpu-cluster"
}

variable "use_exec_plugin" {
  description = "Whether to use gcloud exec plugin for Kubernetes auth"
  type        = bool
  default     = true
}

// ───────────────────────────────────────────────────────────────────
// Node‐pool sizing
// ───────────────────────────────────────────────────────────────────
variable "gke_cpu_machine_type" {
  description = "Machine type for CPU node pool"
  type        = string
  default     = "e2-small"
}

variable "gke_gpu_machine_type" {
  description = "Machine type for GPU node pool"
  type        = string
  default     = "n1-standard-4"
}

variable "gke_gpu_type" {
  description = "GPU accelerator type"
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gke_gpu_max_nodes" {
  description = "Max nodes for GPU pool"
  type        = number
  default     = 2
}
