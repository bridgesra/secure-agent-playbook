#!/usr/bin/env bash
# Case 2 / Case 3 Dev Container smokes via @devcontainers/cli. Requires Docker.
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

# --- Case 2 cursor ---
set +e
( cd "${work}" && new-project case2-cursor cursor ) >/tmp/rt-case2-np.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "runtime new-project cursor"

set +e
bringup "${work}/case2-cursor" >/tmp/rt-case2-up.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "Case 2 devcontainer up"

if [[ "${rc}" -eq 0 ]]; then
  set +e
  exec_in "${work}/case2-cursor" bash -lc 'command -v rtk && command -v headroom' >/tmp/rt-case2-bins.out 2>&1
  rc=$?
  set -e
  assert_exit 0 "${rc}" "Case 2 has rtk and headroom"

  set +e
  exec_in "${work}/case2-cursor" bash -lc 'curl -sf --max-time 5 http://127.0.0.1:8787/health' >/tmp/rt-case2-health.out 2>&1
  rc=$?
  set -e
  assert_exit 0 "${rc}" "Case 2 Headroom health"

  set +e
  exec_in "${work}/case2-cursor" bash -lc 'command -v claude' >/tmp/rt-case2-claude.out 2>&1
  rc=$?
  set -e
  assert_exit 1 "${rc}" "Case 2 does not require claude"
fi

teardown "${work}/case2-cursor"

# --- Case 3 both ---
set +e
( cd "${work}" && new-project case3-both both ) >/tmp/rt-case3-np.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "runtime new-project both"

set +e
bringup "${work}/case3-both" >/tmp/rt-case3-up.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "Case 3 devcontainer up"

if [[ "${rc}" -eq 0 ]]; then
  set +e
  exec_in "${work}/case3-both" bash -lc 'command -v rtk && command -v headroom && command -v claude && command -v jq' \
    >/tmp/rt-case3-bins.out 2>&1
  rc=$?
  set -e
  assert_exit 0 "${rc}" "Case 3 has rtk, headroom, claude, jq"

  set +e
  exec_in "${work}/case3-both" bash -lc 'curl -sf --max-time 5 http://127.0.0.1:8787/health' >/tmp/rt-case3-health.out 2>&1
  rc=$?
  set -e
  assert_exit 0 "${rc}" "Case 3 Headroom health"
fi

teardown "${work}/case3-both"

rm -rf "${fake}" "${work}"
finish
