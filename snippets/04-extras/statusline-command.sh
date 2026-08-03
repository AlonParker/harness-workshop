#!/bin/bash
# Status line: model, context usage, working directory, session topic.
#
# Install:
#   cp snippets/04-extras/statusline-command.sh ~/.claude/statusline-command.sh
#   chmod +x ~/.claude/statusline-command.sh
#   then add to ~/.claude/settings.json:
#     "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
#
# Renders, dimmed, at the bottom of the session:
#   Opus 5 [####------] 43%          my-harness · wiring the guard hook
#
# The context bar is the reason this exists: you see the window filling up
# while you work, instead of finding out when a compaction happens.
#
# Claude Code feeds this script a JSON blob on stdin; every field below is
# read from it with a fallback, so a missing key degrades the line instead of
# breaking it.

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name')
pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
dir_name=""
if [ -n "$dir" ]; then dir_name=$(basename "$dir"); fi

# Session topic: custom name from /rename, else the AI-generated title.
# Absent until Claude Code has produced a title, so it may be empty.
topic=$(echo "$input" | jq -r '.session_name // ""')

pct_int=$(printf '%.0f' "$pct")

filled=$(( pct_int / 10 ))
if [ "$filled" -gt 10 ]; then filled=10; fi
if [ "$filled" -lt 0 ]; then filled=0; fi
empty=$(( 10 - filled ))

bar=""
for ((i=0; i<filled; i++)); do bar="${bar}#"; done
for ((i=0; i<empty; i++)); do bar="${bar}-"; done

# Terminal width. statusline runs with no tty of its own and COLUMNS unset,
# so tput would report a bare termcap default of 80. The parent `claude`
# process does hold the tty - ask stty through it, and fall back to 80 only
# if that path fails (e.g. no controlling terminal at all).
# The immediate parent may be an intermediate shell with no tty, so walk up
# the process chain until a tty turns up.
cols=""
pid=$PPID
for _ in 1 2 3 4 5; do
  [ -z "$pid" ] || [ "$pid" = "0" ] || [ "$pid" = "1" ] && break
  ptty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
  if [ -n "$ptty" ] && [ "$ptty" != "??" ] && [ -e "/dev/$ptty" ]; then
    cols=$(stty size < "/dev/$ptty" 2>/dev/null | cut -d' ' -f2)
    [ -n "$cols" ] && break
  fi
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done
case "$cols" in ''|*[!0-9]*) cols=80 ;; esac

gap="          "
left="${model} [${bar}] ${pct_int}%"

tail=""
if [ -n "$dir_name" ] && [ -n "$topic" ]; then
  # Trim the topic to whatever room is left after the fixed parts.
  room=$(( cols - ${#left} - ${#gap} - ${#dir_name} - 3 ))
  if [ "$room" -lt 8 ]; then
    tail="${gap}${dir_name}"
  else
    if [ "${#topic}" -gt "$room" ]; then
      topic="${topic:0:$(( room - 3 ))}..."
    fi
    tail="${gap}${dir_name} · ${topic}"
  fi
elif [ -n "$dir_name" ]; then
  tail="${gap}${dir_name}"
elif [ -n "$topic" ]; then
  room=$(( cols - ${#left} - ${#gap} ))
  if [ "$room" -ge 8 ]; then
    if [ "${#topic}" -gt "$room" ]; then
      topic="${topic:0:$(( room - 3 ))}..."
    fi
    tail="${gap}${topic}"
  fi
fi

out="${left}${tail}"
# Last-resort clamp: on a very narrow terminal even the fixed part overflows.
if [ "${#out}" -gt "$cols" ]; then out="${out:0:$cols}"; fi

printf "\033[2m%s\033[0m" "$out"
