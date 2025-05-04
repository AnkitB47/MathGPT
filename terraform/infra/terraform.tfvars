project_id          = "mathgpt-458012"
region              = "europe-west4"
gke_cluster_name    = "mathsgpt-gpu-cluster"
cluster_exists      = false

gke_cpu_machine_type  = "e2-small"
gke_cpu_max_nodes     = 3

gke_gpu_machine_type  = "n1-standard-4"
gke_gpu_type          = "NVIDIA_T4_GPUS"
gke_gpu_max_nodes     = 1
gke_gpu_zones         = ["europe-west4-a", "europe-west4-b","europe-west4-c"]
