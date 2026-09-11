#!/usr/bin/env bash
# start-headroom.sh: skip, already healthy, start, timeout still exit 0.
set -u
source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

START="${TEMPLATE}/.devcontainer/start-headroom.sh"
ISOLATED_CMDS=(bash dirname pwd mkdir chmod mv rm cat mktemp nohup sleep env)

run_start() {
  local work="$1"
  env \
    HOME="${work}/home" \
    CURL_HEALTH="${CURL_HEALTH:-fail}" \
    PATH="${work}/bin:${work}/isolated" \
    bash "${START}"
}

# --- headroom missing: skip, exit 0 ---
work="$(mktemp -d)"
mkdir -p "${work}/bin" "${work}/home" "${work}/isolated" "${work}/state"
: > "${work}/stub.log"
link_isolated_cmds "${work}/isolated" "${ISOLATED_CMDS[@]}"
write_curl_stub "${work}/bin/curl" "${work}/stub.log" "${work}/state"
set +e
run_start "${work}" >/tmp/start-missing.out 2>/tmp/start-missing.err
rc=$?
set -e
assert_exit 0 "${rc}" "missing headroom exits 0"
assert_file_contains /tmp/start-missing.err "headroom not installed" "missing headroom skip message"
assert_not_contains "$(cat "${work}/stub.log")" "headroom proxy" "missing headroom does not start proxy"
rm -rf "${work}"

# --- already healthy: exit 0, do not start ---
work="$(mktemp -d)"
mkdir -p "${work}/bin" "${work}/home" "${work}/isolated" "${work}/state"
: > "${work}/stub.log"
link_isolated_cmds "${work}/isolated" "${ISOLATED_CMDS[@]}"
write_headroom_stub "${work}/bin/headroom" "${work}/stub.log"
write_curl_stub "${work}/bin/curl" "${work}/stub.log" "${work}/state"
set +e
CURL_HEALTH=ok run_start "${work}" >/tmp/start-ok.out 2>/tmp/start-ok.err
rc=$?
set -e
assert_exit 0 "${rc}" "healthy proxy exits 0"
assert_not_contains "$(cat "${work}/stub.log")" "headroom proxy" "healthy proxy does not start again"
rm -rf "${work}"

# --- start path: first health fails, then ok; proxy invoked ---
work="$(mktemp -d)"
mkdir -p "${work}/bin" "${work}/home" "${work}/isolated" "${work}/state"
: > "${work}/stub.log"
touch "${work}/state/curl_fail_once"
link_isolated_cmds "${work}/isolated" "${ISOLATED_CMDS[@]}"
write_headroom_stub "${work}/bin/headroom" "${work}/stub.log"
write_curl_stub "${work}/bin/curl" "${work}/stub.log" "${work}/state"
set +e
CURL_HEALTH=ok run_start "${work}" >/tmp/start-start.out 2>/tmp/start-start.err
rc=$?
set -e
assert_exit 0 "${rc}" "start path exits 0"
assert_contains "$(cat "${work}/stub.log")" "headroom proxy --host 127.0.0.1 --port 8787" \
  "start path launches proxy on 127.0.0.1:8787"
rm -rf "${work}"

# --- timeout: health never ok; still exit 0 (must not fail container start) ---
work="$(mktemp -d)"
mkdir -p "${work}/bin" "${work}/home" "${work}/isolated" "${work}/state"
: > "${work}/stub.log"
link_isolated_cmds "${work}/isolated" "${ISOLATED_CMDS[@]}"
write_headroom_stub "${work}/bin/headroom" "${work}/stub.log"
write_curl_stub "${work}/bin/curl" "${work}/stub.log" "${work}/state"
set +e
CURL_HEALTH=fail run_start "${work}" >/tmp/start-timeout.out 2>/tmp/start-timeout.err
rc=$?
set -e
assert_exit 0 "${rc}" "unhealthy timeout exits 0"
assert_file_contains /tmp/start-timeout.err "proxy did not become healthy" "timeout warning"
assert_contains "$(cat "${work}/stub.log")" "headroom proxy --host 127.0.0.1 --port 8787" \
  "timeout path still launched proxy"
rm -rf "${work}"

finish
