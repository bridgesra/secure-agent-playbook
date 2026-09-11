#!/usr/bin/env bash
# Installer (fake HOME, stub docker) and new-project claude / cursor / both.
set -u
source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

source_helpers_from() {
  local zshrc="$1"
  local tmp
  tmp="$(mktemp)"
  sed -n '/^# >>> secure-agent-playbook >>>/,/^# <<< secure-agent-playbook <<</p' "${zshrc}" > "${tmp}"
  # shellcheck disable=SC1090
  source "${tmp}"
  rm -f "${tmp}"
}

fake="$(mktemp -d)"
export HOME="${fake}"
mkdir -p "${HOME}/.local/bin"
: > "${HOME}/docker.log"
export DOCKER_LOG="${HOME}/docker.log"

cat > "${HOME}/.local/bin/docker" <<EOF
#!/usr/bin/env bash
echo "docker \$*" >> "${DOCKER_LOG}"
exit 0
EOF
chmod +x "${HOME}/.local/bin/docker"
export PATH="${HOME}/.local/bin:${PATH}"

set +e
bash "${REPO_ROOT}/secure-agent-playbook.sh" >/tmp/playbook-install.out 2>/tmp/playbook-install.err
rc=$?
set -e
assert_exit 0 "${rc}" "installer exits 0"
assert_dir "${HOME}/.config/secure-agent-template" "installer copied template"
assert_file "${HOME}/.config/secure-agent-template/.claude/settings.json" \
  "installer template includes Claude settings"
assert_file "${HOME}/.config/claude-sandbox/Dockerfile" "installer wrote Case 1 Dockerfile"
assert_file_contains "${HOME}/.config/claude-sandbox/Dockerfile" "@anthropic-ai/claude-code" \
  "generated Dockerfile installs Claude Code"
assert_file "${HOME}/.zshrc" "installer wrote zshrc"
assert_file_contains "${HOME}/.zshrc" "# >>> secure-agent-playbook >>>" "zshrc open marker"
assert_file_contains "${HOME}/.zshrc" "# <<< secure-agent-playbook <<<" "zshrc close marker"
assert_file_contains "${HOME}/docker.log" "docker build" "installer called docker build"
assert_file_contains "${HOME}/docker.log" "docker volume create" "installer created auth volume"

# Re-run must replace helpers, not duplicate the block.
set +e
bash "${REPO_ROOT}/secure-agent-playbook.sh" >/tmp/playbook-reinstall.out 2>/tmp/playbook-reinstall.err
rc=$?
set -e
assert_exit 0 "${rc}" "installer re-run exits 0"
marker_count="$(grep -c '# >>> secure-agent-playbook >>>' "${HOME}/.zshrc" || true)"
assert_eq "1" "${marker_count}" "re-run does not duplicate zshrc markers"

source_helpers_from "${HOME}/.zshrc"

work="$(mktemp -d)"

# missing name
set +e
( cd "${work}" && new-project ) >/tmp/np-noname.out 2>&1
rc=$?
set -e
assert_exit 1 "${rc}" "new-project without name exits 1"

# claude: keep both-mode devcontainer
set +e
( cd "${work}" && new-project proj-claude claude ) >/tmp/np-claude.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "new-project claude exits 0"
assert_file "${work}/proj-claude/.devcontainer/devcontainer.json" "claude project has devcontainer.json"
assert_jq "${work}/proj-claude/.devcontainer/devcontainer.json" \
  '.features | has("ghcr.io/anthropics/devcontainer-features/claude-code:1.0")' \
  "claude mode keeps both-mode recipe"
assert_jq "${work}/proj-claude/.cursor/mcp.json" \
  '.mcpServers.headroom.command == "/usr/local/bin/headroom"' \
  "claude project copies Headroom MCP"
assert_file "${work}/proj-claude/.claude/statusline.sh" "claude project copies statusline"

# cursor: swap recipe
set +e
( cd "${work}" && new-project proj-cursor cursor ) >/tmp/np-cursor.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "new-project cursor exits 0"
assert_jq "${work}/proj-cursor/.devcontainer/devcontainer.json" \
  '.postCreateCommand == "bash .devcontainer/setup-agent-tools.sh cursor"' \
  "cursor mode swaps in cursor-only recipe"
assert_jq "${work}/proj-cursor/.devcontainer/devcontainer.json" \
  '.features | has("ghcr.io/anthropics/devcontainer-features/claude-code:1.0") | not' \
  "cursor mode has no Claude Code feature"

# both (explicit) and default
set +e
( cd "${work}" && new-project proj-both both ) >/tmp/np-both.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "new-project both exits 0"
assert_jq "${work}/proj-both/.devcontainer/devcontainer.json" \
  '.postCreateCommand == "bash .devcontainer/setup-agent-tools.sh both"' \
  "both mode keeps both recipe"

set +e
( cd "${work}" && new-project proj-default ) >/tmp/np-default.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "new-project default exits 0"
assert_jq "${work}/proj-default/.devcontainer/devcontainer.json" \
  '.postCreateCommand == "bash .devcontainer/setup-agent-tools.sh both"' \
  "new-project default mode is both"

# missing template
rm -rf "${HOME}/.config/secure-agent-template"
set +e
( cd "${work}" && new-project proj-missing claude ) >/tmp/np-missing.out 2>&1
rc=$?
set -e
assert_exit 1 "${rc}" "new-project without template exits 1"
assert_file_contains /tmp/np-missing.out "secure-agent-playbook.sh first" \
  "missing template tells user to run installer"

rm -rf "${fake}" "${work}"
finish
