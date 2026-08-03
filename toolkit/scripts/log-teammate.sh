#!/bin/bash
#
# Teammate logger (Claude Code — PostToolUse, matcher: SendMessage)
#
# Appends one JSONL line per lead→teammate message to logs/teammates.jsonl so
# that a reporting command can show Agent Teams activity: which teammates ran,
# how many checkpoint round-trips each took, and how long a run stayed open.
# Purely observational: never blocks, never adds context, any failure is a
# silent exit 0.
#
# WHY THIS EXISTS SEPARATELY FROM log-delegation.sh
# Teammate SPAWN is already captured: a teammate is spawned via the ordinary
# Agent tool (subagent_type: claude, run_in_background: true, name: <executor>),
# so PostToolUse Task|Agent logs it — as agent "claude", indistinguishable from
# a real catch-all delegation except by its desc. What was missing is everything
# after the spawn: the SendMessage traffic that carries the checkpoint protocol.
# Verified live 2026-07-25 that BOTH directions are captured — lead→teammate and
# teammate→lead (to: "main"/"team-lead") — so round-trip counts are real, not a
# lead-side-only proxy. Still NOT visible: the teammate's OWN tool calls, which
# run with cwd in the target repo, so per-teammate edit/token counts remain out
# of reach by design.
#
# SCHEMA CAVEAT
# The Agent Teams SendMessage payload shape is not documented. Every field is
# extracted with a `// null` fallback so payload drift degrades to null fields
# rather than a broken record or a lost line. `raw_keys` records the actual
# tool_input key names, which is how to recalibrate the extractors if the shape
# changes: `jq -r '.raw_keys' logs/teammates.jsonl | sort -u`.
#
# Test locally:
#   echo '{"session_id":"test","tool_name":"SendMessage","tool_input":{"to":"sdk-executor","summary":"approve checkpoint","message":"approved, proceed"},"tool_response":{}}' \
#     | CLAUDE_PROJECT_DIR=$PWD bash .claude/hooks/log-teammate.sh

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
  tool: (.tool_name // null),
  # Recipient. Observed live 2026-07-25: BOTH directions land here — the lead
  # sending to a teammate name, and a teammate sending back with to "main" or
  # "team-lead". So this log covers the full round-trip, not just the lead side.
  to: (.tool_input.to // .tool_input.recipient // .tool_input.agent // null),
  # Text length only for plain-string messages. Protocol messages (shutdown /
  # plan_approval) carry an OBJECT here, where `length` would silently mean "key
  # count" — report null instead, and flag the kind via msg_kind.
  msg_chars: (
    (.tool_input.message // .tool_input.text) as $m
    | if ($m | type) == "string" then ($m | length) else null end
  ),
  msg_kind: ((.tool_input.message // .tool_input.text | type) // null),
  # The UI preview line. Real payloads always carry it (it is required when
  # `message` is a string); it is the only human-readable field kept here, and
  # it is a 5-10 word summary by contract, never the message body.
  summary: (.tool_input.summary // null),
  error: (
    if (.tool_response | type) == "object"
    then (.tool_response.is_error // (.tool_response.error != null))
    else false
    end
  ),
  raw_keys: ((.tool_input // {}) | keys)
}' >> "$LOG_DIR/teammates.jsonl" 2>/dev/null

exit 0
