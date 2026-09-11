#!/usr/bin/env bash
# claude-box docker argv (stub docker, no real container).
set -u
source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

fake="$(mktemp -d)"
export HOME="${fake}"
mkdir -p "${HOME}/.local/bin" "${HOME}/project"
: > "${HOME}/docker.log"
export DOCKER_LOG="${HOME}/docker.log"

cat > "${HOME}/.local/bin/docker" <<EOF
#!/usr/bin/env bash
echo "docker \$*" >> "${DOCKER_LOG}"
exit 0
EOF
chmod +x "${HOME}/.local/bin/docker"
export PATH="${HOME}/.local/bin:${PATH}"

helper_tmp="$(mktemp)"
extract_playbook_helpers > "${helper_tmp}"
# shellcheck disable=SC1090
source "${helper_tmp}"
rm -f "${helper_tmp}"

set +e
( cd "${HOME}/project" && claude-box --dangerously-skip-permissions ) >/tmp/claude-box.out 2>&1
rc=$?
set -e
assert_exit 0 "${rc}" "claude-box exits 0 with stub docker"

log="$(cat "${HOME}/docker.log")"
assert_contains "${log}" "claude-config-volume:/home/agent" "mounts auth volume at /home/agent"
assert_contains "${log}" "${HOME}/project:/workspace" "mounts project at /workspace"
assert_contains "${log}" "HOME=/home/agent" "sets HOME=/home/agent"
assert_contains "${log}" "CLAUDE_CONFIG_DIR=/home/agent/.claude" "sets CLAUDE_CONFIG_DIR"
assert_contains "${log}" "ANTHROPIC_BASE_URL=http://127.0.0.1:8787" "routes Claude through Headroom"
assert_contains "${log}" "HEADROOM_BEACON=off" "disables Headroom beacon"
assert_contains "${log}" "claude-secure-sandbox:latest" "uses Case 1 image"
assert_contains "${log}" "--dangerously-skip-permissions" "forwards extra args to the image"

rm -rf "${fake}"
finish
