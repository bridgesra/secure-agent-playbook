#!/usr/bin/env bash
# Case 1 image recipe embedded in secure-agent-playbook.sh.
set -u
source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

df="$(mktemp)"
extract_case1_dockerfile > "${df}"

if [[ ! -s "${df}" ]]; then
  fail "extracted Dockerfile is empty"
  rm -f "${df}"
  finish
  exit 1
fi
pass "extracted Dockerfile is non-empty"

assert_file_contains "${df}" "jq" "Dockerfile installs jq"
assert_file_contains "${df}" "@anthropic-ai/claude-code" "Dockerfile installs Claude Code"
assert_file_contains "${df}" "rtk" "Dockerfile installs RTK"
assert_file_contains "${df}" "headroom" "Dockerfile installs Headroom"
assert_file_contains "${df}" "HEADROOM_BEACON=off" "Dockerfile disables Headroom beacon"
assert_file_contains "${df}" "ANTHROPIC_BASE_URL=http://127.0.0.1:8787" "Dockerfile routes Claude through Headroom"
assert_file_contains "${df}" "headroom proxy --host 127.0.0.1 --port 8787" "entrypoint starts Headroom proxy"
assert_file_contains "${df}" 'exec claude "$@"' "entrypoint execs claude"

rm -f "${df}"
finish
