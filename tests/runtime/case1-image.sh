#!/usr/bin/env bash
# Case 1 image smoke: binaries, Headroom health via entrypoint. Requires Docker.
set -u
source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

if ! command -v docker >/dev/null 2>&1; then
  fail "docker is required when RUN_RUNTIME=1"
  finish
  exit 1
fi

work="$(mktemp -d)"
extract_case1_dockerfile > "${work}/Dockerfile"
if [[ ! -s "${work}/Dockerfile" ]]; then
  fail "could not extract Case 1 Dockerfile"
  rm -rf "${work}"
  finish
  exit 1
fi

set +e
docker build -t playbook-test-case1:test "${work}" >/tmp/case1-build.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "Case 1 image builds"

if [[ "${rc}" -ne 0 ]]; then
  fail "docker build failed; see /tmp/case1-build.out"
  rm -rf "${work}"
  finish
  exit 1
fi

set +e
docker run --rm --entrypoint bash playbook-test-case1:test -c \
  'command -v jq && command -v rtk && command -v headroom && command -v claude' \
  >/tmp/case1-bins.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "Case 1 image has jq, rtk, headroom, claude"

mkdir -p "${work}/stub"
cat > "${work}/stub/claude" <<'EOF'
#!/bin/bash
curl -sf --max-time 5 http://127.0.0.1:8787/health
EOF
chmod +x "${work}/stub/claude"

set +e
docker run --rm \
  -e HOME=/tmp/agent \
  -e HEADROOM_BEACON=off \
  -v "${work}/stub/claude:/usr/local/bin/claude" \
  playbook-test-case1:test >/tmp/case1-health.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "entrypoint starts Headroom; health check succeeds"

set +e
docker run --rm --entrypoint bash playbook-test-case1:test -c \
  'rtk init --show 2>/dev/null || rtk init -g --auto-patch --no-trust-filters >/dev/null; rtk init --show' \
  >/tmp/case1-rtk.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "rtk init --show runs in Case 1 image"
assert_file_contains /tmp/case1-rtk.out "rtk" "rtk hook output mentions rtk"

rm -rf "${work}"
finish
