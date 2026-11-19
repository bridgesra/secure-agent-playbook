#!/usr/bin/env bash
# setup-agent-tools.sh: default (no arg), legacy claude/both args, removed cursor mode, invalid arg.
set -u
source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

SETUP="${TEMPLATE}/.devcontainer/setup-agent-tools.sh"
ISOLATED_CMDS=(bash dirname pwd mkdir chmod mv rm cat mktemp nohup sleep env ln head tail)

make_mode_env() {
  local work="$1"
  local with_jq="$2"
  mkdir -p "${work}/home/.local/bin" "${work}/isolated" "${work}/claude" "${work}/state"
  : > "${work}/stub.log"
  write_rtk_stub "${work}/home/.local/bin/rtk" "${work}/stub.log"
  write_headroom_stub "${work}/home/.local/bin/headroom" "${work}/stub.log"
  write_curl_stub "${work}/home/.local/bin/curl" "${work}/stub.log" "${work}/state"
  write_stub "${work}/home/.local/bin/sudo" "${work}/stub.log"
  write_stub "${work}/home/.local/bin/apt-get" "${work}/stub.log"
  write_stub "${work}/home/.local/bin/uv" "${work}/stub.log"
  link_isolated_cmds "${work}/isolated" "${ISOLATED_CMDS[@]}"
  if [[ "${with_jq}" == "1" ]]; then
    ln -sf "$(command -v jq)" "${work}/isolated/jq"
  fi
}

run_setup() {
  local work="$1"
  shift
  env \
    HOME="${work}/home" \
    CLAUDE_HOME="${work}/claude" \
    CURL_HEALTH=ok \
    PATH="${work}/home/.local/bin:${work}/isolated" \
    bash "${SETUP}" "$@"
}

# Full Claude setup: Claude RTK hook, Headroom routing, no Cursor hook.
check_claude_setup() {
  local work="$1"
  local label="$2"
  local log
  log="$(cat "${work}/stub.log")"
  if grep -E '^rtk init -g --auto-patch --no-trust-filters$' "${work}/stub.log" >/dev/null; then
    pass "${label} registers RTK for Claude"
  else
    fail "${label} missing Claude RTK init"
  fi
  assert_not_contains "${log}" "--agent cursor" "${label} does not register Cursor RTK"
  assert_file "${work}/claude/settings.json" "${label} route_claude wrote settings"
  assert_jq "${work}/claude/settings.json" \
    '.env.ANTHROPIC_BASE_URL == "http://127.0.0.1:8787"' \
    "${label} settings route through Headroom"
  assert_contains "${log}" "curl" "${label} starts Headroom health check"
}

# --- default: no argument ---
work="$(mktemp -d)"
make_mode_env "${work}" 1
set +e
run_setup "${work}" >/tmp/setup-default.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "no-arg setup exits 0"
check_claude_setup "${work}" "no-arg"
rm -rf "${work}"

# --- legacy args from older devcontainer.json files ---
for legacy in claude both; do
  work="$(mktemp -d)"
  make_mode_env "${work}" 1
  set +e
  run_setup "${work}" "${legacy}" >/tmp/setup-${legacy}.out 2>&1
  rc=$?
  set -e
  assert_exit 0 "${rc}" "legacy ${legacy} arg exits 0"
  check_claude_setup "${work}" "legacy ${legacy}"
  rm -rf "${work}"
done

# --- removed cursor mode and invalid args are rejected ---
for bad in cursor nope; do
  work="$(mktemp -d)"
  make_mode_env "${work}" 1
  set +e
  run_setup "${work}" "${bad}" >/tmp/setup-${bad}.out 2>&1
  rc=$?
  set -e
  assert_exit 1 "${rc}" "${bad} arg exits 1"
  if [[ -f "${work}/claude/settings.json" ]]; then
    fail "${bad} arg still wrote Claude settings"
  else
    pass "${bad} arg made no changes"
  fi
  rm -rf "${work}"
done

finish
