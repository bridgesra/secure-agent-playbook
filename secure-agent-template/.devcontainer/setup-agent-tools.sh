#!/usr/bin/env bash
# Install jq (Claude status line), RTK (token-saving shell proxy), and agent hooks.
# Usage: setup-agent-tools.sh <claude|cursor|both>
set -euo pipefail

MODE="${1:-both}"
export PATH="/usr/local/bin:${HOME}/.local/bin:${PATH}"
RTK_INSTALLER="https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"

install_jq() {
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends jq
}

install_rtk() {
  if command -v rtk >/dev/null 2>&1 && rtk gain >/dev/null 2>&1; then
    return 0
  fi
  curl -fsSL "${RTK_INSTALLER}" | sudo env RTK_INSTALL_DIR=/usr/local/bin sh
}

prepare_claude_home() {
  sudo mkdir -p /home/vscode/.claude
  sudo chown -R vscode:vscode /home/vscode/.claude
  chmod 700 /home/vscode/.claude
}

# Cursor hooks are global-only. Claude auto-rewrite also needs -g.
init_claude() {
  rtk init -g --auto-patch --no-trust-filters
}

init_cursor() {
  rtk init -g --agent cursor --auto-patch --no-trust-filters
}

case "${MODE}" in
  claude)
    install_jq
    prepare_claude_home
    install_rtk
    init_claude
    ;;
  cursor)
    install_rtk
    init_cursor
    ;;
  both)
    install_jq
    prepare_claude_home
    install_rtk
    init_claude
    init_cursor
    ;;
  *)
    echo "Usage: $0 <claude|cursor|both>" >&2
    exit 1
    ;;
esac
