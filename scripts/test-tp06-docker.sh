#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }
step() { echo ""; echo "==> $1"; }

step "TP06 - Build image bad"

docker build -f "$SCRIPT_DIR/app/Dockerfile.bad" -t app:bad "$SCRIPT_DIR/app/" \
  && pass "app:bad built" || fail "app:bad build failed"

step "TP06 - Build image optimized"

docker build -t app:optimized "$SCRIPT_DIR/app/" \
  && pass "app:optimized built" || fail "app:optimized build failed"

docker build -t devops-app:1.0.0 "$SCRIPT_DIR/app/" \
  && pass "devops-app:1.0.0 built" || fail "devops-app:1.0.0 build failed"

step "TP06 - Image size comparison"

echo "Image sizes:"
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep -E "app:bad|app:optimized"

BAD_SIZE=$(docker image inspect app:bad --format='{{.Size}}')
OPT_SIZE=$(docker image inspect app:optimized --format='{{.Size}}')

if [ "$OPT_SIZE" -lt "$BAD_SIZE" ]; then
  pass "optimized image ($OPT_SIZE bytes) smaller than bad ($BAD_SIZE bytes)"
else
  fail "optimized image is NOT smaller than bad image"
fi

step "TP06 - Non-root user check"

USER=$(docker run --rm app:optimized whoami)
if [ "$USER" = "appuser" ]; then
  pass "container runs as non-root: $USER"
else
  fail "container runs as root or unexpected user: $USER"
fi

step "TP06 - Start docker compose stack"

cd "$SCRIPT_DIR"
docker compose down -v 2>/dev/null || true
docker compose up -d --build
echo "Waiting for services to be healthy..."
sleep 15

step "TP06 - Health checks"

docker compose ps

NGINX_RUNNING=$(docker compose ps --status running --services 2>/dev/null | grep -c nginx || true)
if [ "$NGINX_RUNNING" -eq 0 ]; then
  echo "nginx container logs:"
  docker compose logs nginx
  fail "nginx container is not running (port 80 probablement occupé sur l'hôte)"
fi

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/health || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
  pass "nginx /health returns 200"
else
  fail "nginx /health returned $HTTP_STATUS"
fi

APP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health || echo "000")
if [ "$APP_STATUS" = "200" ]; then
  pass "app /health returns 200"
else
  fail "app /health returned $APP_STATUS"
fi

ROOT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/ || echo "000")
if [ "$ROOT_STATUS" = "200" ]; then
  pass "nginx / returns 200"
else
  fail "nginx / returned $ROOT_STATUS"
fi

step "TP06 - Cleanup"

docker compose down -v
pass "stack stopped and volumes removed"

echo "======================"
echo "TP06 DONE"
echo "======================"
