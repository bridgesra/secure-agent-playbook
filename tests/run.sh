#!/usr/bin/env bash
# Run playbook tests. Layers 1–2 always; Layer 3 when RUN_RUNTIME=1.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

failed=0
ran=0

run_test() {
  local path="$1"
  echo "======== ${path} ========"
  ran=$((ran + 1))
  if bash "${path}"; then
    echo "OK ${path}"
  else
    echo "NOT OK ${path}"
    failed=1
  fi
  echo
}

shopt -s nullglob
for f in tests/contract/*.sh tests/unit/*.sh tests/installer/*.sh; do
  run_test "${f}"
done

if [[ "${RUN_RUNTIME:-}" == "1" ]]; then
  for f in tests/runtime/*.sh; do
    run_test "${f}"
  done
fi

echo "======== summary ========"
if [[ "${ran}" -eq 0 ]]; then
  echo "No tests found."
  exit 1
fi
if [[ "${failed}" -ne 0 ]]; then
  echo "FAILED"
  exit 1
fi
echo "ALL OK"
exit 0
