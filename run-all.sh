#!/usr/bin/env bash
set -euo pipefail

# Run Terraform
# echo "→ Running Terraform…"
# gh workflow run "🛠 Terraform Deploy" --ref main
# gh run watch --exit-zero --workflow="🛠 Terraform Deploy"

# # Deploy the general assistant
# echo "→ Deploying General Assistant…"
# gh workflow run "🚀 Deploy General Assistant" --ref main
# gh run watch --exit-zero --workflow="🚀 Deploy General Assistant"

# Deploy the GPU assistant
echo "→ Deploying GPU Assistant…"
gh workflow run "🖥️ Deploy GPU Assistant" --ref main
gh run watch --exit-zero --workflow="🖥️ Deploy GPU Assistant"

echo "✅ All workflows complete!"
