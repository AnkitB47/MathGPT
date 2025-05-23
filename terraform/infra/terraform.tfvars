project_id          = "mathgpt-458012"
region              = "europe-west4"
gke_cluster_name    = "mathsgpt-gpu-cluster"

gke_cpu_machine_type  = "e2-small"
gke_cpu_max_nodes     = 3

gke_gpu_machine_type  = "n1-standard-4"
gke_gpu_type          = "nvidia-tesla-t4"
gke_gpu_max_nodes     = 1
gke_gpu_zones         = ["europe-west4-c"]
