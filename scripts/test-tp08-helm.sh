#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHART_DIR="$SCRIPT_DIR/devops-app-chart"
NAMESPACE="devops-training"
RELEASE="devops-app"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }
step() { echo ""; echo "==> $1"; }

step "TP08 - Start minikube"

if ! command -v minikube &>/dev/null; then
  fail "minikube not installed. Run: curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && sudo install -o root -g root -m 0755 minikube-linux-amd64 /usr/local/bin/minikube"
fi

if ! minikube status | grep -q "Running"; then
  minikube start
fi
pass "minikube running"

step "TP08 - Helm lint"

helm lint "$CHART_DIR" \
  && pass "helm lint default values OK" || fail "helm lint failed"

helm lint "$CHART_DIR" -f "$CHART_DIR/values-dev.yaml" \
  && pass "helm lint values-dev.yaml OK" || fail "helm lint values-dev.yaml failed"

helm lint "$CHART_DIR" -f "$CHART_DIR/values-prod.yaml" \
  && pass "helm lint values-prod.yaml OK" || fail "helm lint values-prod.yaml failed"

step "TP08 - Helm template (dev)"

helm template "$RELEASE" "$CHART_DIR" -f "$CHART_DIR/values-dev.yaml" > /tmp/helm-dev-output.yaml \
  && pass "helm template dev OK" || fail "helm template dev failed"

grep -q "replicas: 1" /tmp/helm-dev-output.yaml \
  && pass "dev values: replicas=1" || fail "dev values: replicas not 1"

grep -q "development" /tmp/helm-dev-output.yaml \
  && pass "dev values: nodeEnv=development" || fail "dev values: nodeEnv not development"

step "TP08 - Helm template (prod)"

helm template "$RELEASE" "$CHART_DIR" -f "$CHART_DIR/values-prod.yaml" > /tmp/helm-prod-output.yaml \
  && pass "helm template prod OK" || fail "helm template prod failed"

grep -q "HorizontalPodAutoscaler" /tmp/helm-prod-output.yaml \
  && pass "prod values: HPA enabled (replicas géré par HPA)" || fail "prod values: HPA not found"

grep -q "maxReplicas: 20" /tmp/helm-prod-output.yaml \
  && pass "prod values: maxReplicas=20" || fail "prod values: maxReplicas not 20"

step "TP08 - Kustomize build"

kubectl kustomize "$SCRIPT_DIR/k8s/overlays/dev/" > /tmp/kustomize-dev.yaml \
  && pass "kustomize dev build OK" || fail "kustomize dev build failed"

grep -q "dev-devops-app" /tmp/kustomize-dev.yaml \
  && pass "kustomize dev: namePrefix applied" || fail "kustomize dev: namePrefix not found"

kubectl kustomize "$SCRIPT_DIR/k8s/overlays/prod/" > /tmp/kustomize-prod.yaml \
  && pass "kustomize prod build OK" || fail "kustomize prod build failed"

grep -q "prod-devops-app" /tmp/kustomize-prod.yaml \
  && pass "kustomize prod: namePrefix applied" || fail "kustomize prod: namePrefix not found"

step "TP08 - Create namespace"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
pass "namespace $NAMESPACE ready"

step "TP08 - Helm install (dev)"

helm install "$RELEASE" "$CHART_DIR" \
  -f "$CHART_DIR/values-dev.yaml" \
  -n "$NAMESPACE" \
  --set postgresql.auth.password=secret123 \
  --wait --timeout=90s \
  && pass "helm install dev OK" || fail "helm install dev failed"

helm list -n "$NAMESPACE"

step "TP08 - Helm upgrade (prod)"

helm upgrade "$RELEASE" "$CHART_DIR" \
  -f "$CHART_DIR/values-prod.yaml" \
  -n "$NAMESPACE" \
  --set postgresql.auth.password=secret123 \
  --wait --timeout=90s \
  && pass "helm upgrade prod OK" || fail "helm upgrade prod failed"

REVISION=$(helm history "$RELEASE" -n "$NAMESPACE" --max 1 | tail -1 | awk '{print $1}')
pass "current revision: $REVISION"

step "TP08 - Helm rollback"

helm rollback "$RELEASE" 1 -n "$NAMESPACE" --wait \
  && pass "helm rollback to revision 1 OK" || fail "helm rollback failed"

step "TP08 - Helm history"

helm history "$RELEASE" -n "$NAMESPACE"

step "TP08 - Cleanup"

helm uninstall "$RELEASE" -n "$NAMESPACE"
kubectl delete namespace "$NAMESPACE"
pass "release uninstalled and namespace deleted"

echo "======================"
echo "TP08 DONE"
echo "======================"
