#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; }
section() { echo ""; echo "=================================================="; echo "# $1"; echo "=================================================="; }

RESULTS=()

run_tp() {
  local name="$1"
  local script="$2"

  section "$name"
  if bash "$script"; then
    RESULTS+=("PASS: $name")
  else
    RESULTS+=("FAIL: $name")
  fi
}

run_tp "TP03/04 - Terraform" "$SCRIPT_DIR/test-tp03-terraform.sh"
run_tp "TP05 - Ansible" "$SCRIPT_DIR/test-tp05-ansible.sh"
run_tp "TP06 - Docker Avance" "$SCRIPT_DIR/test-tp06-docker.sh"
run_tp "TP07 - Kubernetes" "$SCRIPT_DIR/test-tp07-kubernetes.sh"
run_tp "TP08 - Helm & Kustomize" "$SCRIPT_DIR/test-tp08-helm.sh"

echo ""
echo "=================================================="
echo "# RESULTS"
echo "=================================================="
for r in "${RESULTS[@]}"; do
  echo "  $r"
done

FAIL_COUNT=0
for r in "${RESULTS[@]}"; do
  if [[ "$r" == FAIL:* ]]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

echo ""
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "All TPs passed."
  exit 0
else
  echo "$FAIL_COUNT TP(s) failed."
  exit 1
fi
