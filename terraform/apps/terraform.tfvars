project_id           = "mathgpt-458012"
region               = "europe-west4"
gke_cluster_name     = "mathsgpt-gpu-cluster"
use_exec_plugin      = true

service_name         = "mathsgpt"
container_image_cpu  = "docker.io/ankitb47/maths-gpt:general_v1"
cpu                  = "2"
memory               = "2Gi"
coding_assistant_ip  = "34.91.192.103"