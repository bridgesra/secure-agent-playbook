# Shared helpers for playbook tests. Source from a test file; do not execute.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${REPO_ROOT}/secure-agent-template"
PASSES=0
FAILS=0

pass() {
  echo "  PASS: $*"
  PASSES=$((PASSES + 1))
}

fail() {
  echo "  FAIL: $*"
  FAILS=$((FAILS + 1))
}

assert_eq() {
  local expected="$1" actual="$2" msg="${3:-assert_eq}"
  if [[ "${expected}" == "${actual}" ]]; then
    pass "${msg}"
  else
    fail "${msg}: expected '${expected}' got '${actual}'"
  fi
}

assert_exit() {
  local expected="$1" actual="$2" msg="${3:-exit status}"
  assert_eq "${expected}" "${actual}" "${msg}"
}

assert_file() {
  local path="$1" msg="${2:-file exists: $1}"
  if [[ -f "${path}" ]]; then
    pass "${msg}"
  else
    fail "missing file: ${path}"
  fi
}

assert_dir() {
  local path="$1" msg="${2:-dir exists: $1}"
  if [[ -d "${path}" ]]; then
    pass "${msg}"
  else
    fail "missing dir: ${path}"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-contains '${needle}'}"
  if [[ "${haystack}" == *"${needle}"* ]]; then
    pass "${msg}"
  else
    fail "${msg}: needle not found"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="${3:-does not contain '${needle}'}"
  if [[ "${haystack}" == *"${needle}"* ]]; then
    fail "${msg}: unexpectedly found '${needle}'"
  else
    pass "${msg}"
  fi
}

assert_file_contains() {
  local path="$1" needle="$2" msg="${3:-${path} contains '${needle}'}"
  if [[ ! -f "${path}" ]]; then
    fail "${msg}: file missing"
    return
  fi
  if grep -q -- "${needle}" "${path}"; then
    pass "${msg}"
  else
    fail "${msg}"
  fi
}

assert_file_not_contains() {
  local path="$1" needle="$2" msg="${3:-${path} lacks '${needle}'}"
  if [[ ! -f "${path}" ]]; then
    fail "${msg}: file missing"
    return
  fi
  if grep -q -- "${needle}" "${path}"; then
    fail "${msg}: unexpectedly found '${needle}'"
  else
    pass "${msg}"
  fi
}

assert_json() {
  local path="$1"
  if jq empty "${path}" >/dev/null 2>&1; then
    pass "json ok: ${path}"
  else
    fail "invalid json: ${path}"
  fi
}

assert_jq() {
  local path="$1" expr="$2" msg="${3:-jq ${expr} on ${path}}"
  if jq -e "${expr}" "${path}" >/dev/null 2>&1; then
    pass "${msg}"
  else
    fail "${msg}"
  fi
}

extract_case1_dockerfile() {
  sed -n "/<<'DOCKERFILE'/,/^DOCKERFILE$/p" "${REPO_ROOT}/secure-agent-playbook.sh" | sed '1d;$d'
}

extract_playbook_helpers() {
  sed -n '/^# >>> secure-agent-playbook >>>/,/^# <<< secure-agent-playbook <<</p' \
    "${REPO_ROOT}/secure-agent-playbook.sh"
}

write_stub() {
  local dest="$1"
  local log="${2}"
  cat > "${dest}" <<EOF
#!/usr/bin/env bash
echo "\$(basename "\$0") \$*" >> "${log}"
exit 0
EOF
  chmod +x "${dest}"
}

# rtk stub: implements gain / init / --version and logs argv.
write_rtk_stub() {
  local dest="$1"
  local log="$2"
  cat > "${dest}" <<EOF
#!/usr/bin/env bash
echo "rtk \$*" >> "${log}"
case "\${1:-}" in
  gain|--version) exit 0 ;;
  init) exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "${dest}"
}

# headroom stub: --version ok; proxy records args and exits.
write_headroom_stub() {
  local dest="$1"
  local log="$2"
  cat > "${dest}" <<EOF
#!/usr/bin/env bash
echo "headroom \$*" >> "${log}"
case "\${1:-}" in
  --version) echo "headroom-stub"; exit 0 ;;
  proxy) exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "${dest}"
}

# curl stub. CURL_HEALTH=ok|fail (default fail). CURL_FAIL_ONCE file: first health check fails.
write_curl_stub() {
  local dest="$1"
  local log="$2"
  local state_dir="$3"
  cat > "${dest}" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${log}"
if [[ "\$*" == *"/health"* ]]; then
  if [[ -f "${state_dir}/curl_fail_once" ]]; then
    rm -f "${state_dir}/curl_fail_once"
    exit 1
  fi
  if [[ "\${CURL_HEALTH:-fail}" == "ok" ]]; then
    exit 0
  fi
  exit 1
fi
exit 0
EOF
  chmod +x "${dest}"
}

# Isolated PATH: real utils plus stubs, optionally without jq.
link_isolated_cmds() {
  local dest="$1"
  shift
  mkdir -p "${dest}"
  local cmd src
  for cmd in "$@"; do
    src="$(command -v "${cmd}")" || continue
    ln -sf "${src}" "${dest}/${cmd}"
  done
}

finish() {
  echo "--- ${PASSES} passed, ${FAILS} failed ---"
  if [[ "${FAILS}" -ne 0 ]]; then
    return 1
  fi
  return 0
}
