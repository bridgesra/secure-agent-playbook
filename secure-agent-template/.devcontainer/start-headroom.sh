#!/usr/bin/env bash
# Start the Headroom compression proxy if it is not already healthy.
# Safe to re-run (postCreate and postStart). Does not fail container startup.
set -u

# Append (not prepend) so an existing PATH entry wins. Tests set
# AGENT_TOOLS_EXTRA_PATH="" so a real /usr/local/bin/headroom can't leak in.
extra_path="${AGENT_TOOLS_EXTRA_PATH-/usr/local/bin:${HOME}/.local/bin}"
if [[ -n "${extra_path}" ]]; then
  export PATH="${PATH}:${extra_path}"
fi
export HEADROOM_BEACON="${HEADROOM_BEACON:-off}"
export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"

LOG_DIR="${HOME}/.headroom"
LOG_FILE="${LOG_DIR}/proxy.log"
HEALTH_URL="http://127.0.0.1:8787/health"

if ! command -v headroom >/dev/null 2>&1; then
  echo "start-headroom: headroom not installed; skip" >&2
  exit 0
fi

if curl -sf --max-time 1 "${HEALTH_URL}" >/dev/null 2>&1; then
  exit 0
fi

mkdir -p "${LOG_DIR}"
nohup headroom proxy --host 127.0.0.1 --port 8787 >>"${LOG_FILE}" 2>&1 &

i=0
while [ "${i}" -lt 30 ]; do
  if curl -sf --max-time 1 "${HEALTH_URL}" >/dev/null 2>&1; then
    exit 0
  fi
  i=$((i + 1))
  sleep 1
done

echo "start-headroom: proxy did not become healthy; see ${LOG_FILE}" >&2
exit 0
