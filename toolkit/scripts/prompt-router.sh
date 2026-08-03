#!/bin/bash
#
# Prompt Router (Claude Code — UserPromptSubmit)
#
# TEMPLATE: the two blocks under "Keyword routing" are examples. Replace them
# with your own keyword -> instruction pairs; the structure stays the same.
#
# Appends routing instructions to the user's prompt based on keyword matching.
# Whatever this script prints on STDOUT is appended to the prompt the model
# receives, so a grep hit turns into an instruction the model reads BEFORE it
# starts planning. This is the cheapest way to make routing habitual: no skill
# invocation, no extra turn, and the user never has to remember an agent name.
#
# The pattern is always the same three lines:
#   if echo "$PROMPT" | grep -qiE '<keywords>'; then
#     add_instruction "INSTRUCTION: <what the model should do>"
#   fi
# Keep instructions short and imperative. They compete with the user's actual
# prompt for attention, so a paragraph is worse than a sentence.
#
# Test locally:
#   echo '{"prompt":"write a query for the reporting table"}' | bash .claude/hooks/prompt-router.sh

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)

if [ -z "$PROMPT" ]; then
  exit 0
fi

INSTRUCTIONS=""

add_instruction() {
  if [ -z "$INSTRUCTIONS" ]; then
    INSTRUCTIONS="$1"
  else
    INSTRUCTIONS="$INSTRUCTIONS
$1"
  fi
}

# --- Always-on instructions ---------------------------------------------------
# Anything added here reaches the model on EVERY prompt, so it costs tokens on
# every turn. Reserve this section for one or two things that genuinely always
# apply (e.g. "search your memory store before starting"), and put everything
# else behind a keyword.

# --- Keyword routing ----------------------------------------------------------
# Two worked examples. Add one block per agent/skill you want routed.

if echo "$PROMPT" | grep -qiE '\b(review|pr )\b'; then
  add_instruction "INSTRUCTION: Delegate to your review subagent instead of reviewing inline; require file:line evidence for each finding."
fi

if echo "$PROMPT" | grep -qiE '\b(sql|query|table)\b'; then
  add_instruction "INSTRUCTION: This looks like a data task — delegate to your data subagent and follow its query rules (dry-run before execution)."
fi

if [ -z "$INSTRUCTIONS" ]; then
  exit 0
fi

echo "$INSTRUCTIONS"
