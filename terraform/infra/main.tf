provider "google" {
  project = var.project_id
  region  = var.region
}

# 0) If re-using an existing cluster, read its data
data "google_container_cluster" "existing" {
  count    = var.cluster_exists ? 1 : 0
  name     = var.gke_cluster_name
  location = var.region
  project  = var.project_id
}

# 1) Create GKE cluster (skip if cluster_exists=true)
resource "google_container_cluster" "gpu_cluster" {
  count                    = var.cluster_exists ? 0 : 1
  name                     = var.gke_cluster_name
  location                 = var.region
  remove_default_node_pool = true
  initial_node_count       = 1

  locations = var.gke_gpu_zones           # ← list of zones

  node_config {
    machine_type = var.gke_cpu_machine_type
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  enable_shielded_nodes       = true
  enable_intranode_visibility = true
  enable_l4_ilb_subsetting    = true
}

# 2) Expose either the new or existing cluster’s endpoint/CA cert
locals {
  cluster_name           = var.cluster_exists ? data.google_container_cluster.existing[0].name : google_container_cluster.gpu_cluster[0].name
  cluster_endpoint       = var.cluster_exists ? data.google_container_cluster.existing[0].endpoint : google_container_cluster.gpu_cluster[0].endpoint
  cluster_ca_certificate = var.cluster_exists ? data.google_container_cluster.existing[0].master_auth[0].cluster_ca_certificate : google_container_cluster.gpu_cluster[0].master_auth[0].cluster_ca_certificate
}

output "cluster_endpoint" {
  value = local.cluster_endpoint
}

output "cluster_ca_certificate" {
  value = local.cluster_ca_certificate
}

# 3) CPU node-pool (for general workloads, Prometheus, Cloud Run, etc.)
resource "google_container_node_pool" "cpu_pool" {
  count    = var.cluster_exists ? 0 : 1
  name     = "${var.gke_cluster_name}-cpu-pool"
  cluster  = local.cluster_name
  location = var.region

  initial_node_count = 1

  node_config {
    machine_type = var.gke_cpu_machine_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]
  }

  autoscaling {
    min_node_count = 1
    max_node_count = var.gke_cpu_max_nodes
  }

  timeouts {
    create = "15m"
    delete = "10m"
  }
}

# 4) GPU node-pool (tainted so only GPU-workloads land)
resource "google_container_node_pool" "gpu_pool" {
  count    = var.cluster_exists ? 0 : 1
  name     = "${var.gke_cluster_name}-gpu-pool"
  cluster  = local.cluster_name
  location = var.region
  node_locations = var.gke_gpu_zones

  node_config {
    machine_type = var.gke_gpu_machine_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]

    guest_accelerator {
      type  = var.gke_gpu_type
      count = 1
    }

    preemptible  = true
    disk_size_gb = 30
    disk_type    = "pd-ssd"

    metadata = {
      disable-legacy-endpoints = "true"
      install-nvidia-driver    = "true"
    }

    taint {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }
  }

  initial_node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = var.gke_gpu_max_nodes
  }

  timeouts {
    create = "30m"
    delete = "20m"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      node_config[0].labels,
      node_config[0].metadata,
    ]
  }
}
