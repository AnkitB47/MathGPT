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
  description = "GCP region for Cloud Run & GKE"
}

variable "service_name" {
  type        = string
  default     = "mathsgpt"
  description = "Cloud Run service name"
}

variable "container_image_cpu" {
  type        = string
  default     = "docker.io/ankitb47/maths-gpt:general_v1"
  description = "Docker image for CPU deployment (Cloud Run)"
}

variable "cpu" {
  type        = string
  default     = "1"
  description = "vCPU for Cloud Run"
}

variable "memory" {
  type        = string
  default     = "2Gi"
  description = "Memory for Cloud Run"
}

variable "container_image_gpu" {
  type        = string
  default     = "docker.io/ankitb47/maths-gpt:gpu_v1"
  description = "Docker image for GPU deployment (GKE)"
}

variable "import_existing_cluster" {
  type        = bool
  default     = false
  description = "Set to true to import an existing GKE cluster instead of creating new"
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
  default     = 1
  description = "Max number of GPU nodes in the pool"
}

variable "gke_gpu_zones" {
  type        = list(string)
  default     = ["europe-west4-a"]
  description = "Zones in which GPUs are available"
}

variable "gpu_workload_config" {
  type = list(object({
    component = string
    image     = string
  }))
  default = [
    {
      component = "llm_service"
      image     = "docker.io/ankitb47/maths-gpt:gpu_v1"
    }
  ]
  description = "GPU workload configurations for Helm chart components"
}
