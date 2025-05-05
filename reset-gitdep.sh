#!/usr/bin/env bash
set -euo pipefail

: "${GCP_PROJECT_ID:?set this to your project}"
: "${GCP_REGION:?set this to your region (e.g. europe-west4)}"
: "${GCP_STATE_BUCKET:?set this to your tfstate bucket}"
: "${GCP_SA_KEY:?point this at your service-account JSON key}"
: "${GKE_CLUSTER_NAME:=mathsgpt-gpu-cluster}"

# Activate and configure
echo "🔑 Activating service account…"
gcloud auth activate-service-account --key-file="$GCP_SA_KEY"
gcloud config set project "$GCP_PROJECT_ID" >/dev/null
gcloud config set compute/region "$GCP_REGION" >/dev/null

# 0) Verify GPU quota
GPU_QUOTA=$( \
  gcloud compute project-info describe \
    --project "$GCP_PROJECT_ID" \
    --flatten="quotas[]" \
    --format="table(quotas.metric,quotas.limit)" \
  | grep -w GPUS_ALL_REGIONS \
  | awk '{print $2}' \
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

# 1) Cleanup Kubernetes GPU assistant resources
if kubectl version --short &>/dev/null; then
  echo "🧹 Cleaning up previous GPU assistant resources…"
  kubectl delete namespace gpu-assistant --ignore-not-found || true
  kubectl delete daemonset nvidia-device-plugin-daemonset -n kube-system --ignore-not-found || true
fi

# 2) Fetch GKE credentials if cluster exists
if gcloud container clusters describe "$GKE_CLUSTER_NAME" \
     --region="$GCP_REGION" --project="$GCP_PROJECT_ID" &>/dev/null; then
  echo "🔑 Fetching GKE credentials for $GKE_CLUSTER_NAME…"
  gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" \
    --region "$GCP_REGION" --project "$GCP_PROJECT_ID" --quiet
else
  echo "ℹ️  Cluster $GKE_CLUSTER_NAME not found; skipping kubeconfig fetch."
fi

# 3) Remove GPU taint
if kubectl get nodes --selector=cloud.google.com/gke-nodepool=${GKE_CLUSTER_NAME}-gpu-pool &>/dev/null; then
  echo "⏳ Clearing GPU taints…"
  gcloud container node-pools update "${GKE_CLUSTER_NAME}-gpu-pool" \
    --cluster="$GKE_CLUSTER_NAME" \
    --region="$GCP_REGION" \
    --node-taints="" --quiet
fi

# 4) Grant IAM roles
echo "🔐 Granting IAM roles to $SA_EMAIL"
for ROLE in \
    roles/container.admin \
    roles/compute.instanceAdmin.v1 \
    roles/iam.serviceAccountUser \
    roles/run.admin \
    roles/run.invoker \
    roles/storage.admin; do
  gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" --role="$ROLE" --quiet || true
done

# 5) Cleanup Prometheus/Helm
if kubectl version --short &>/dev/null; then
  echo "🧹 Cleaning up Helm monitoring…"
  helm uninstall prometheus-operator-crds --namespace monitoring || true
  helm uninstall kube-prometheus-stack --namespace monitoring || true
  kubectl delete namespace monitoring --ignore-not-found || true
  kubectl delete crd prometheuses.monitoring.coreos.com prometheusrules.monitoring.coreos.com servicemonitors.monitoring.coreos.com podmonitors.monitoring.coreos.com --ignore-not-found || true
fi

# 6) Clear Terraform locks & caches
echo "🗑️ Clearing Terraform locks…"
gsutil -q rm "gs://${GCP_STATE_BUCKET}/terraform/state/infra/default.tflock" || true
gsutil -q rm "gs://${GCP_STATE_BUCKET}/terraform/state/apps/default.tflock" || true

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
