#!/usr/bin/env bash
set -euo pipefail

: "${GCP_PROJECT_ID:?mathgpt-458012}"
: "${GCP_REGION:?europe-west4}"
: "${GCP_STATE_BUCKET:?mathgpt-tf-state}"
: "${GCP_SA_KEY:?sa-key}"
: "${GKE_CLUSTER_NAME:=mathsgpt-gpu-cluster}"

# ─────────────────────────────────────────────────────────────────────────────
# 0) Activate & configure gcloud + ADC
# ─────────────────────────────────────────────────────────────────────────────
echo "🔑 Activating service account for gcloud CLI…"
gcloud auth activate-service-account --key-file="$GCP_SA_KEY"
gcloud config set project    "$GCP_PROJECT_ID" >/dev/null
gcloud config set compute/region "$GCP_REGION" >/dev/null

echo "🔑 Pointing Application Default Credentials at your key file…"
export GOOGLE_APPLICATION_CREDENTIALS="$GCP_SA_KEY"


# ─────────────────────────────────────────────────────────────────────────────
# 1) Verify GPUS_ALL_REGIONS quota
# ─────────────────────────────────────────────────────────────────────────────
echo "🔍 Checking GPUS_ALL_REGIONS quota…"
GPU_QUOTA=$(
  gcloud compute project-info describe \
    --project "$GCP_PROJECT_ID" \
    --flatten="quotas[]" \
    --format="table(quotas.metric,quotas.limit)" \
  | grep -w GPUS_ALL_REGIONS \
  | awk '{print $2}'
)

if [[ -z "$GPU_QUOTA" ]]; then
  echo "❌ ERROR: GPUS_ALL_REGIONS not found—request quota first."
  exit 1
elif (( $(echo "$GPU_QUOTA < 1" | bc -l) )); then
  echo "❌ ERROR: GPUS_ALL_REGIONS is $GPU_QUOTA—must be ≥1."
  exit 1
else
  echo "✅ GPUS_ALL_REGIONS quota is $GPU_QUOTA."
fi


SA_EMAIL="mathsgpt-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# ─────────────────────────────────────────────────────────────────────────────
# 2) Cleanup Kubernetes GPU assistant resources
# ─────────────────────────────────────────────────────────────────────────────
if kubectl version --short &>/dev/null; then
  echo "🧹 Cleaning up previous GPU assistant resources…"
  kubectl delete namespace gpu-assistant            --ignore-not-found || true
  kubectl delete daemonset nvidia-device-plugin-daemonset \
                                            -n kube-system --ignore-not-found || true
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3) Fetch GKE credentials if cluster exists
# ─────────────────────────────────────────────────────────────────────────────
if gcloud container clusters describe "$GKE_CLUSTER_NAME" \
     --region="$GCP_REGION" --project="$GCP_PROJECT_ID" &>/dev/null; then
  echo "🔑 Fetching GKE credentials for $GKE_CLUSTER_NAME…"
  gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" \
    --region "$GCP_REGION" --project "$GCP_PROJECT_ID" --quiet
else
  echo "ℹ️  Cluster $GKE_CLUSTER_NAME not found; skipping kubeconfig fetch."
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4) Remove GPU taint
# ─────────────────────────────────────────────────────────────────────────────
if kubectl get nodes --selector=cloud.google.com/gke-nodepool=${GKE_CLUSTER_NAME}-gpu-pool &>/dev/null; then
  echo "⏳ Clearing GPU taints…"
  gcloud container node-pools update "${GKE_CLUSTER_NAME}-gpu-pool" \
    --cluster="$GKE_CLUSTER_NAME" \
    --region="$GCP_REGION" \
    --node-taints="" --quiet
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5) Grant IAM roles to deployer SA
# ─────────────────────────────────────────────────────────────────────────────
echo "🔐 Granting IAM roles to $SA_EMAIL"
for ROLE in \
  roles/container.admin \               # full GKE control (create/delete clusters, node-pools, etc)  
  roles/container.clusterViewer \       # allow gcloud get-credentials  
  roles/container.clusterAdmin \        # if Terraform ever needs to upgrade or delete the cluster itself  
  roles/compute.instanceAdmin.v1 \      # create/delete VMs (node pools)  
  roles/iam.serviceAccountUser \        # “impersonate” other SAs  
  roles/run.admin \                     # Cloud Run: create/update services  
  roles/run.invoker \                   # Cloud Run: invoke permissions  
  roles/storage.admin \                 # create/delete buckets, set ACLs  
  roles/storage.objectAdmin \           # full object-level control (lock files, state)  
; do
  gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$ROLE" \
    --quiet || true
done

# ─────────────────────────────────────────────────────────────────────────────
# 6) Cleanup Prometheus/Helm
# ─────────────────────────────────────────────────────────────────────────────
if kubectl version --short &>/dev/null; then
  echo "🧹 Cleaning up Helm monitoring…"
  helm uninstall prometheus-operator-crds --namespace monitoring || true
  helm uninstall kube-prometheus-stack    --namespace monitoring || true
  kubectl delete namespace monitoring     --ignore-not-found || true
  kubectl delete crd \
    prometheuses.monitoring.coreos.com \
    prometheusrules.monitoring.coreos.com \
    servicemonitors.monitoring.coreos.com \
    podmonitors.monitoring.coreos.com \
    --ignore-not-found || true
fi

# ─────────────────────────────────────────────────────────────────────────────
# 7) Clear Terraform locks & local caches
# ─────────────────────────────────────────────────────────────────────────────
echo "🗑️ Clearing Terraform locks…"
gcloud storage rm --quiet "gs://${GCP_STATE_BUCKET}/terraform/state/infra/default.tflock" || true
gcloud storage rm --quiet "gs://${GCP_STATE_BUCKET}/terraform/state/apps/default.tflock"   || true

echo "🧹 Cleaning local Terraform…"
find terraform/infra terraform/apps -maxdepth 1 -type d -name ".terraform*" -exec rm -rf {} +
find terraform/infra terraform/apps -type f \( -name "*.tfstate*" -o -name ".terraform.lock.hcl" \) -delete

cat <<EOF

✅ Reset complete.

→ Next steps:
   cd terraform/infra
   terraform init -reconfigure \
     -backend-config="bucket=${GCP_STATE_BUCKET}" \
     -backend-config="prefix=terraform/state/infra"
   terraform apply -var-file="terraform.tfvars"

   cd ../apps
   terraform init -reconfigure \
     -backend-config="bucket=${GCP_STATE_BUCKET}" \
     -backend-config="prefix=terraform/state/apps"
   terraform apply -var-file="terraform.tfvars"
EOF
