---
name: run-elsewhere
description: >
  Run a task in ANOTHER repository, as a separate Claude session started in that
  directory, and report what happened. The session loads that repo's CLAUDE.md
  and hooks instead of this harness's. Use when asked to do something in a repo
  that is not this one, or to hand a task package to a canonical agent.
---

# /run-elsewhere — send a task to another repository

Run the task as a **separate process started in the target directory**. That is
the whole point: a session loads its rules from the directory it was started in,
so this is the only way to make another repo's CLAUDE.md and hooks apply to the
work — and equally, the only way *your* hooks stop applying.

A subagent cannot do this. It runs inside your session, under your rules, no
matter which directory its files live in.

## Arguments

`/run-elsewhere <repo-path> [--resume <session-id>] <task>`

The repo path and the task are required. Without a repo path, ask which
repository; do not guess. With `--resume`, continue an existing session instead
of starting a new one — it keeps everything that session already read and
decided, and costs a fraction of a fresh start.

## What to do

1. **Resolve the path** and confirm it exists (`ls <repo-path>`). Report and stop
   if it does not — a typo here silently runs the task in the wrong place.

2. **Run it**, from the target directory:

   ```bash
   cd <repo-path> && claude -p '<task>' \
     --output-format json \
     --allowedTools "Read,Glob,Grep,Bash(git *)" \
     < /dev/null > /tmp/run-elsewhere.json 2>/dev/null
   ```

   With `--resume <session-id>`, add that flag to the same command. Resume only
   works from the directory that created the session, which the `cd` already
   guarantees.

   Three details that are not optional:
   - **`cd` first.** It decides whose rules apply. Everything else is detail.
   - **`< /dev/null`**, or the CLI waits for stdin and prints a warning line into
     the output, which then fails to parse as JSON.
   - **`--allowedTools`**, because a headless run has nobody to approve a
     permission prompt: anything unlisted is refused mid-turn. Start read-only as
     above; add `Edit,Write` only when the task is meant to change files, and say
     so in your report when you do.

3. **Read the result** out of the JSON:

   ```bash
   jq -r '.result' /tmp/run-elsewhere.json
   jq -r '"session: \(.session_id)  turns: \(.num_turns)  cost: $\(.total_cost_usd)"' /tmp/run-elsewhere.json
   ```

   If `toolkit/scripts/log-headless-run.sh` is installed in your harness, log
   the turn as well — one line, and the run stops being invisible:

   ```bash
   bash .claude/hooks/log-headless-run.sh /tmp/run-elsewhere.json <repo-path>
   ```

   This is not optional bookkeeping. `PostToolUse` catches subagents and
   teammates for free because those are tool calls; a `claude -p` run is a plain
   Bash call, so without this line every handoff you make is missing from
   `/harness-stats` — the runs that leave your harness are precisely the ones
   you cannot see.

4. **Report back**: what the session said, which directory it ran in, and the
   session id. Then note explicitly **whose rules were in force** — the target
   repo's, not this harness's. If the task touched something your own hooks
   protect, say plainly that your guard did not run for it.

5. **Offer to continue.** The session persists; resume it with the same command
   plus `--resume <session-id>`, run from the same directory. The conversation is
   cached, so a follow-up turn is far cheaper than starting over.

## Reporting honestly

Say what the run did, not what it was asked to do. If the session reported being
blocked, quote the denial verbatim — the blocker is the interesting part, and
whose hook produced it tells you which rules were loaded.

If the session refused a tool for lack of permission, that is a signal your
`--allowedTools` list was too narrow. Widen it and resume; do not rephrase the
task to work around it, and never reach for `--dangerously-skip-permissions` —
that also disables the target repo's own guards, which is the opposite of why
the run happens there.

## What this does not do

- It does not commit or push. The deliverable is an uncommitted diff a human
  reviews.
- It does not carry your conversation over. The other session never saw this
  chat, so everything it needs goes in the task text: absolute paths, decisions
  already made, and what is explicitly out of scope.
- It does not protect the target repo from you, or you from it. A guard is a rule
  about a session, not about a file on disk.
