// ────────────────────────────────────────────────────────────────────
// terraform/apps/main.tf
// ────────────────────────────────────────────────────────────────────

// 0) Infra outputs
data "terraform_remote_state" "infra" {
  backend = "gcs"
  config = {
    bucket = "mathgpt-tf-state"
    prefix = "terraform/state/infra"
  }
}

// 1) GCP + k8s + Helm providers
provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

// Service Account & IAM for Cloud Run
data "google_service_account" "deployer" {
  project    = var.project_id
  account_id = "mathsgpt-deployer"
}

provider "kubernetes" {
  host                   = "https://${data.terraform_remote_state.infra.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_certificate)

  dynamic "exec" {
    for_each = var.use_exec_plugin ? [1] : []
    content {
      api_version = "client.authentication.k8s.io/v1"
      command     = "gcloud"
      args = [
        "container", "clusters", "get-credentials",
        var.gke_cluster_name, "--region", var.region, "--project", var.project_id, "--quiet",
      ]
    }
  }

  token = data.google_client_config.default.access_token
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.terraform_remote_state.infra.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_certificate)

    dynamic "exec" {
      for_each = var.use_exec_plugin ? [1] : []
      content {
        api_version = "client.authentication.k8s.io/v1"
        command     = "gcloud"
        args = [
          "container", "clusters", "get-credentials",
          var.gke_cluster_name, "--region", var.region, "--project", var.project_id, "--quiet",
        ]
      }
    }

    token = data.google_client_config.default.access_token
  }
}

// 2) IAM bindings for the deployer SA
resource "google_project_iam_member" "run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${data.google_service_account.deployer.email}"
}
resource "google_project_iam_member" "run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${data.google_service_account.deployer.email}"
}
resource "google_project_iam_member" "sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${data.google_service_account.deployer.email}"
}
resource "google_project_iam_member" "k8s_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${data.google_service_account.deployer.email}"
}
resource "google_project_iam_member" "compute_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${data.google_service_account.deployer.email}"
}
resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${data.google_service_account.deployer.email}"
}

// 3) Cloud Run “cpu” service
resource "google_cloud_run_service" "cpu" {
  name     = var.service_name
  location = var.region

  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "0"
      }
    }
    spec {
      service_account_name = data.google_service_account.deployer.email
      containers {
        image = var.container_image_cpu
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

  depends_on = [
    google_project_iam_member.run_admin,
    google_project_iam_member.run_invoker,
  ]
}

resource "google_cloud_run_service_iam_member" "cpu_public" {
  location = var.region
  project  = var.project_id
  service  = google_cloud_run_service.cpu.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

// 4) The monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

// 5) Install CRDs (no tolerations needed once you remove the pool taint)
resource "helm_release" "prometheus_operator_crds" {
  depends_on       = [ kubernetes_namespace.monitoring ]
  name             = "prometheus-operator-crds"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus-operator-crds"
  version          = "20.0.0"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false
  skip_crds        = false

  wait    = true
  timeout = 600
}

// 6) Main kube-prometheus-stack
resource "helm_release" "prom_stack" {
  depends_on       = [ helm_release.prometheus_operator_crds ]
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "45.0.0"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false
  skip_crds        = true
  cleanup_on_fail  = true

  wait           = true
  wait_for_jobs  = false
  timeout        = 1800  // 30m

  // storage & retention tweaks
  set {
    name  = "grafana.service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "grafana.adminPassword"
    value = "admin"
  }
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "7d"
  }
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "standard"
  }
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]"
    value = "ReadWriteOnce"
  }
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "50Gi"
  }
}
