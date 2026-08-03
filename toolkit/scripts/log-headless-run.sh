#!/usr/bin/env bash
#
# Headless-run logger (called explicitly by a skill — NOT a hook)
#
# Appends one JSONL line per `claude -p` turn to logs/headless-runs.jsonl.
#
# Why this exists: `PostToolUse` with matcher `Task|Agent` catches subagents and
# teammates for free, because those are tool calls. A handoff driven by
# `claude -p` is not — it is a plain Bash call, so the entire headless path is
# invisible to that hook. Without this script the runs that leave your harness
# are exactly the ones missing from /harness-stats.
#
# It also records MORE than the Agent tool ever exposed: `--output-format json`
# reports cost, turn count, cache usage and permission denials.
#
# Purely observational: never blocks, any failure is a silent exit 0.
#
# Usage, after a `claude -p ... --output-format json` run returns:
#   bash log-headless-run.sh <result.json> <repo> [task-label]
#
#     result.json  the file the headless run wrote
#     repo         target directory the run happened in
#     task-label   optional short label — a phase, a ticket, whatever groups
#                  runs for you later. Keep it short; the task text itself does
#                  not belong in a log you may share.
#
# Test locally:
#   printf '%s' '{"session_id":"abc","num_turns":3,"total_cost_usd":0.5,"is_error":false,"permission_denials":[],"usage":{"cache_read_input_tokens":100}}' > /tmp/t.json
#   bash log-headless-run.sh /tmp/t.json some-repo plan

command -v jq >/dev/null 2>&1 || exit 0

RESULT_JSON="$1"
REPO="${2:-?}"
TASK="${3:-}"

[ -n "$RESULT_JSON" ] && [ -f "$RESULT_JSON" ] || exit 0

HARNESS="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOG_DIR="$HARNESS/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

# A turn that died before writing valid JSON still deserves a record —
# otherwise a broken run is indistinguishable from a run that never happened.
# The classic cause is a forgotten `< /dev/null`: the CLI prints a stdin warning
# line ahead of the payload, and the whole file stops parsing.
if ! jq -e . "$RESULT_JSON" >/dev/null 2>&1; then
  jq -nc \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg repo "$REPO" --arg task "$TASK" --arg file "$RESULT_JSON" \
    '{ts:$ts, repo:$repo,
      task:(if ($task|length) > 0 then $task else null end),
      session_id:null, unparsable:true, result_file:$file}' \
    >> "$LOG_DIR/headless-runs.jsonl" 2>/dev/null
  exit 0
fi

jq -c \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg repo "$REPO" --arg task "$TASK" \
  '{
    ts: $ts,
    repo: $repo,
    task: (if ($task | length) > 0 then $task else null end),
    # The handle for --resume. Without it a turn is a dead end, so it is the
    # one field worth grepping for when you want to continue yesterday'"'"'s run.
    session_id: (.session_id // null),
    turns: (.num_turns // null),
    cost_usd: (.total_cost_usd // null),
    duration_ms: (.duration_ms // null),
    cache_read: (.usage.cache_read_input_tokens // null),
    cache_creation: (.usage.cache_creation_input_tokens // null),
    output_tokens: (.usage.output_tokens // null),
    # A non-empty denials list means --allowedTools was too narrow for what the
    # run actually needed. The agent'"'"'s own report often does not mention it,
    # which is why the count is logged rather than trusted to the prose.
    denials: ((.permission_denials // []) | length),
    # `has()` rather than `// null`: jq treats false as empty, so `.is_error //
    # null` silently rewrites every SUCCESSFUL run as null — and a log where
    # success and "field missing" look identical cannot answer "how many runs
    # failed", which is the first question you bring to it.
    is_error: (if has("is_error") then .is_error else null end),
    subtype: (.subtype // null)
  }' "$RESULT_JSON" >> "$LOG_DIR/headless-runs.jsonl" 2>/dev/null

exit 0
