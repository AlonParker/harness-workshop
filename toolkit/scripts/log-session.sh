#!/bin/bash
#
# Session logger (Claude Code — SessionStart, matcher: startup|resume|clear)
#
# Appends one JSONL line per session start to logs/sessions.jsonl so that a
# reporting command can spot sessions with zero delegations (the orchestrator
# doing domain work itself instead of routing). Purely observational: never
# blocks, adds no context, any failure is a silent exit 0.
# Test locally:
#   echo '{"session_id":"test","source":"startup"}' \
#     | CLAUDE_PROJECT_DIR=$PWD bash .claude/hooks/log-session.sh

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat)

HARNESS="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOG_DIR="$HARNESS/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

echo "$INPUT" | jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
  ts: $ts,
  session_id: (.session_id // null),
  source: (.source // null)
}' >> "$LOG_DIR/sessions.jsonl" 2>/dev/null

exit 0
