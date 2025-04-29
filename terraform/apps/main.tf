data "terraform_remote_state" "infra" {
  backend = "gcs"
  config = {
    bucket = "mathgpt-tf-state"
    prefix = "terraform/state/infra"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${data.terraform_remote_state.infra.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gcloud"
    args        = [
      "container","clusters","get-credentials",
      var.gke_cluster_name,
      "--region", var.region,
      "--project", var.project_id,
      "--quiet",
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.terraform_remote_state.infra.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gcloud"
      args        = [
        "container","clusters","get-credentials",
        var.gke_cluster_name,
        "--region", var.region,
        "--project", var.project_id,
        "--quiet",
      ]
    }
  }
}

# 1) Service Account + IAM
resource "google_service_account" "deployer" {
  account_id   = "mathsgpt-deployer"
  display_name = "MathsGPT Deployer"
}

resource "google_project_iam_member" "run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_project_iam_member" "run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_project_iam_member" "service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_project_iam_member" "k8s_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

# 2) Cloud Run CPU service
resource "google_cloud_run_service" "cpu" {
  name     = var.service_name
  location = var.region

  template {

    metadata {
      annotations = {
        # minScale = minimum number of instances to keep warm
        "autoscaling.knative.dev/minScale" = "0"
      }
    }

    spec {
      service_account_name = google_service_account.deployer.email

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

# 3) Kubernetes namespace + Helm chart for monitoring
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "prom_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "45.0.0"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 600

  set {
    name  = "grafana.service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "grafana.adminPassword"
    value = "admin"
  }
  set {
    name  = "prometheusOperator.admissionWebhooks.enabled"
    value = "false"
  }
  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
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

  depends_on = [
    kubernetes_namespace.monitoring
  ]
}
