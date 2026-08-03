# Hook script library

A library to copy into **your own** harness — here it is deliberately not wired
into any `settings.json`, so nothing in this repository executes it.

## What's in here

| Script | Hook event | What it does | Group |
|---|---|---|---|
| `log-session.sh` | `SessionStart` (`startup\|resume\|clear`) | One JSONL line per session start into `logs/sessions.jsonl` — lets you spot sessions with zero delegations. | A — copy as is |
| `log-delegation.sh` | `PostToolUse` (`Task\|Agent`) | One JSONL line per subagent delegation into `logs/delegations.jsonl`: which agent, prompt size, error flag, duration/tokens when available. | A — copy as is |
| `log-teammate.sh` | `PostToolUse` (`SendMessage`) | One JSONL line per Agent Teams message into `logs/teammates.jsonl` — covers both directions, so checkpoint round-trips are countable. | A — copy as is |
| `log-headless-run.sh` | CLI, not a hook | One JSONL line per `claude -p` turn into `logs/headless-runs.jsonl`: session id, turns, cost, cache usage, permission denials. Called by `/run-elsewhere` after a run returns. | A — copy as is |
| `session-motd.sh` | `SessionStart` (`startup\|resume\|clear`) | Prints a command cheat-sheet to the user via `systemMessage` — visible in the terminal, invisible to the model, zero tokens. | B — replace placeholders |
| `prompt-router.sh` | `UserPromptSubmit` | Greps the user's prompt for keywords and appends routing instructions to it, so the model sees them before planning. | B — replace placeholders |
| `preflight-gate.sh` | `PreToolUse` (`Task\|Agent`) | Runs `repo-preflight.sh` before a write subagent is dispatched; blocks the delegation (`exit 2`) if the repo needs attention. | B — replace placeholders |
| `repo-preflight.sh` | CLI, not a hook | Reports branch/dirty state per repo, fast-forwards clean base branches, prints `NEEDS_ATTENTION` otherwise. Called by `preflight-gate.sh` or by hand. | A — copy as is |
| `teammate-idle-inbox-gate.sh` | `TeammateIdle` | Keeps a teammate awake while its Agent Teams inbox still holds undelivered messages — closes the checkpoint delivery race. | A — copy as is |
| `papercut.sh` | CLI, not a hook | Records one friction event (dead-end tool call, stale doc, missing permission) as a JSONL line in `logs/papercuts.jsonl`. Agents call it themselves. | A — copy as is |
| `claude-changelog-notify.sh` | `SessionStart` (`startup`) | On the first session after a CLI version bump, fetches the official CHANGELOG and shows the sections you skipped. Silent on every later session. | A — copy as is |

Group **A** works unmodified. Group **B** has placeholders (`<your-agent>`,
`<path-to-repo>`, `<your-command>`) and example blocks you are meant to replace
with your own agents and commands — the mechanics around them are complete.

## How to wire one up

1. Copy the script into your harness at `.claude/hooks/<name>.sh`.
2. `chmod +x .claude/hooks/<name>.sh` — a non-executable hook fails silently,
   which looks exactly like a hook that does nothing.
3. Register it in `.claude/settings.json` (project-level, committed) or
   `.claude/settings.local.json` (yours only, gitignored). Use
   `$CLAUDE_PROJECT_DIR` so the path works regardless of cwd:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Task|Agent",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/log-delegation.sh\""
          }
        ]
      }
    ]
  }
}
```

4. Restart `claude` — settings and hook registrations are read at startup, so an
   edit to `settings.json` does not affect the session you made it in.

For a global hook (every project), the same shape goes into
`~/.claude/settings.json` with an absolute path instead of
`$CLAUDE_PROJECT_DIR`. `claude-changelog-notify.sh` is the natural candidate:
a CLI version bump is not a per-project event.

## The fail-silent invariant

Every observing script here follows the same three rules:

- it opens with `command -v jq >/dev/null || exit 0` — no `jq`, no hook, no error;
- every `jq` extraction has a `// null` fallback, so an undocumented payload
  shape degrades to null fields instead of a broken record or a lost line;
- every write goes out with `2>/dev/null` and the script ends in `exit 0`.

The result: **no observing hook can break your session.** A logger that crashes
on a payload change is worse than no logger, because it takes the session with
it.

Exactly two scripts break the session *on purpose*, and they do it explicitly
with `exit 2` plus a message on stderr:

- `preflight-gate.sh` — denies the delegation and tells the model why;
- `teammate-idle-inbox-gate.sh` — denies the idle and tells the teammate to read
  its inbox.

`exit 2` from a `PreToolUse`-family hook means "block, and feed stderr back to
the model as the reason". That is the whole enforcement mechanism.

## Requirements

- `jq` — all scripts (they exit 0 without it, so a missing `jq` is invisible;
  check with `command -v jq` if a hook seems to do nothing).
- `python3` — `teammate-idle-inbox-gate.sh` only (the inbox JSON is parsed in
  Python).
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — `log-teammate.sh` and
  `teammate-idle-inbox-gate.sh` only. Without Agent Teams enabled, the
  `SendMessage` and `TeammateIdle` events never fire and both hooks are inert.
- `curl` — `claude-changelog-notify.sh` only (a failed fetch degrades to a
  "could not fetch" message, not an error).

## Where the logs go

All loggers write to `logs/*.jsonl` under your harness root
(`sessions.jsonl`, `delegations.jsonl`, `teammates.jsonl`, `papercuts.jsonl`,
`headless-runs.jsonl`), appending one line per event. Read them with `jq`:

```bash
jq -r '.agent' logs/delegations.jsonl | sort | uniq -c | sort -rn
```

Keep `logs/` in `.gitignore`. These files contain prompt text, task
descriptions, and message summaries — they are session content, not artifacts.

## Why two of these are not hooks

`papercut.sh` and `log-headless-run.sh` are called explicitly rather than wired
to an event, and for opposite reasons.

`papercut.sh` has no event to hang on: friction is a judgement, not a lifecycle
point. Something has to decide "that was a dead end", and that something is the
agent — which is why the rule lives in `CLAUDE.md` instead.

`log-headless-run.sh` has the opposite problem: the event exists but fires in
the wrong place. `PostToolUse` on `Task|Agent` covers subagents and teammates,
because those are tool calls the runtime can see. A `claude -p` handoff is a
plain `Bash` call — matching it would mean logging every shell command and then
guessing which ones were handoffs. So the skill that runs the handoff logs it,
one line after the JSON is read.

The consequence is worth stating plainly: **without that line, the runs that
leave your harness are the only ones missing from your stats.** Delegations
inside the session are logged for free; the ones that cross a repository
boundary are exactly the ones you have to log on purpose.
