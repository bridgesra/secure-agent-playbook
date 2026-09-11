#!/usr/bin/env bash
# One-time setup for the Secure Agent Playbook.
# Run from the repo root: ./secure-agent-playbook.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_SRC="${REPO_ROOT}/secure-agent-template"
TEMPLATE_DEST="${HOME}/.config/secure-agent-template"
SANDBOX_DIR="${HOME}/.config/claude-sandbox"
ZSHRC="${HOME}/.zshrc"
MARKER="# >>> secure-agent-playbook >>>"

if [[ ! -d "${TEMPLATE_SRC}" ]]; then
  echo "Error: secure-agent-template/ not found next to this script."
  exit 1
fi

echo "==> Installing project template to ${TEMPLATE_DEST}"
mkdir -p "${TEMPLATE_DEST}"
cp -R "${TEMPLATE_SRC}/." "${TEMPLATE_DEST}/"

echo "==> Building Claude Code sandbox image"
mkdir -p "${SANDBOX_DIR}"
cat > "${SANDBOX_DIR}/Dockerfile" <<'DOCKERFILE'
FROM node:20-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends git curl ca-certificates jq \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1001 -s /bin/bash claudeuser
RUN npm install -g @anthropic-ai/claude-code

RUN curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh \
  | RTK_INSTALL_DIR=/usr/local/bin sh

RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh \
  && mkdir -p /usr/local/share/uv/tools /usr/local/share/uv/python \
  && env \
    UV_TOOL_BIN_DIR=/usr/local/bin \
    UV_TOOL_DIR=/usr/local/share/uv/tools \
    UV_PYTHON_INSTALL_DIR=/usr/local/share/uv/python \
    uv tool install --python 3.13 "headroom-ai[proxy,mcp]"

ENV HEADROOM_BEACON=off \
    DO_NOT_TRACK=1 \
    ANTHROPIC_BASE_URL=http://127.0.0.1:8787

RUN cat >/usr/local/bin/claude-entrypoint.sh <<'EOF'
#!/bin/bash
export PATH="/usr/local/bin:${PATH}"
export HEADROOM_BEACON="${HEADROOM_BEACON:-off}"
export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-http://127.0.0.1:8787}"
if command -v rtk >/dev/null 2>&1; then
  rtk init -g --auto-patch --no-trust-filters >/dev/null 2>&1 || true
fi
if command -v headroom >/dev/null 2>&1; then
  mkdir -p "${HOME}/.headroom"
  if ! curl -sf --max-time 1 http://127.0.0.1:8787/health >/dev/null 2>&1; then
    nohup headroom proxy --host 127.0.0.1 --port 8787 >>"${HOME}/.headroom/proxy.log" 2>&1 &
    i=0
    while [ "${i}" -lt 30 ]; do
      if curl -sf --max-time 1 http://127.0.0.1:8787/health >/dev/null 2>&1; then
        break
      fi
      i=$((i + 1))
      sleep 1
    done
  fi
fi
exec claude "$@"
EOF
RUN chmod +x /usr/local/bin/claude-entrypoint.sh

WORKDIR /workspace
RUN chown -R claudeuser:claudeuser /workspace

USER claudeuser
ENTRYPOINT ["/usr/local/bin/claude-entrypoint.sh"]
DOCKERFILE

docker build -t claude-secure-sandbox:latest "${SANDBOX_DIR}"
docker volume create claude-config-volume >/dev/null 2>&1 || true

if grep -q "${MARKER}" "${ZSHRC}" 2>/dev/null; then
  echo "==> Updating shell helpers in ${ZSHRC}"
  _playbook_zshrc_tmp="$(mktemp)"
  awk '
    /# >>> secure-agent-playbook >>>/ { skip=1; next }
    /# <<< secure-agent-playbook <<</ { skip=0; next }
    !skip { print }
  ' "${ZSHRC}" > "${_playbook_zshrc_tmp}"
  mv "${_playbook_zshrc_tmp}" "${ZSHRC}"
  unset _playbook_zshrc_tmp
else
  echo "==> Adding shell helpers to ${ZSHRC}"
fi

cat >> "${ZSHRC}" <<'ZSH'

# >>> secure-agent-playbook >>>
# Scaffold a new project with Cursor + Claude ignore/rules files.
# Usage: new-project my-app [claude|cursor|both]
new-project() {
  local name="${1:-}"
  local mode="${2:-both}"

  if [[ -z "${name}" ]]; then
    echo "Usage: new-project <name> [claude|cursor|both]"
    return 1
  fi

  local dest
  dest="$(pwd)/${name}"
  local template="${HOME}/.config/secure-agent-template"

  if [[ ! -d "${template}" ]]; then
    echo "Run secure-agent-playbook.sh first."
    return 1
  fi

  mkdir -p "${dest}"
  cp -R "${template}/." "${dest}/"

  if [[ "${mode}" == "cursor" ]]; then
    cp "${dest}/.devcontainer/devcontainer.cursor-only.json" "${dest}/.devcontainer/devcontainer.json"
  fi

  cd "${dest}" || return 1
  echo "Created ${dest}"
  echo ""
  echo "Before your first git pull/push, run (inside the container if using cursor/both/claude-box):"
  echo "  git config --global credential.helper store"
  echo "  Credentials are saved after the first successful auth."

  case "${mode}" in
    claude)
      echo "Next: claude-box"
      ;;
    cursor)
      if command -v cursor >/dev/null 2>&1; then
        cursor .
      else
        echo "Next: cursor .  then Reopen in Container"
      fi
      ;;
    both)
      if command -v cursor >/dev/null 2>&1; then
        cursor .
      fi
      echo "Next: Reopen in Container, then run 'claude' in Cursor's integrated terminal"
      ;;
  esac
}

# Run Claude Code in an isolated container (Case 1).
claude-box() {
  local target_dir uid gid
  target_dir="$(pwd)"
  uid="$(id -u)"
  gid="$(id -g)"
  echo "Launching Claude Code sandbox for: ${target_dir}"

  # Docker volumes mount as root. Persist HOME + CLAUDE_CONFIG_DIR on the volume
  # so OAuth credentials and .claude.json survive across runs.
  docker run --rm \
    -v claude-config-volume:/home/agent \
    --user root \
    --entrypoint bash \
    claude-secure-sandbox:latest \
    -c "mkdir -p /home/agent/.claude && chown -R ${uid}:${gid} /home/agent && chmod 700 /home/agent/.claude"

  docker run --rm -it \
    --name "claude-agent-$(basename "${target_dir}")-$$" \
    -v "${target_dir}:/workspace" \
    -v claude-config-volume:/home/agent \
    -e HOME=/home/agent \
    -e CLAUDE_CONFIG_DIR=/home/agent/.claude \
    -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
    -e CLAUDE_CODE_OAUTH_TOKEN="${CLAUDE_CODE_OAUTH_TOKEN:-}" \
    -e HEADROOM_BEACON=off \
    -e DO_NOT_TRACK=1 \
    -e ANTHROPIC_BASE_URL=http://127.0.0.1:8787 \
    -u "${uid}:${gid}" \
    -w /workspace \
    claude-secure-sandbox:latest "$@"
}
# <<< secure-agent-playbook <<<
ZSH

echo ""
echo "Done. Run: source ~/.zshrc"
echo ""
echo "Optional: add auth to ~/.zshrc"
echo "  export ANTHROPIC_API_KEY=sk-ant-..."
echo ""
echo "Create projects:"
echo "  new-project my-app claude   # Claude Code only"
echo "  new-project my-app cursor   # Cursor only"
echo "  new-project my-app both     # Cursor + Claude (default)"
