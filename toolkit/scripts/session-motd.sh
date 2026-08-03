#!/bin/bash
#
# Session MOTD (Claude Code — SessionStart, matcher: startup|resume|clear)
#
# TEMPLATE: replace the greeting and the COMMANDS heredoc with your own
# cheat-sheet. The mechanism is the point, not the content.
#
# Emits JSON with a `systemMessage` field. Per the hooks docs, `systemMessage`
# is shown to the USER in the terminal UI but is NOT added to the model's
# context — so a cheat-sheet printed this way costs ZERO tokens, no matter how
# long it is. That is what makes it different from `additionalContext` (which
# the model does read, and does pay for) and from printing to stdout.
#
# The command list is deliberately STATIC: some skills are internal and must
# not be advertised as user commands. When you add a user-facing skill, add a
# line to the heredoc below.
#
# Fail-silent: any problem is a bare exit 0 (model: log-session.sh).
# Test locally:
#   echo '{}' | CLAUDE_PROJECT_DIR=$PWD bash .claude/hooks/session-motd.sh

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Consume the hook payload (unused) so the caller never sees a broken pipe
cat >/dev/null

# Your harness root, if you want to add a live status line below (e.g. a count
# of open items from a directory you track). Not used by this template.
# HARNESS="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

COMMANDS=$(cat <<'EOF'
  /<your-command>            — one line on what it does
  /<your-command> <arg>      — the same command with an argument
EOF
)

MOTD=$'\n\n'"Your harness is ready.

Commands:
${COMMANDS}"

jq -n --arg msg "$MOTD" '{systemMessage: $msg}' 2>/dev/null || exit 0

exit 0
