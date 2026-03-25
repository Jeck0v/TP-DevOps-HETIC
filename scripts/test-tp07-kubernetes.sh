#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NAMESPACE="devops-training"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }
step() { echo ""; echo "==> $1"; }

step "TP07 - Start minikube"

if ! command -v minikube &>/dev/null; then
  fail "minikube not installed. Run: curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && sudo install -o root -g root -m 0755 minikube-linux-amd64 /usr/local/bin/minikube"
fi

if ! minikube status | grep -q "Running"; then
  minikube start
fi
pass "minikube running"

step "TP07 - Validate manifests (dry-run)"

kubectl apply --dry-run=client -f "$SCRIPT_DIR/k8s/configmap.yaml" \
  && pass "configmap.yaml valid" || fail "configmap.yaml invalid"

kubectl apply --dry-run=client -f "$SCRIPT_DIR/k8s/postgres.yaml" \
  && pass "postgres.yaml valid" || fail "postgres.yaml invalid"

kubectl apply --dry-run=client -f "$SCRIPT_DIR/k8s/app.yaml" \
  && pass "app.yaml valid" || fail "app.yaml invalid"

kubectl apply --dry-run=client -f "$SCRIPT_DIR/k8s/ingress.yaml" \
  && pass "ingress.yaml valid" || fail "ingress.yaml invalid"

step "TP07 - Kustomize dry-run"

kubectl apply --dry-run=client -k "$SCRIPT_DIR/k8s/overlays/dev/" \
  && pass "kustomize dev overlay valid" || fail "kustomize dev overlay invalid"

kubectl apply --dry-run=client -k "$SCRIPT_DIR/k8s/overlays/prod/" \
  && pass "kustomize prod overlay valid" || fail "kustomize prod overlay invalid"


step "TP07 - Create namespace"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl config set-context --current --namespace="$NAMESPACE"
pass "namespace $NAMESPACE ready"

step "TP07 - Ensure devops-app:1.0.0 image is built"

docker build -t devops-app:1.0.0 "$SCRIPT_DIR/app/" >/dev/null 2>&1
pass "devops-app:1.0.0 image ready"

step "TP07 - Load image into cluster"

minikube image load devops-app:1.0.0
pass "image loaded into minikube"

step "TP07 - Create secret"

kubectl create secret generic app-secrets \
  --namespace="$NAMESPACE" \
  --from-literal=DB_USER=appuser \
  --from-literal=DB_PASSWORD=supersecret123 \
  --dry-run=client -o yaml | kubectl apply -f -
pass "secret app-secrets applied"

step "TP07 - Apply manifests"

kubectl apply -f "$SCRIPT_DIR/k8s/configmap.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/postgres.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/app.yaml"
pass "manifests applied"

step "TP07 - Wait for postgres ready"

kubectl rollout status deployment/postgres -n "$NAMESPACE" --timeout=120s \
  && pass "postgres deployment ready" || fail "postgres not ready in time"

step "TP07 - Wait for app ready"

kubectl rollout status deployment/devops-app -n "$NAMESPACE" --timeout=120s \
  && pass "devops-app deployment ready" || fail "devops-app not ready in time"

step "TP07 - Check pods"

kubectl get pods -n "$NAMESPACE"
POD_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app=devops-app --field-selector=status.phase=Running --no-headers | wc -l)
if [ "$POD_COUNT" -ge 3 ]; then
  pass "$POD_COUNT app pods running"
else
  fail "expected 3 app pods, got $POD_COUNT"
fi

step "TP07 - Test app via port-forward"

kubectl port-forward svc/devops-app-svc 8080:80 -n "$NAMESPACE" &
PF_PID=$!
sleep 3

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
kill $PF_PID 2>/dev/null || true

if [ "$HTTP_STATUS" = "200" ]; then
  pass "app /health returns 200"
else
  fail "app /health returned $HTTP_STATUS"
fi

step "TP07 - Scaling test"

kubectl scale deployment devops-app --replicas=5 -n "$NAMESPACE"
kubectl rollout status deployment/devops-app -n "$NAMESPACE" --timeout=60s
POD_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app=devops-app --field-selector=status.phase=Running --no-headers | wc -l)
pass "scaled to $POD_COUNT pods"

kubectl scale deployment devops-app --replicas=3 -n "$NAMESPACE"
kubectl rollout status deployment/devops-app -n "$NAMESPACE" --timeout=60s
pass "scaled back to 3 pods"

step "TP07 - Cleanup"

kubectl delete namespace "$NAMESPACE"
pass "namespace $NAMESPACE deleted"

echo "======================"
echo "TP07 DONE"
echo "======================"
