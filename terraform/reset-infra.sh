#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# reset-infra.sh — full teardown & rebuild of MathsGPT infra + apps
# ──────────────────────────────────────────────────────────────────────

# 0) Pick up your service-account key
if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" && -f "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
  KEY_FILE="$GOOGLE_APPLICATION_CREDENTIALS"
elif [[ -f key.json ]]; then
  KEY_FILE="$(pwd)/key.json"
elif [[ -f sa-key.json ]]; then
  KEY_FILE="$(pwd)/sa-key.json"
else
  echo "❌ No service-account key found. Place 'key.json' or 'sa-key.json' in repo root, or set GOOGLE_APPLICATION_CREDENTIALS."
  exit 1
fi

echo "🔑 Using service account key: $KEY_FILE"
export GOOGLE_APPLICATION_CREDENTIALS="$KEY_FILE"

# 1) Activate SA for gcloud & ADC
gcloud auth activate-service-account --key-file="$KEY_FILE"
PROJECT_ID="$(python3 - <<EOF
import json
print(json.load(open("$KEY_FILE"))["project_id"])
EOF
)"
gcloud config set project "$PROJECT_ID" >/dev/null
REGION="${REGION:-$(gcloud config get-value run/region 2>/dev/null || echo europe-west4)}"
STATE_BUCKET="mathgpt-tf-state"

echo "🛠 PROJECT_ID=$PROJECT_ID  REGION=$REGION  BUCKET=$STATE_BUCKET"

# 2) Clean up local state
echo "• Backing up & cleaning local Terraform state…"
for DIR in infra apps; do
  mkdir -p tf_state_backup/"$DIR"
  cp -f "$DIR"/*.tfstate* tf_state_backup/"$DIR"/ 2>/dev/null || true
  rm -rf "$DIR"/.terraform "$DIR"/*.tfstate* "$DIR"/terraform.tfstate.backup
done

# 3) Destroy in correct order: apps → infra
destroy_module() {
  pushd "$1" >/dev/null
  echo "• Destroying module '$1'…"
  terraform init -reconfigure \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="prefix=terraform/state/$1"

  terraform destroy -var-file="terraform.tfvars" -auto-approve
  popd >/dev/null
}
destroy_module apps
destroy_module infra

# 4) (Optional) GCP manual cleanup loops here…

# 5) Ensure TF state bucket & grant SA objectAdmin
echo "• Ensuring state bucket exists…"
if ! gsutil ls "gs://$STATE_BUCKET" >/dev/null 2>&1; then
  gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$STATE_BUCKET"
  gsutil uniformbucketlevelaccess set on "gs://$STATE_BUCKET"
  gsutil versioning set on "gs://$STATE_BUCKET"
fi

SA_EMAIL="$(python3 - <<EOF
import json
print(json.load(open("$KEY_FILE"))["client_email"])
EOF
)"
echo "• Granting storage.objectAdmin to $SA_EMAIL on gs://$STATE_BUCKET"
gsutil iam ch serviceAccount:"$SA_EMAIL":roles/storage.objectAdmin "gs://$STATE_BUCKET" || true

# 6) Re-deploy infra → apps
apply_module() {
  pushd "$1" >/dev/null
  echo "• Deploying module '$1'…"
  terraform init -reconfigure \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="prefix=terraform/state/$1"

  terraform apply -var-file="terraform.tfvars" -auto-approve
  popd >/dev/null
}
apply_module infra
apply_module apps

# 7) Post-deploy checks
echo "• Post-deploy verification…"
RUN_URL=$(terraform -chdir=apps output -raw cloud_run_url 2>/dev/null || true)
[[ -n "$RUN_URL" ]] && echo "  → Cloud Run: $RUN_URL"
GRAF_IP=$(kubectl get svc -n monitoring kube-prometheus-stack-grafana \
           -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
[[ -n "$GRAF_IP" ]] && echo "  → Grafana: http://$GRAF_IP"

echo "✅ All done!"
