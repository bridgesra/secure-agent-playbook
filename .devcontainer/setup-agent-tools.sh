#!/usr/bin/env bash
# Install jq (Claude status line), RTK, Headroom, and the Claude Code hooks.
# Usage: setup-agent-tools.sh
# A legacy mode argument (claude|both) from older devcontainer.json files is accepted.
set -euo pipefail

MODE="${1:-claude}"
# Append (not prepend) so an existing PATH entry wins; installs still land in /usr/local/bin.
export PATH="${PATH}:/usr/local/bin:${HOME}/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-/home/vscode/.claude}"
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
  if command -v headroom >/dev/null 2>&1 && headroom --version >/dev/null 2>&1; then
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
  if [[ "${CLAUDE_HOME}" != "/home/vscode/.claude" ]]; then
    mkdir -p "${CLAUDE_HOME}"
    chmod 700 "${CLAUDE_HOME}"
    return 0
  fi
  sudo mkdir -p /home/vscode/.claude
  sudo chown -R vscode:vscode /home/vscode/.claude
  chmod 700 /home/vscode/.claude
}

# Claude auto-rewrite needs the global (-g) hook.
init_claude() {
  rtk init -g --auto-patch --no-trust-filters
}

# Route Claude Code (CLI + sidebar extension) through the local Headroom proxy.
# ENABLE_TOOL_SEARCH=false avoids "unsupported content type" in the VS Code webview.
route_claude() {
  local settings="${CLAUDE_HOME}/settings.json"
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
  claude|both)
    install_jq
    prepare_claude_home
    install_rtk
    install_headroom
    init_claude
    route_claude
    start_headroom
    ;;
  *)
    echo "Usage: $0 [claude]  (Cursor support was removed; got '${MODE}')" >&2
    exit 1
    ;;
esac
