#!/usr/bin/env bash
# Pre-workshop environment check. Everything must be green.
set -u

PASS=0
FAIL=0

ok()   { printf '\033[32m  OK\033[0m  %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '\033[31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL+1)); }

echo "== harness-workshop environment check =="

# 1. Claude Code installed
if command -v claude >/dev/null 2>&1; then
  ok "claude found: $(claude --version 2>/dev/null | head -1)"
else
  bad "claude not found — install Claude Code (see setup/pre-workshop.md)"
fi

# 2. jq (hooks parse JSON with it)
if command -v jq >/dev/null 2>&1; then
  ok "jq found"
else
  bad "jq not found — macOS: brew install jq | Debian: sudo apt install jq"
fi

# 2b. python3 (scripts/teammate-idle-inbox-gate.sh parses the inbox JSON with it)
if command -v python3 >/dev/null 2>&1; then
  ok "python3 found: $(python3 --version 2>&1)"
else
  bad "python3 not found — macOS: xcode-select --install | Debian: sudo apt install python3"
fi

# 3. bash version (associative-array-free scripts, but 3.2+ required)
if [ -n "${BASH_VERSION:-}" ]; then
  ok "bash $BASH_VERSION"
else
  bad "not running under bash — run: bash setup/check.sh"
fi

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 4. Claude Code version recent enough for Agent Teams
if command -v claude >/dev/null 2>&1; then
  CC_VER=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [ -n "$CC_VER" ]; then
    MAJ=${CC_VER%%.*}; REST=${CC_VER#*.}; MIN=${REST%%.*}; PATCH=${REST#*.}
    if [ "$MAJ" -gt 2 ] || { [ "$MAJ" -eq 2 ] && [ "$MIN" -gt 1 ]; } || \
       { [ "$MAJ" -eq 2 ] && [ "$MIN" -eq 1 ] && [ "$PATCH" -ge 178 ]; }; then
      ok "Claude Code $CC_VER supports Agent Teams (needs >= 2.1.178)"
    else
      bad "Claude Code $CC_VER too old for Agent Teams (needs >= 2.1.178) — update it"
    fi
  else
    printf '\033[33mSKIP\033[0m  could not parse claude version for the Agent Teams check\n'
  fi
fi

# 5. A trivial hook round-trip: echo JSON through jq like a hook would
if command -v jq >/dev/null 2>&1; then
  RESULT=$(echo '{"tool_input":{"file_path":"x"}}' | jq -r '.tool_input.file_path' 2>/dev/null)
  [ "$RESULT" = "x" ] && ok "hook-style JSON parsing works" \
                      || bad "jq JSON round-trip failed"
fi

# 6. Handout <-> repo consistency: every `toolkit/scripts/<name>.sh` and
#    `snippets/<dir>/<name>` the handout tells participants to copy must exist.
#    This is the check that keeps docs from drifting from code.
MISSING=""
for MD in "$REPO_DIR"/handout/*.md "$REPO_DIR"/README.md; do
  [ -f "$MD" ] || continue
  while IFS= read -r ref; do
    [ -f "$REPO_DIR/$ref" ] || MISSING="$MISSING $(basename "$MD"):$ref"
  done < <(grep -ohE '(toolkit/scripts/[A-Za-z0-9_.-]+\.sh|toolkit/skills/[A-Za-z0-9_.-]+/SKILL\.md|snippets/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\.(sh|json|md))' "$MD" 2>/dev/null \
           | sort -u)
done
if [ -z "$MISSING" ]; then
  ok "handout and repo file paths agree"
else
  bad "handout points at missing files:$MISSING"
fi

# 7. The copy-me toolkit: scripts present and executable, skills present.
#    Both halves matter — the scripts write logs, the skills read them, and a
#    toolkit with only writers is the half-built state this repo warns about.
SCRIPTS_DIR="$REPO_DIR/toolkit/scripts"
if [ -d "$SCRIPTS_DIR" ]; then
  NSCRIPTS=0; NOTEXEC=0
  for f in "$SCRIPTS_DIR"/*.sh; do
    [ -f "$f" ] || continue
    NSCRIPTS=$((NSCRIPTS+1))
    [ -x "$f" ] || { chmod +x "$f" 2>/dev/null || NOTEXEC=$((NOTEXEC+1)); }
  done
  if [ "$NSCRIPTS" -gt 0 ] && [ "$NOTEXEC" -eq 0 ]; then
    ok "toolkit/scripts/ present ($NSCRIPTS scripts, executable)"
  else
    bad "toolkit/scripts/ incomplete — expected executable *.sh, found $NSCRIPTS"
  fi
else
  bad "toolkit/scripts/ not found — are you in the repo root?"
fi

SKILLS_DIR="$REPO_DIR/toolkit/skills"
if [ -d "$SKILLS_DIR" ]; then
  NSKILLS=0
  for d in "$SKILLS_DIR"/*/; do
    [ -f "$d/SKILL.md" ] && NSKILLS=$((NSKILLS+1))
  done
  if [ "$NSKILLS" -gt 0 ]; then
    ok "toolkit/skills/ present ($NSKILLS skills)"
  else
    bad "toolkit/skills/ has no SKILL.md — a skill directory without one is inert"
  fi
else
  bad "toolkit/skills/ not found — are you in the repo root?"
fi

# 8. The memory store: mem0 + Qdrant. REQUIRED — the memory block has no
#    file fallback, and the install is too big to do during the session.
#    podman, not Docker: Docker is not allowed on corporate machines.
if command -v podman >/dev/null 2>&1; then
  ok "podman found"
else
  bad "podman not found — needed for Qdrant. macOS: brew install podman | Debian: sudo apt install podman"
fi

if command -v uv >/dev/null 2>&1; then
  ok "uv found ($(uv --version 2>/dev/null))"
else
  bad "uv not found — it runs the mem0 server. See my-harness/mem0/README.md"
fi

if curl -fsS -m 3 http://localhost:6333/readyz >/dev/null 2>&1; then
  ok "Qdrant answering on :6333"
else
  bad "Qdrant not reachable on :6333 — run: bash my-harness/mem0/run.sh"
fi

# The venv must exist, or the first session spends minutes downloading torch.
if [ -d "$REPO_DIR/my-harness/mem0/.venv" ]; then
  ok "mem0 python env installed"

  # fastembed is checked separately because its absence is SILENT: mem0 catches
  # the ImportError and falls back to dense-only retrieval with no error, so a
  # broken store looks like a working one until someone searches for a literal
  # token. An existing .venv from before this dep was added will lack it.
  if "$REPO_DIR/my-harness/mem0/.venv/bin/python" -c "import fastembed" 2>/dev/null; then
    ok "fastembed present (BM25 hybrid search enabled)"
  else
    bad "fastembed missing — BM25 keyword search silently disabled. Run: bash my-harness/mem0/run.sh"
  fi
else
  bad "mem0 deps not installed — run: bash my-harness/mem0/run.sh (big download, not for workshop day)"
fi

# NOT checked here: .mcp.json. The participant copies it into my-harness/ during
# the memory block (snippets/02-memory/.mcp.json), so its absence before the
# workshop is correct, not a failure.

# 9. The seed base for the memory block.
SEED_JSON="$REPO_DIR/my-harness/mem0/seed-decisions.json"
SEED_PY="$REPO_DIR/my-harness/mem0/seed.py"
if [ -f "$SEED_JSON" ] && [ -f "$SEED_PY" ]; then
  if command -v jq >/dev/null 2>&1; then
    NSEED=$(jq 'length' "$SEED_JSON" 2>/dev/null || echo 0)
    if [ "$NSEED" -ge 10 ]; then
      ok "decisions seed present ($NSEED entries)"
    else
      bad "seed-decisions.json has $NSEED entries — expected at least 10"
    fi
  else
    ok "decisions seed present (jq missing, count not verified)"
  fi
  # The seed must write where the MCP server reads. A mismatch means you seed one
  # collection and search another — the single most confusing failure in the block.
  SEED_COLL=$(grep -oE 'COLLECTION = "[A-Za-z0-9_]+"' "$SEED_PY" | head -1 | sed 's/.*"\(.*\)"/\1/')
  SNIP_COLL=$(grep -oE '"MEM0_COLLECTION": "[A-Za-z0-9_]+"' "$REPO_DIR/snippets/02-memory/.mcp.json" 2>/dev/null | head -1 | sed 's/.*: "\(.*\)"/\1/')
  if [ -n "$SEED_COLL" ] && [ "$SEED_COLL" = "$SNIP_COLL" ]; then
    ok "seed and mcp.json agree on collection ($SEED_COLL)"
  else
    bad "collection mismatch: seed.py says '$SEED_COLL', snippets/02-memory/.mcp.json says '$SNIP_COLL'"
  fi
else
  bad "seed files missing — expected my-harness/mem0/seed-decisions.json and seed.py"
fi

# 10. The empty scaffold the participant builds in.
SCAFFOLD="$REPO_DIR/my-harness/.claude/settings.json"
if [ -f "$SCAFFOLD" ]; then
  if command -v jq >/dev/null 2>&1 && [ "$(jq -r 'keys | length' "$SCAFFOLD" 2>/dev/null)" = "0" ]; then
    ok "my-harness/ scaffold present, settings.json empty"
  else
    bad "my-harness/.claude/settings.json is not empty — it must start as {} (git restore it)"
  fi
else
  bad "my-harness/.claude/settings.json not found — the scaffold is missing"
fi

# 11. Every snippet the blocks tell participants to copy must exist and, for
#     JSON, must parse. This is what keeps the handout from pointing at nothing.
SNIP_MISSING=""
for f in 01-hooks/01-stop-sound.json 01-hooks/02-notification-sound.json \
         01-hooks/03-userpromptsubmit.json 01-hooks/04-pretooluse.json \
         01-hooks/inject-reminder.sh 01-hooks/guard-env.sh \
         02-memory/.mcp.json \
         03-orchestration/05-agent-teams-env.json \
         03-orchestration/task-package.md \
         03-orchestration/run-elsewhere/SKILL.md \
         04-extras/06-statusline.json \
         04-extras/statusline-command.sh; do
  [ -f "$REPO_DIR/snippets/$f" ] || SNIP_MISSING="$SNIP_MISSING $f"
done
if [ -z "$SNIP_MISSING" ]; then
  NBAD_JSON=0
  if command -v jq >/dev/null 2>&1; then
    for f in "$REPO_DIR"/snippets/*/*.json; do
      jq . "$f" >/dev/null 2>&1 || NBAD_JSON=$((NBAD_JSON+1))
    done
  fi
  if [ "$NBAD_JSON" -eq 0 ]; then
    ok "snippets/ complete ($(ls "$REPO_DIR"/snippets/*/* 2>/dev/null | wc -l | tr -d ' ') files, JSON parses)"
  else
    bad "snippets/ has $NBAD_JSON invalid JSON file(s)"
  fi
else
  bad "snippets missing:$SNIP_MISSING"
fi

# The two snippet scripts get copied and chmod'ed by participants; make sure the
# originals are executable so a plain cp already works.
SNIP_NOTEXEC=""
for f in "$REPO_DIR"/snippets/*/*.sh; do
  [ -f "$f" ] || continue
  [ -x "$f" ] || { chmod +x "$f" 2>/dev/null || SNIP_NOTEXEC="$SNIP_NOTEXEC $(basename "$f")"; }
done
if [ -z "$SNIP_NOTEXEC" ]; then
  ok "snippet scripts executable"
else
  bad "snippet scripts not executable:$SNIP_NOTEXEC"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32mAll green (%d checks). You are ready.\033[0m\n' "$PASS"
  exit 0
else
  printf '\033[31m%d check(s) failed. Fix before the workshop.\033[0m\n' "$FAIL"
  exit 1
fi
