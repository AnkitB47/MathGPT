project_id          = "mathgpt-458012"
region              = "europe-west4"
service_name        = "mathsgpt"
container_image_cpu = "docker.io/ankitb47/maths-gpt:general_v1"
container_image_gpu = "docker.io/ankitb47/maths-gpt:gpu_v1"
cpu                 = "1"
memory              = "2Gi"
gke_cluster_name    = "mathsgpt-gpu-cluster"
gke_machine_type    = "n1-standard-4"
gke_gpu_type        = "nvidia-tesla-t4"
gke_gpu_zones       = ["europe-west4-a"]
gke_gpu_max_nodes   = 2
gpu_workload_config = [{
  component = "llm_service",
  image     = "docker.io/ankitb47/maths-gpt:gpu_v1"
}]
