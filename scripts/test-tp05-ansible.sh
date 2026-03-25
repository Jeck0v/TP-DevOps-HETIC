#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/infra/ansible"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }
step() { echo ""; echo "==> $1"; }

step "TP05 - Ansible syntax checks"

ansible-playbook --syntax-check -i "$ANSIBLE_DIR/inventory.yml" "$ANSIBLE_DIR/playbook-base.yml" \
  && pass "playbook-base.yml syntax OK" || fail "playbook-base.yml syntax error"

ansible-playbook --syntax-check -i "$ANSIBLE_DIR/inventory.yml" "$ANSIBLE_DIR/playbook-nginx.yml" \
  && pass "playbook-nginx.yml syntax OK" || fail "playbook-nginx.yml syntax error"

ansible-playbook --syntax-check -i "$ANSIBLE_DIR/inventory.yml" "$ANSIBLE_DIR/site.yml" \
  && pass "site.yml syntax OK" || fail "site.yml syntax error"

step "TP05 - Start Docker nodes"

cd "$ANSIBLE_DIR"
docker compose up -d
sleep 2

step "TP05 - Bootstrap Python on nodes"

ansible all -i "$ANSIBLE_DIR/inventory.yml" -m raw \
  -a "apt-get update -qq && apt-get install -y -qq python3 sudo" \
  && pass "python3 + sudo installed on all nodes" || fail "python3/sudo install failed"

step "TP05 - Ansible ping"

ansible all -i "$ANSIBLE_DIR/inventory.yml" -m ping \
  && pass "ansible ping all nodes OK" || fail "ansible ping failed"

step "TP05 - Run playbook-base"

ansible-playbook -i "$ANSIBLE_DIR/inventory.yml" "$ANSIBLE_DIR/playbook-base.yml" \
  && pass "playbook-base run OK" || fail "playbook-base run failed"

step "TP05 - Idempotence check (second run must show changed=0)"

OUTPUT=$(ansible-playbook -i "$ANSIBLE_DIR/inventory.yml" "$ANSIBLE_DIR/playbook-base.yml" 2>&1)
echo "$OUTPUT"
if echo "$OUTPUT" | grep -q "changed=0"; then
  pass "idempotence OK (changed=0)"
else
  fail "idempotence FAILED (changed != 0)"
fi

step "TP05 - Run site.yml with roles"

ansible-playbook -i "$ANSIBLE_DIR/inventory.yml" "$ANSIBLE_DIR/site.yml" \
  && pass "site.yml with roles OK" || fail "site.yml with roles failed"

step "TP05 - Cleanup"

docker compose down
pass "Docker nodes stopped"

echo "======================"
echo "TP05 DONE"
echo "======================"
