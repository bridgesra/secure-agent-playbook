#!/usr/bin/env bash
# statusline.sh: fixture JSON in, context / model / 5h / 7d out.
set -u
source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

STATUSLINE="${TEMPLATE}/.claude/statusline.sh"
FIXTURES="$(cd "$(dirname "$0")/../fixtures" && pwd)"
SESSION_FILE="/tmp/claude_session_start"
HISTORY_FILE="/tmp/claude_budget_history"

backup_tmp() {
  rm -f "${SESSION_FILE}.bak" "${HISTORY_FILE}.bak"
  [[ -f "${SESSION_FILE}" ]] && cp "${SESSION_FILE}" "${SESSION_FILE}.bak"
  [[ -f "${HISTORY_FILE}" ]] && cp "${HISTORY_FILE}" "${HISTORY_FILE}.bak"
  rm -f "${SESSION_FILE}" "${HISTORY_FILE}"
}

restore_tmp() {
  rm -f "${SESSION_FILE}" "${HISTORY_FILE}"
  [[ -f "${SESSION_FILE}.bak" ]] && mv "${SESSION_FILE}.bak" "${SESSION_FILE}"
  [[ -f "${HISTORY_FILE}.bak" ]] && mv "${HISTORY_FILE}.bak" "${HISTORY_FILE}"
}

run_statusline() {
  local fixture="$1"
  backup_tmp
  local out rc
  set +e
  out="$(cat "${fixture}" | bash "${STATUSLINE}" 2>/dev/null)"
  rc=$?
  set -e
  restore_tmp
  printf '%s\n' "${out}"
  return "${rc}"
}

check_payload() {
  local fixture="$1" context="$2" model="$3"
  local out rc
  set +e
  out="$(run_statusline "${fixture}")"
  rc=$?
  set -e
  assert_exit 0 "${rc}" "$(basename "${fixture}") exits 0"
  assert_contains "${out}" "Context: ${context}%" "$(basename "${fixture}") context ${context}%"
  assert_contains "${out}" "${model}" "$(basename "${fixture}") model ${model}"
  assert_contains "${out}" "5h:" "$(basename "${fixture}") 5h line"
  assert_contains "${out}" "7d:" "$(basename "${fixture}") 7d line"
}

# run_statusline uses set -e internally via restore; disable -e around it
set +e
check_payload "${FIXTURES}/statusline-low.json" "20" "Test Haiku"
check_payload "${FIXTURES}/statusline-mid.json" "70" "Test Sonnet"
check_payload "${FIXTURES}/statusline-high.json" "90" "Test Opus"

out="$(run_statusline "${FIXTURES}/statusline-missing-limits.json")"
rc=$?
set -e
assert_exit 0 "${rc}" "missing limits exits 0"
assert_contains "${out}" "Context: 15%" "missing limits context"
assert_contains "${out}" "Bare Model" "missing limits model"
assert_contains "${out}" "5h:" "missing limits still prints 5h"
assert_contains "${out}" "7d:" "missing limits still prints 7d"
assert_contains "${out}" "0%" "missing limits default to 0%"

finish
