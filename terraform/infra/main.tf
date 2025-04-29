provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_container_cluster" "existing" {
  count    = var.cluster_exists ? 1 : 0
  name     = var.gke_cluster_name
  location = var.region
  project  = var.project_id
}

resource "google_container_cluster" "gpu" {
  count                    = var.cluster_exists ? 0 : 1
  name                     = var.gke_cluster_name
  location                 = var.region
  remove_default_node_pool = true
  initial_node_count       = 1

  enable_shielded_nodes       = true
  enable_intranode_visibility = true
  enable_l4_ilb_subsetting    = true

  node_config {
    machine_type = "e2-small"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_container_node_pool" "gpu_pool" {
  count    = var.cluster_exists ? 0 : 1
  cluster  = var.cluster_exists ? data.google_container_cluster.existing[0].name : google_container_cluster.gpu[0].name
  location = var.region
  name     = "${var.gke_cluster_name}-gpu-pool"

  autoscaling {
    min_node_count = 0
    max_node_count = var.gke_gpu_max_nodes
  }
  node_locations = var.gke_gpu_zones

  node_config {
    machine_type = var.gke_machine_type
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

output "cluster_endpoint" {
  description = "GKE API server endpoint"
  value       = var.cluster_exists ? data.google_container_cluster.existing[0].endpoint : google_container_cluster.gpu[0].endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 CA cert for the cluster"
  value       = var.cluster_exists ? data.google_container_cluster.existing[0].master_auth[0].cluster_ca_certificate : google_container_cluster.gpu[0].master_auth[0].cluster_ca_certificate
}

