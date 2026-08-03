#!/usr/bin/env bash
# One command that brings the whole mem0 track up: Qdrant, the Python side,
# the MCP registration, and the seeded decisions base.
#
# Idempotent by design — run it as often as you like. Every step checks whether
# it is already done and skips it, so a second run costs seconds instead of the
# first run's gigabyte. That matters because the most common failure here is a
# half-finished install: something timed out, you re-ran one step by hand, and
# now you cannot tell which of the four are actually in place.
#
# Run it from anywhere; paths resolve against this script's own location.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HARNESS=$(dirname "$HERE")
MEM0_DIR_NAME=$(basename "$HERE")

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'
ok()   { echo "${GREEN}  OK${OFF}  $*"; }
skip() { echo "${DIM}SKIP${OFF}  $*"; }
info() { echo "${YELLOW}    ${OFF}$*"; }
die()  { echo "${RED}FAIL${OFF}  $*"; exit 1; }

echo "== mem0 track setup =="
echo "${DIM}harness: $HARNESS${OFF}"
echo

# ---------------------------------------------------------------- 1. tooling
command -v uv     >/dev/null 2>&1 || die "uv not found. macOS: brew install uv"
command -v podman >/dev/null 2>&1 || die "podman not found. macOS: brew install podman"
ok "uv and podman present"

# ---------------------------------------------------------------- 2. Qdrant
# qdrant-up.sh is already idempotent and handles the podman VM on macOS, so
# this defers to it rather than reimplementing the logic.
PORT=${QDRANT_PORT:-6333}
if curl -fsS "http://localhost:${PORT}/readyz" >/dev/null 2>&1; then
  skip "Qdrant already answering on :${PORT}"
else
  info "starting Qdrant (first run pulls the image)..."
  bash "$HERE/qdrant-up.sh" || die "qdrant-up.sh failed"
fi

# ---------------------------------------------------------------- 3. Python
# The venv lands in mem0/.venv. ~840 MB on first run — this is the step people
# think has hung. It has not.
if [ -d "$HERE/.venv" ] && "$HERE/.venv/bin/python" -c "import fastembed" 2>/dev/null; then
  skip "python deps installed (.venv present, fastembed importable)"
else
  info "installing python deps — ~840 MB, several minutes, go get a coffee..."
  uv sync --directory "$HERE" || die "uv sync failed"
  # fastembed is verified separately because its absence is SILENT: mem0
  # catches the ImportError and quietly runs dense-only, so retrieval still
  # "works" while every literal lookup (a ticket key, an identifier) misses.
  "$HERE/.venv/bin/python" -c "import fastembed" 2>/dev/null \
    || die "fastembed missing after sync — BM25 keyword search would be silently off"
  ok "python deps installed"
fi

# ---------------------------------------------------------------- 4. .mcp.json
# Not written here on purpose: registering the server is the participant's own
# step (`cp ../snippets/02-memory/.mcp.json .mcp.json`), because reading the file
# you are about to hand a local process is the point of that step. This only
# reports whether it has happened, and reads the collection name back out of it.
MCP="$HARNESS/.mcp.json"
COLLECTION=${MEM0_COLLECTION:-my_harness_memory}
if [ -f "$MCP" ]; then
  MCP_COLL=$(grep -oE '"MEM0_COLLECTION": *"[A-Za-z0-9_]+"' "$MCP" 2>/dev/null \
             | head -1 | sed 's/.*: *"\(.*\)"/\1/')
  [ -n "$MCP_COLL" ] && COLLECTION=$MCP_COLL
  if grep -q "\"$MEM0_DIR_NAME\"" "$MCP" 2>/dev/null; then
    ok ".mcp.json present, points at $MEM0_DIR_NAME/ (collection: $COLLECTION)"
  else
    info ".mcp.json present but its --directory is not '$MEM0_DIR_NAME' —"
    info "  the server will not start. Compare against snippets/02-memory/.mcp.json."
  fi
else
  info ".mcp.json not there yet — copy it when you reach the memory block:"
  info "  cp ../snippets/02-memory/.mcp.json .mcp.json   (from $HARNESS)"
fi

# ---------------------------------------------------------------- 5. seed
# The seed is what makes the memory block runnable from minute one: you search
# a real decisions base before you have written anything yourself.
SEEDED=$(curl -fsS "http://localhost:${PORT}/collections/${COLLECTION}" 2>/dev/null \
         | grep -o '"points_count":[0-9]*' | head -1 | cut -d: -f2)
if [ -n "${SEEDED:-}" ] && [ "${SEEDED:-0}" -gt 0 ] 2>/dev/null; then
  skip "collection '$COLLECTION' already holds $SEEDED entries"
  info "to reseed from scratch: podman exec workshop-qdrant true && \\"
  info "  curl -X DELETE http://localhost:${PORT}/collections/${COLLECTION}"
else
  info "seeding the decisions base (~30 s: torch and the embedder load first)..."
  uv run --directory "$HERE" python seed.py || die "seed.py failed"
  ok "decisions base seeded"
fi

echo
echo "${GREEN}Done.${OFF} Restart claude from $HARNESS, then ask it which mem0 tools it has."
echo "${DIM}First session start takes ~26 s for the MCP handshake. It is not frozen.${OFF}"
