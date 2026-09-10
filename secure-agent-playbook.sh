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

WORKDIR /workspace
RUN chown -R claudeuser:claudeuser /workspace

USER claudeuser
ENTRYPOINT ["claude"]
DOCKERFILE

docker build -t claude-secure-sandbox:latest "${SANDBOX_DIR}"
docker volume create claude-config-volume >/dev/null 2>&1 || true

if grep -q "${MARKER}" "${ZSHRC}" 2>/dev/null; then
  echo "==> Updating shell helpers in ${ZSHRC}"
  sed -i '' "/${MARKER}/,/# <<< secure-agent-playbook <<</d" "${ZSHRC}"
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
