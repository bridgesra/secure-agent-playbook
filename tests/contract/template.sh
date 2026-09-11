#!/usr/bin/env bash
# Template inventory, JSON parse, and shipped-script syntax.
set -u
source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

required_files=(
  ".cursorignore"
  ".cursor/mcp.json"
  ".cursor/rules/global-standards.mdc"
  ".claudeignore"
  ".claude/settings.json"
  ".claude/statusline.sh"
  ".claude/skills/folder-explore/SKILL.md"
  "CLAUDE.md"
  "notes.md"
  ".gitignore"
  ".devcontainer/devcontainer.json"
  ".devcontainer/devcontainer.cursor-only.json"
  ".devcontainer/setup-agent-tools.sh"
  ".devcontainer/start-headroom.sh"
)

for rel in "${required_files[@]}"; do
  assert_file "${TEMPLATE}/${rel}" "template has ${rel}"
done

json_files=(
  "${TEMPLATE}/.cursor/mcp.json"
  "${TEMPLATE}/.claude/settings.json"
  "${TEMPLATE}/.devcontainer/devcontainer.json"
  "${TEMPLATE}/.devcontainer/devcontainer.cursor-only.json"
)

for jf in "${json_files[@]}"; do
  assert_json "${jf}"
done

scripts=(
  "${REPO_ROOT}/secure-agent-playbook.sh"
  "${TEMPLATE}/.devcontainer/setup-agent-tools.sh"
  "${TEMPLATE}/.devcontainer/start-headroom.sh"
  "${TEMPLATE}/.claude/statusline.sh"
  "${REPO_ROOT}/tests/run.sh"
  "${REPO_ROOT}/tests/helpers.sh"
)

for sh in "${scripts[@]}"; do
  if bash -n "${sh}" 2>/tmp/bash-n.err; then
    pass "bash -n $(basename "${sh}")"
  else
    fail "bash -n ${sh}: $(cat /tmp/bash-n.err)"
  fi
done

if command -v zsh >/dev/null 2>&1; then
  helper_tmp="$(mktemp)"
  extract_playbook_helpers > "${helper_tmp}"
  if zsh -n "${helper_tmp}" 2>/tmp/zsh-n.err; then
    pass "zsh -n playbook helpers"
  else
    fail "zsh -n helpers: $(cat /tmp/zsh-n.err)"
  fi
  rm -f "${helper_tmp}"
else
  fail "zsh not available for helper syntax check"
fi

finish
