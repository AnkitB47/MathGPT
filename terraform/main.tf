terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# 1) service account for Cloud Run (unused permissions minimized)
resource "google_service_account" "deployer" {
  account_id   = "cloud-run-deployer"
  display_name = "Cloud Run Deployer"
}

# 2) give that service account the Cloud Run Admin & Viewer roles
resource "google_project_iam_member" "deployer_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}
resource "google_project_iam_member" "deployer_viewer" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

# 3) allow unauthenticated invocations
resource "google_project_iam_member" "invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "allUsers"
}

# 4) the Cloud Run service itself
resource "google_cloud_run_service" "mathsgpt" {
  name     = var.service_name
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.deployer.email

      containers {
        image = var.container_image

        ports {
          name           = "http1"
          container_port = 8501
        }
        resources {
          limits = {
            cpu    = var.cpu
            memory = var.memory
          }
        }
      }
    }
  }

  traffic {
    latest_revision = true
    percent         = 100
  }
}

output "url" {
  description = "Your MathGPT Cloud Run URL"
  value       = google_cloud_run_service.mathsgpt.status[0].url
}
