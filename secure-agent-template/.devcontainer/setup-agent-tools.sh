#!/usr/bin/env bash
# Install jq (Claude status line), RTK, Headroom, and agent hooks.
# Usage: setup-agent-tools.sh <claude|cursor|both>
set -euo pipefail

MODE="${1:-both}"
export PATH="/usr/local/bin:${HOME}/.local/bin:${PATH}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RTK_INSTALLER="https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"
UV_INSTALLER="https://astral.sh/uv/install.sh"

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

install_uv() {
  if [[ -x /usr/local/bin/uv ]]; then
    return 0
  fi
  curl -LsSf "${UV_INSTALLER}" | sudo env UV_INSTALL_DIR=/usr/local/bin sh
}

install_headroom() {
  if [[ -x /usr/local/bin/headroom ]] && /usr/local/bin/headroom --version >/dev/null 2>&1; then
    return 0
  fi
  install_uv
  sudo mkdir -p /usr/local/share/uv/tools /usr/local/share/uv/python
  sudo env \
    PATH="/usr/local/bin:${PATH}" \
    UV_TOOL_BIN_DIR=/usr/local/bin \
    UV_TOOL_DIR=/usr/local/share/uv/tools \
    UV_PYTHON_INSTALL_DIR=/usr/local/share/uv/python \
    uv tool install --python 3.13 "headroom-ai[proxy,mcp]"
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

# Route Claude Code (CLI + sidebar extension) through the local Headroom proxy.
# ENABLE_TOOL_SEARCH=false avoids "unsupported content type" in the VS Code webview.
route_claude() {
  local settings="/home/vscode/.claude/settings.json"
  local tmp
  if [[ ! -f "${settings}" ]]; then
    echo '{}' > "${settings}"
  fi
  tmp="$(mktemp)"
  jq --arg url "http://127.0.0.1:8787" '
    .env = (.env // {}) |
    .env.ANTHROPIC_BASE_URL = $url |
    .env.ENABLE_TOOL_SEARCH = "false"
  ' "${settings}" > "${tmp}"
  mv "${tmp}" "${settings}"
}

start_headroom() {
  bash "${SCRIPT_DIR}/start-headroom.sh"
}

case "${MODE}" in
  claude)
    install_jq
    prepare_claude_home
    install_rtk
    install_headroom
    init_claude
    route_claude
    start_headroom
    ;;
  cursor)
    install_rtk
    install_headroom
    init_cursor
    start_headroom
    ;;
  both)
    install_jq
    prepare_claude_home
    install_rtk
    install_headroom
    init_claude
    init_cursor
    route_claude
    start_headroom
    ;;
  *)
    echo "Usage: $0 <claude|cursor|both>" >&2
    exit 1
    ;;
esac
