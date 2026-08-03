#!/bin/bash
#
# Delegation logger (Claude Code — PostToolUse, matcher: Task|Agent)
#
# Appends one JSONL line per subagent delegation to logs/delegations.jsonl.
# Purely observational: never blocks, never adds context, any failure is a
# silent exit 0. The Task/Agent hook payload schema is not officially
# documented, so every field is extracted with a fallback — missing fields
# are logged as null rather than breaking the record.
#
# Background launches (run_in_background omitted or true) fire PostToolUse at
# task START, before any totals exist — duration_ms/tokens are null for them
# by design, not by payload drift. The `bg` field records the launch mode so
# reports can tell "metrics unavailable" from "metrics missing".
#
# Agent Teams teammates come through this same hook: a teammate is spawned with
# the Agent tool (subagent_type: claude + name: <some>-executor), so it lands as
# agent "claude". The `teammate`/`agent_name` fields separate them from real
# catch-all delegations. Their SendMessage traffic is logged separately by
# log-teammate.sh; their own in-repo tool calls are not visible to this harness.
# Test locally:
#   echo '{"session_id":"test","tool_name":"Task","tool_input":{"subagent_type":"my-agent","description":"test task","prompt":"hello"},"tool_response":{}}' \
#     | CLAUDE_PROJECT_DIR=$PWD bash .claude/hooks/log-delegation.sh

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
  agent: (.tool_input.subagent_type // "claude"),
  desc: (.tool_input.description // null),
  prompt_chars: ((.tool_input.prompt // "") | length),
  bg: (.tool_input.run_in_background != false),
  # Agent Teams teammates are spawned through this very tool (subagent_type:
  # claude + a `name`), so without this flag they are
  # indistinguishable from a genuine catch-all delegation and permanently
  # inflate the routing-gap metric. A `name` is what makes a teammate
  # addressable via SendMessage, so its presence is the marker.
  teammate: ((.tool_input.name // "") != ""),
  agent_name: (.tool_input.name // null),
  error: (
    if (.tool_response | type) == "object"
    then (.tool_response.is_error // (.tool_response.error != null))
    else false
    end
  ),
  duration_ms: (.tool_response.totalDurationMs // null),
  tokens: (.tool_response.totalTokens // .tool_response.usage.output_tokens // null)
}' >> "$LOG_DIR/delegations.jsonl" 2>/dev/null

exit 0
