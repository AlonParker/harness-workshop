# Hook mechanics: the eight things a hook can do

Reference, not an exercise. You wrote three hooks in `01-hooks.md`; this is
the full vocabulary, so you can look up "how do I make it do X" later.

Every mechanic below has a working example in `toolkit/scripts/` — one exception,
noted where it applies.

## The eight mechanics

| # | Mechanic                              | How                                                       | Example                                                  |
|---|---------------------------------------|-----------------------------------------------------------|----------------------------------------------------------|
| 1 | **Add text to the model's context**   | print to stdout                                           | `prompt-router.sh`                                       |
| 2 | **Tell the user something, for free** | JSON with `systemMessage`                                 | `session-motd.sh`                                        |
| 3 | **Inject context explicitly**         | JSON with `hookSpecificOutput.additionalContext`          | `claude-changelog-notify.sh`                             |
| 4 | **Observe without interfering**       | append JSONL, always `exit 0`                             | `log-session.sh`, `log-delegation.sh`, `log-teammate.sh` |
| 5 | **Do slow work without blocking**     | `( ... ) &` plus a log in `$TMPDIR`                       | *demo only — see below*                                  |
| 6 | **Run rarely, not every time**        | a state file: date stamp, seen-version, TTL, content hash | `claude-changelog-notify.sh`, `preflight-gate.sh`        |
| 7 | **Rewrite what the tool receives**    | `updatedInput` + `permissionDecision: "allow"`            | *demo only — see below*                                  |
| 8 | **Block the action outright**         | write to stderr, `exit 2`                                 | `preflight-gate.sh`, `teammate-idle-inbox-gate.sh`       |

## The distinctions that actually matter

**2 vs 3 is a token question.** `systemMessage` is shown to *you* in the
terminal and never enters the model's context — a 50-line cheat-sheet
printed this way costs nothing, every session, forever.
`additionalContext` is read by the model, so you pay for it every time.
Use `systemMessage` for things humans need and models do not.
`claude-changelog-notify.sh` uses both in one JSON payload, which makes it
the clearest example to read.

**1 vs 3.** Plain stdout on `UserPromptSubmit` gets appended to the
prompt — simplest possible injection, and enough for most cases. The
`additionalContext` field exists for events where stdout is not treated as
context.

**8 is the one that makes a hook law.** stderr plus `exit 2` does not just
stop the action: the stderr text is handed back to the agent as feedback,
so it can react. This is the difference between a `CLAUDE.md` rule (a
request the model may forget) and a hook (a rule the runtime enforces).
`preflight-gate.sh` blocks delegating work into a dirty repo;
`teammate-idle-inbox-gate.sh` blocks a teammate from going idle while
messages are still undelivered to it.

Note what 8 is *not* for: a gate that fires on things you actually do
often will teach you to work around it. Block the expensive mistakes only.

**6 is what keeps 5 and 3 affordable.** A `SessionStart` hook runs on every
single session. Without a state file, "check the changelog" becomes
"fetch a changelog fifteen times a day". The state-file variants worth
knowing: a date stamp (once per calendar day), a seen-version marker (once
per upgrade), a TTL stamp (at most every N seconds), a content hash (only
when the thing actually changed).

## The invariant: fail-silent

Every script in `toolkit/scripts/` opens with some form of

```bash
command -v jq >/dev/null 2>&1 || exit 0
```

every `jq` expression has a `// null` fallback, and every write is
`2>/dev/null`. A hook that crashes on an unexpected payload would break
*every* session, including the one where you are trying to fix it. So:

> An observing hook must never be able to fail loudly. If it cannot do its
> job, it exits 0 and stays quiet.

The two blocking hooks are the deliberate exception — and they fail via an
explicit `exit 2` with a readable reason, never via a crash.

## The two mechanics without a file here

**5 (background work)** and **7 (rewriting tool input)** are shown in the
demo but not shipped in `toolkit/scripts/`, because the real implementations depend
on tooling you do not have installed:

- 5 — a `SessionStart` hook that re-indexes repositories in the background:
  `( heavy_thing >"$TMPDIR/log" 2>&1 ) &` then `exit 0` immediately. The
  session starts instantly; the work lands later. The pattern is three
  lines; the payload is what needs the tooling.
- 7 — `PreToolUse` on `Bash` that returns `updatedInput` with a different
  command and `permissionDecision: "allow"`. In the demo: the agent types
  `git status`, the machine runs a token-optimising proxy instead, and the
  agent never knows. Powerful and easy to misuse — if the rewrite is not
  strictly equivalent, you have made your harness lie to the agent.

## Bonus: a status line (not a hook, same settings file)

`statusLine` runs a command and renders its stdout, dimmed, at the bottom of the
session. Mechanically it is the sibling of everything above — a shell command the
runtime calls, JSON on stdin — but it only *displays*, so it can never block or
break a turn.

```bash
cp ../snippets/04-extras/statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
#    then merge ../snippets/04-extras/06-statusline.json into ~/.claude/settings.json
#    and restart claude
```

What you get:

```
Opus 5 [####------] 43%          my-harness · wiring the guard hook
```

Model, a context-usage bar, the working directory, and the session topic
(`/rename`, or the title Claude Code generates on its own).

The bar is the point. Context fills up invisibly otherwise, and the first sign is
a compaction you did not plan for — usually mid-task. Seeing `[########--] 82%`
lets you finish the thought, or start a fresh session on purpose.

The directory matters more than it looks, too: once you run agents in other
repositories (block 3), "which directory am I in" stops being obvious and starts
deciding whose rules apply.

Note it goes in **`~/.claude/settings.json`** — a status line is a property of
how *you* like to work, not of one project.

## Where to look things up

The official hooks reference lists every event and every field of the JSON
payload — `resources.md` has the link. Two habits that save time:

1. `echo "$INPUT" | jq .` into a log file first, look at the real payload,
   *then* write the logic. Payload shapes change between releases;
   `log-teammate.sh` even records `raw_keys` for exactly this reason.
2. Restart `claude` after editing `settings.json`. Hook definitions are
   read at startup.
