#!/bin/bash
#
# Papercut logger (CLI, called by the orchestrator and Bash-capable subagents)
#
# Records one friction event ("papercut") encountered during agent work —
# a dead-end tool call, broken link, stale instruction, repeated permission
# denial — as one JSONL line in logs/papercuts.jsonl. Purely observational:
# never blocks the caller, any failure is a silent exit 0.
#
# Usage:
#   bash "$HARNESS/.claude/hooks/papercut.sh" <category> "<note>" [target]
#   category: tool-failure | stale-doc | broken-link | missing-permission |
#             routing-gap | env | other   (anything else is coerced to "other")
#   note:     free-text description of the friction (English)
#   target:   optional file path / tool name / URL the complaint is about
#
# agent attribution: set PAPERCUT_AGENT=<subagent name> when the orchestrator
# logs on behalf of a non-Bash subagent (defaults to "claude").
# Test locally:
#   bash .claude/hooks/papercut.sh stale-doc "test note" some/file.md \
#     && tail -1 logs/papercuts.jsonl

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

CATEGORY="${1:-}"
NOTE="${2:-}"
TARGET="${3:-}"

# A papercut without a note is noise — drop it silently.
[ -n "$NOTE" ] || exit 0

case "$CATEGORY" in
  tool-failure|stale-doc|broken-link|missing-permission|routing-gap|env|other) ;;
  *) CATEGORY="other" ;;
esac

# Resolve the harness root from the script's own location, NOT from
# CLAUDE_PROJECT_DIR: Agent Teams teammates run with cwd (and project dir)
# inside a sibling repo, but the papercut log always belongs to the harness.
HARNESS="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="$HARNESS/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

jq -cn \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg session_id "${CLAUDE_SESSION_ID:-}" \
  --arg agent "${PAPERCUT_AGENT:-claude}" \
  --arg category "$CATEGORY" \
  --arg note "$NOTE" \
  --arg target "$TARGET" \
  '{
    ts: $ts,
    session_id: (if $session_id == "" then null else $session_id end),
    agent: $agent,
    category: $category,
    target: (if $target == "" then null else $target end),
    note: $note
  }' >> "$LOG_DIR/papercuts.jsonl" 2>/dev/null

exit 0
