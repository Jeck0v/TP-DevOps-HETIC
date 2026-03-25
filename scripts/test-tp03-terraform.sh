#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TF_ROOT="$SCRIPT_DIR/infra/terraform"
TF_DEV="$SCRIPT_DIR/infra/terraform/environments/dev"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }
step() { echo ""; echo "==> $1"; }

step "TP03/04 - Terraform validate (root)"

cd "$TF_ROOT"
terraform init -upgrade -input=false >/dev/null 2>&1
terraform validate \
  && pass "root module validate OK" || fail "root module validate failed"

terraform fmt -check -recursive \
  && pass "terraform fmt OK" || fail "terraform fmt has formatting issues"

step "TP03/04 - Terraform plan (root)"

terraform plan -var-file=dev.tfvars -input=false -out=/tmp/tfplan-root \
  && pass "terraform plan root OK" || fail "terraform plan root failed"

step "TP03/04 - Terraform validate (environments/dev)"

cd "$TF_DEV"
terraform init -upgrade -input=false >/dev/null 2>&1
terraform validate \
  && pass "environments/dev validate OK" || fail "environments/dev validate failed"

step "TP03/04 - Terraform plan (environments/dev)"

terraform plan \
  -var="app_name=devops-app" \
  -var="environment=dev" \
  -var="web_port=8181" \
  -var="web_replicas=2" \
  -var="db_password=secret123" \
  -var="db_port=5433" \
  -input=false -out=/tmp/tfplan-dev \
  && pass "terraform plan environments/dev OK" || fail "terraform plan environments/dev failed"

step "TP03/04 - Terraform apply (root)"

cd "$TF_ROOT"
terraform apply -var-file=dev.tfvars -input=false -auto-approve \
  && pass "terraform apply root OK" || fail "terraform apply root failed"

sleep 3

step "TP03/04 - Verify Docker resources"

CONTAINER=$(docker ps --filter "name=devops-app-dev" --format "{{.Names}}" | head -1)
if [ -n "$CONTAINER" ]; then
  pass "container $CONTAINER is running"
else
  fail "no devops-app-dev container found"
fi

terraform output web_url \
  && pass "terraform output web_url OK" || fail "terraform output web_url failed"

step "TP03/04 - Terraform destroy (root)"

terraform destroy -var-file=dev.tfvars -input=false -auto-approve \
  && pass "terraform destroy root OK" || fail "terraform destroy root failed"

echo "======================"
echo "TP03/04 DONE"
echo "======================"
