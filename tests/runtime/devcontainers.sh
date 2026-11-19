#!/usr/bin/env bash
# Case 2 Dev Container smoke via @devcontainers/cli. Requires Docker.
set -u
source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

if ! command -v docker >/dev/null 2>&1; then
  fail "docker is required when RUN_RUNTIME=1"
  finish
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  fail "npx is required when RUN_RUNTIME=1"
  finish
  exit 1
fi

DC=(npx --yes @devcontainers/cli)

source_helpers() {
  local tmp
  tmp="$(mktemp)"
  extract_playbook_helpers > "${tmp}"
  # shellcheck disable=SC1090
  source "${tmp}"
  rm -f "${tmp}"
}

bringup() {
  local folder="$1"
  "${DC[@]}" up --workspace-folder "${folder}"
}

teardown() {
  local folder="$1"
  "${DC[@]}" down --workspace-folder "${folder}" >/dev/null 2>&1 || true
}

exec_in() {
  local folder="$1"
  shift
  "${DC[@]}" exec --workspace-folder "${folder}" -- "$@"
}

fake="$(mktemp -d)"
export HOME="${fake}"
mkdir -p "${HOME}/.config"
cp -R "${TEMPLATE}/." "${HOME}/.config/secure-agent-template/"
source_helpers

work="$(mktemp -d)"

# --- Case 2: VS Code Dev Container ---
set +e
( cd "${work}" && new-project case2 ) >/tmp/rt-case2-np.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "runtime new-project"

set +e
bringup "${work}/case2" >/tmp/rt-case2-up.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "Case 2 devcontainer up"

if [[ "${rc}" -eq 0 ]]; then
  set +e
  exec_in "${work}/case2" bash -lc 'command -v rtk && command -v headroom && command -v claude && command -v jq' \
    >/tmp/rt-case2-bins.out 2>&1
  rc=$?
  set -e
  assert_exit 0 "${rc}" "Case 2 has rtk, headroom, claude, jq"

  set +e
  exec_in "${work}/case2" bash -lc 'curl -sf --max-time 5 http://127.0.0.1:8787/health' >/tmp/rt-case2-health.out 2>&1
  rc=$?
  set -e
  assert_exit 0 "${rc}" "Case 2 Headroom health"
fi

teardown "${work}/case2"

rm -rf "${fake}" "${work}"
finish
