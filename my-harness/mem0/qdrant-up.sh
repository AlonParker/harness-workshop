#!/usr/bin/env bash
# Start the Qdrant vector store for the mem0 track. Idempotent: safe to run
# again — an existing container is started, not recreated, so your memories
# survive.
#
# podman, not Docker: Docker Desktop is not allowed on corporate machines.
# On Linux podman runs natively; on macOS it needs a VM ("podman machine"),
# which this script initialises for you if it is missing.
set -uo pipefail

CONTAINER=${QDRANT_CONTAINER:-workshop-qdrant}
VOLUME=${QDRANT_VOLUME:-workshop_qdrant}
PORT=${QDRANT_PORT:-6333}
IMAGE=docker.io/qdrant/qdrant

if ! command -v podman >/dev/null 2>&1; then
  echo "FAIL: podman not found."
  echo "  macOS:  brew install podman"
  echo "  Debian: sudo apt install podman"
  exit 1
fi

# macOS/Windows only: podman needs a Linux VM. On Linux there is no machine
# subsystem and 'podman machine list' returns nothing useful — skip quietly.
if [[ "$(uname -s)" == "Darwin" ]]; then
  # podman >= 6 defaults to the libkrun provider on macOS, which needs the
  # separate krunkit binary that 'brew install podman' does not pull in.
  # applehv is built into macOS and needs nothing extra.
  export CONTAINERS_MACHINE_PROVIDER=${CONTAINERS_MACHINE_PROVIDER:-applehv}
  if ! podman machine list --format '{{.Name}}' 2>/dev/null | grep -q .; then
    echo "No podman machine yet — creating one (a few minutes, one time only)..."
    # 1024 MB is the tested minimum: at 512 the Fedora CoreOS 44 image cannot
    # unpack its initramfs and kernel-panics, while 'podman machine start'
    # hangs silently instead of failing.
    podman machine init --memory 1024 || { echo "FAIL: podman machine init"; exit 1; }
  fi
  if ! podman machine list --format '{{.Running}}' 2>/dev/null | grep -qi true; then
    echo "Starting podman machine..."
    podman machine start || { echo "FAIL: podman machine start"; exit 1; }
  fi
fi

if podman container exists "$CONTAINER" 2>/dev/null; then
  echo "Container '$CONTAINER' already exists — starting it."
  podman start "$CONTAINER" >/dev/null 2>&1
else
  echo "Creating container '$CONTAINER' (image pull on first run)..."
  podman run -d --name "$CONTAINER" --restart=always \
    -p "${PORT}:6333" \
    -v "${VOLUME}:/qdrant/storage" \
    "$IMAGE" >/dev/null || { echo "FAIL: podman run"; exit 1; }
fi

# Qdrant needs a moment before it answers.
echo -n "Waiting for Qdrant on :${PORT} "
for _ in $(seq 1 30); do
  if curl -fsS "http://localhost:${PORT}/readyz" >/dev/null 2>&1; then
    echo
    echo "OK: Qdrant is ready at http://localhost:${PORT}"
    echo "    dashboard: http://localhost:${PORT}/dashboard"
    exit 0
  fi
  echo -n "."
  sleep 1
done

echo
echo "FAIL: Qdrant did not become ready within 30s."
echo "  Inspect with: podman logs $CONTAINER"
exit 1
