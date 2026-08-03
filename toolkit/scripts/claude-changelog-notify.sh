#!/bin/bash
#
# Claude Code changelog notifier (global SessionStart hook, matcher: startup)
#
# Shows the CHANGELOG once per CLI version bump: on the first session started
# on a new Claude Code version, fetches the official CHANGELOG.md and injects
# the sections between the previously seen version and the current one, with
# an instruction for the assistant to present it to the user. Every later
# session on the same version is silent. Any failure is a silent exit 0.
#
# Test locally:
#   echo 2.1.212 > ~/.claude/hooks/.claude-version-seen
#   echo '{"source":"startup"}' | bash ~/.claude/hooks/claude-changelog-notify.sh

INPUT=$(cat)

STATE="$HOME/.claude/hooks/.claude-version-seen"
CHANGELOG_URL="https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"

CURRENT=$(claude --version 2>/dev/null | awk 'NR==1{print $1}')
[ -n "$CURRENT" ] || exit 0

# First run: record the version, show nothing.
if [ ! -f "$STATE" ]; then
  printf '%s\n' "$CURRENT" > "$STATE" 2>/dev/null
  exit 0
fi

SEEN=$(cat "$STATE" 2>/dev/null)
[ "$CURRENT" = "$SEEN" ] && exit 0

# Version changed: mark as seen first (show-once beats retry-spam), then report.
printf '%s\n' "$CURRENT" > "$STATE" 2>/dev/null

command -v jq >/dev/null 2>&1 || exit 0

CHANGELOG=$(curl -fsSL -m 8 "$CHANGELOG_URL" 2>/dev/null)

if [ -z "$CHANGELOG" ]; then
  jq -n --arg seen "$SEEN" --arg cur "$CURRENT" '{
    systemMessage: "Claude Code updated \($seen) -> \($cur). Could not fetch the changelog (offline?): https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md",
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: "Claude Code was updated \($seen) -> \($cur); the changelog could not be fetched. If the user asks what changed, point them to https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md"
    }
  }'
  exit 0
fi

# Slice: everything from "## <CURRENT>" down to (excluding) "## <SEEN>".
# Covers intermediate skipped versions too.
SECTION=$(printf '%s\n' "$CHANGELOG" | awk -v cur="## $CURRENT" -v old="## $SEEN" '
  $0 == cur {on=1}
  on && $0 == old {exit}
  on {print}
')

# Fallback: headings not found (fork/renamed versions) — take the first section.
if [ -z "$SECTION" ]; then
  SECTION=$(printf '%s\n' "$CHANGELOG" | awk '/^## /{n++} n==1{print} n==2{exit}')
fi

# Cap to keep the injected context small.
SECTION=$(printf '%s\n' "$SECTION" | head -200 | head -c 8000)

# systemMessage renders in the user's terminal immediately (no model relay
# needed); additionalContext lets the assistant reference it later.
jq -n --arg seen "$SEEN" --arg cur "$CURRENT" --arg log "$SECTION" '{
  systemMessage: "Claude Code updated \($seen) -> \($cur). What changed:\n\n\($log)",
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: "Claude Code was updated \($seen) -> \($cur). The changelog below was already shown to the user in the terminal; reference it if they ask what changed.\n\n\($log)"
  }
}'
exit 0
