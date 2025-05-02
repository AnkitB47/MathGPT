#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# nuke-all.sh — completely tear down GKE, Cloud Run, Helm, and TF state
# ──────────────────────────────────────────────────────────────────────

: "${GCP_SA_KEY:?must set GCP_SA_KEY to your service-account JSON}"
: "${GCP_PROJECT_ID:?must set GCP_PROJECT_ID to your project ID}"
: "${GCP_REGION:?must set GCP_REGION to your GKE region}"
: "${GCP_STATE_BUCKET:?must set GCP_STATE_BUCKET to your TF state bucket}"

# write the JSON key to a temp file
KEYFILE="$(mktemp)"
echo "$GCP_SA_KEY" > "$KEYFILE"
export GOOGLE_APPLICATION_CREDENTIALS="$KEYFILE"

# common settings
PROJECT="$GCP_PROJECT_ID"
REGION="$GCP_REGION"
TF_BUCKET="$GCP_STATE_BUCKET"
CLUSTER="mathsgpt-gpu-cluster"
RUN_SERVICES=(mathsgpt-general mathsgpt)

echo "🔑 Authenticating…"
gcloud auth activate-service-account --key-file="$KEYFILE"
gcloud config set project "$PROJECT"
gcloud config set compute/region "$REGION"

echo "🧨 Deleting GKE cluster ${CLUSTER} (this also nukes all node-pools)…"
if gcloud container clusters describe "$CLUSTER" --region="$REGION" &>/dev/null; then
  gcloud container clusters delete "$CLUSTER" \
    --region="$REGION" \
    --project="$PROJECT" \
    --quiet
else
  echo "→ no cluster named $CLUSTER found, skipping"
fi

echo "☁️  Deleting Cloud Run services…"
for svc in "${RUN_SERVICES[@]}"; do
  if gcloud run services describe "$svc" --region="$REGION" &>/dev/null; then
    gcloud run services delete "$svc" \
      --region="$REGION" \
      --platform=managed \
      --quiet
  fi
done

echo "🎈 Cleaning up Helm releases & monitoring CRDs…"
# install kubectl & helm if missing
if ! command -v kubectl &>/dev/null; then
  gcloud components install kubectl --quiet
fi
if ! command -v helm &>/dev/null; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# uninstall any stuck releases
helm uninstall prometheus-operator-crds --namespace monitoring || true
helm uninstall kube-prometheus-stack    --namespace monitoring || true

# delete the namespace & CRDs
kubectl delete namespace monitoring --ignore-not-found || true
kubectl get crd \
  | grep -E 'monitoring\.coreos\.com|monitoring\.googleapis\.com' \
  | xargs -r kubectl delete crd --ignore-not-found

echo "📦 Wiping Terraform state from gs://$TF_BUCKET/terraform…"
gsutil -m rm -r "gs://$TF_BUCKET/terraform" || true

echo "🧹 Cleaning local Terraform caches & state…"
find . -type d -name '.terraform' -prune -exec rm -rf '{}' +
find . -type f \( -name '*.tfstate' -o -name '*.tfstate.backup' -o -name '.terraform.lock.hcl' \) -delete

echo "✅ All done! Everything has been torn down."

# remove temp key
rm -f "$KEYFILE"
