#!/bin/bash
#
# Preflight gate (Claude Code — PreToolUse, matcher: Task|Agent)
#
# TEMPLATE: replace the placeholder in the `case` below with your own
# agent -> repo mapping. Everything else works as-is.
#
# The reference example of "a hook as enforcement". A rule written in CLAUDE.md
# is advice the model may skip; the same rule in a PreToolUse hook is
# mechanical. Before a WRITE subagent is dispatched to a repo, this runs
# repo-preflight.sh for that repo. If the repo needs the user's attention
# (uncommitted changes, non-base branch, diverged/unpushed), the delegation is
# BLOCKED (exit 2) and the report is returned as feedback, so the orchestrator
# stops and asks the user instead of editing on top of a dirty tree.
#
# How the blocking works: exit 2 from a PreToolUse hook denies the tool call,
# and whatever the hook wrote to STDERR is fed back to the model as the reason.
# Exit 0 (or any other code) lets the call through. That is the whole contract —
# stderr + exit 2.
#
# Only WRITE agents should be gated. For a reviewer agent a dirty tree is the
# normal input, and read-only agents don't mutate working copies.
#
# Clean results are cached per repo for CACHE_TTL seconds so multi-agent chains
# don't re-run `git fetch` on every delegation.
# Test locally:
#   echo '{"tool_name":"Task","tool_input":{"subagent_type":"<your-agent>","prompt":"x"}}' \
#     | CLAUDE_PROJECT_DIR=$PWD bash .claude/hooks/preflight-gate.sh

CACHE_TTL=600

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat)
AGENT=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)

HARNESS="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
WORKSPACE=$(cd "$HARNESS/.." && pwd)

# One line per write agent: the agent name, and the repo it edits.
# Repos are addressed relative to $WORKSPACE (the parent of your harness), so
# sibling checkouts resolve the same way on every machine.
# Any agent NOT listed here falls through to `exit 0` and is never gated.
# (The pattern is quoted only so this template stays syntactically valid — a
# bare < in a case pattern is a redirection. Real agent names need no quotes.)
case "$AGENT" in
  "<your-agent>") REPO="$WORKSPACE/<path-to-repo>" ;;
  *)              exit 0 ;;
esac

[ -d "$REPO" ] || exit 0

# TTL cache via a stamp file in $TMPDIR: a clean result is remembered for
# CACHE_TTL seconds, so a chain of delegations to the same repo pays for one
# `git fetch`, not one per delegation.
STAMP="${TMPDIR:-/tmp}/preflight-$(basename "$REPO").ok"
if [ -f "$STAMP" ]; then
  now=$(date +%s)
  # Portability: `stat -f %m` is BSD/macOS, `stat -c %Y` is GNU/Linux, and
  # `echo 0` keeps the arithmetic valid if neither exists (the cache then just
  # always looks expired — degraded, never broken).
  mtime=$(stat -f %m "$STAMP" 2>/dev/null || stat -c %Y "$STAMP" 2>/dev/null || echo 0)
  if [ $((now - mtime)) -lt "$CACHE_TTL" ]; then
    exit 0
  fi
fi

REPORT=$(bash "$HARNESS/.claude/hooks/repo-preflight.sh" "$REPO" 2>&1)

if echo "$REPORT" | grep -q 'NEEDS_ATTENTION'; then
  {
    echo "Repo preflight blocked this delegation:"
    echo "$REPORT"
    echo "STOP: ask the user how to proceed; do not retry this delegation as-is."
  } >&2
  exit 2
fi

touch "$STAMP" 2>/dev/null
exit 0
