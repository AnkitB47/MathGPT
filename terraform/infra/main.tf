provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_container_cluster" "primary" {
  name                     = var.gke_cluster_name
  location                 = var.region
  remove_default_node_pool = true
  initial_node_count       = 1

  enable_shielded_nodes       = true
  enable_intranode_visibility = true
  enable_l4_ilb_subsetting    = true
  network_policy {
    enabled = true
  }

  node_config {
    machine_type = var.gke_cpu_machine_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_container_node_pool" "cpu_pool" {
  count      = var.cluster_exists ? 0 : 1
  name       = "${var.gke_cluster_name}-cpu-pool"
  cluster    = google_container_cluster.primary.name
  location   = var.region

  node_locations = var.gke_gpu_zones

  initial_node_count = 1

  node_config {
    machine_type = var.gke_cpu_machine_type
    disk_size_gb = 50
    disk_type    = "pd-balanced"
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]
    metadata = {
      disable-legacy-endpoints = "true"
    }
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

resource "google_container_node_pool" "gpu_pool" {
  count          = var.cluster_exists ? 0 : 1
  name           = "${var.gke_cluster_name}-gpu-pool"
  cluster        = google_container_cluster.primary.name
  location       = var.region
  node_count     = 1
  node_locations = var.gke_gpu_zones

  node_config {
    machine_type = var.gke_gpu_machine_type
    preemptible  = true
    disk_size_gb = 100
    disk_type    = "pd-balanced"

    guest_accelerator {
      type  = var.gke_gpu_type
      count = 1
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]

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
      node_config[0].metadata,
    ]
  }
}

output "cluster_endpoint" {
  value = google_container_cluster.primary.endpoint
}

output "cluster_ca_certificate" {
  value = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
}