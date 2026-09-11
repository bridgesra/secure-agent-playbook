#!/usr/bin/env bash
# setup-agent-tools.sh modes: claude / cursor / both / invalid.
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
  local mode="$2"
  env \
    HOME="${work}/home" \
    CLAUDE_HOME="${work}/claude" \
    CURL_HEALTH=ok \
    PATH="${work}/home/.local/bin:${work}/isolated" \
    bash "${SETUP}" "${mode}"
}

# --- cursor: RTK cursor hook, Headroom start, no Claude routing / jq install ---
work="$(mktemp -d)"
make_mode_env "${work}" 0
set +e
run_setup "${work}" cursor >/tmp/setup-cursor.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "cursor mode exits 0"
log="$(cat "${work}/stub.log")"
assert_contains "${log}" "rtk init -g --agent cursor --auto-patch --no-trust-filters" \
  "cursor registers RTK for Cursor"
assert_not_contains "${log}" "rtk init -g --auto-patch --no-trust-filters" \
  "cursor does not register Claude-only RTK init line without --agent"
# The cursor line also contains "--auto-patch"; the Claude-only invocation is exactly
# "rtk init -g --auto-patch --no-trust-filters" with no --agent. Confirm via grep -x style:
if grep -E '^rtk init -g --auto-patch --no-trust-filters$' "${work}/stub.log" >/dev/null; then
  fail "cursor ran Claude RTK init"
else
  pass "cursor did not run Claude RTK init"
fi
assert_not_contains "${log}" "apt-get" "cursor does not install jq via apt-get"
if [[ -f "${work}/claude/settings.json" ]]; then
  fail "cursor wrote Claude settings (route_claude)"
else
  pass "cursor did not call route_claude"
fi
assert_contains "${log}" "curl" "cursor starts Headroom health check"
rm -rf "${work}"

# --- claude: jq path, Claude home, Claude RTK, route_claude, no cursor agent ---
work="$(mktemp -d)"
make_mode_env "${work}" 1
set +e
run_setup "${work}" claude >/tmp/setup-claude.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "claude mode exits 0"
log="$(cat "${work}/stub.log")"
if grep -E '^rtk init -g --auto-patch --no-trust-filters$' "${work}/stub.log" >/dev/null; then
  pass "claude registers RTK for Claude"
else
  fail "claude missing Claude RTK init"
fi
assert_not_contains "${log}" "--agent cursor" "claude does not register Cursor RTK"
assert_file "${work}/claude/settings.json" "claude route_claude wrote settings"
assert_jq "${work}/claude/settings.json" \
  '.env.ANTHROPIC_BASE_URL == "http://127.0.0.1:8787"' \
  "claude settings route through Headroom"
if [[ -d "${work}/claude" ]] && [[ -f "${work}/claude/settings.json" ]]; then
  pass "claude prepared CLAUDE_HOME"
fi
rm -rf "${work}"

# --- both: union ---
work="$(mktemp -d)"
make_mode_env "${work}" 1
set +e
run_setup "${work}" both >/tmp/setup-both.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "both mode exits 0"
log="$(cat "${work}/stub.log")"
if grep -E '^rtk init -g --auto-patch --no-trust-filters$' "${work}/stub.log" >/dev/null; then
  pass "both registers RTK for Claude"
else
  fail "both missing Claude RTK init"
fi
assert_contains "${log}" "rtk init -g --agent cursor --auto-patch --no-trust-filters" \
  "both registers RTK for Cursor"
assert_file "${work}/claude/settings.json" "both route_claude wrote settings"
assert_jq "${work}/claude/settings.json" \
  '.env.ANTHROPIC_BASE_URL == "http://127.0.0.1:8787"' \
  "both settings route through Headroom"
rm -rf "${work}"

# --- invalid mode ---
work="$(mktemp -d)"
make_mode_env "${work}" 1
set +e
run_setup "${work}" nope >/tmp/setup-nope.out 2>&1
rc=$?
set -e
assert_exit 1 "${rc}" "invalid mode exits 1"
rm -rf "${work}"

finish
