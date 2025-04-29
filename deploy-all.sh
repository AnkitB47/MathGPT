#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# deploy-all.sh — provision infra/apps, then deploy general & GPU apps
# ──────────────────────────────────────────────────────────────────────

# 0) Required environment variables (set these in GitHub Secrets or locally)
: "${GCP_SA_KEY:?Environment variable GCP_SA_KEY must be set to your JSON key}"
: "${GCP_PROJECT_ID:?Environment variable GCP_PROJECT_ID must be set}"
: "${GCP_REGION:?Environment variable GCP_REGION must be set}"
: "${GCP_STATE_BUCKET:?Environment variable GCP_STATE_BUCKET must be set}"

# Write the key JSON to a temp file and point GOOGLE_APPLICATION_CREDENTIALS at it
KEY_FILE="$(mktemp)"
echo "$GCP_SA_KEY" > "$KEY_FILE"
export GOOGLE_APPLICATION_CREDENTIALS="$KEY_FILE"

# Derived values
PROJECT_ID="$GCP_PROJECT_ID"
REGION="$GCP_REGION"
STATE_BUCKET="$GCP_STATE_BUCKET"
SERVICE_ACCOUNT="cloud-run-deployer@${PROJECT_ID}.iam.gserviceaccount.com"

INFRA_DIR="terraform/infra"
APPS_DIR="terraform/apps"
GENERAL_DIR="general-assistant"
GPU_K8S_DIR="coding-assistant/kubernetes"
CLUSTER_NAME="mathsgpt-gpu-cluster"
GPU_NAMESPACE="gpu-assistant"

# 1) Phase 1: infra (GKE + node pools)
echo "🚧 Provisioning infra…"
pushd "$INFRA_DIR" >/dev/null

terraform init -reconfigure \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="prefix=terraform/state/infra"

terraform apply -var-file="terraform.tfvars" -auto-approve

popd >/dev/null

# 2) Phase 2: apps (Cloud Run + Helm)
echo "🚧 Deploying apps (Cloud Run + Helm)…"
pushd "$APPS_DIR" >/dev/null

terraform init -reconfigure \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="prefix=terraform/state/apps"

terraform apply -var-file="terraform.tfvars" -auto-approve

popd >/dev/null

# 3) Deploy General Assistant to Cloud Run
echo "🚀 Deploying General Assistant…"
pushd "$GENERAL_DIR" >/dev/null

gcloud run deploy mathsgpt-general \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --image docker.io/ankitb47/maths-gpt:general_v1 \
  --platform managed \
  --cpu 2 --memory 2Gi --concurrency 1 --min-instances=0 \
  --timeout 300s \
  --service-account "${SERVICE_ACCOUNT}" \
  --allow-unauthenticated

popd >/dev/null

# 4) Deploy GPU Assistant to GKE
echo "🚀 Deploying GPU Assistant…"
gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --quiet

kubectl create namespace "$GPU_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$GPU_K8S_DIR/deployment.yaml" -n "$GPU_NAMESPACE"
kubectl apply -f "$GPU_K8S_DIR/service.yaml"    -n "$GPU_NAMESPACE"

kubectl rollout status deployment/coding-assistant \
  -n "$GPU_NAMESPACE" --timeout=300s

# 5) Cleanup temp key and finish
rm -f "$KEY_FILE"

echo "✅ All done!"
