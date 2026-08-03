# Tracing, logs, papercuts: the feedback loop (Home Work)

The layer nobody builds first and everybody wishes they had.

**This whole block is take-home** — we do not build it during the session,
because it needs nothing from the session. Every piece is already written in
`toolkit/scripts/` and `toolkit/skills/`; you copy and wire them. Budget one evening.

You do NOT type any of this by hand.

## The loop

```
  your harness at work
  ════════════════════
  ╔══════════════════════════════════════════════════════════════════╗
  ║  delegations        teammate msgs         friction               ║
  ║       │                   │                  │                   ║
  ║       v                   v                  v                   ║
  ║  PostToolUse         PostToolUse         papercut.sh             ║
  ║  (Task|Agent)        (SendMessage)       (a CLI -- YOU and       ║
  ║                                          your AGENTS call it)    ║
  ╚══════════════════════════════════════════════════════════════════╝
         │                   │                  │
         v                   v                  v
  delegations.jsonl   teammates.jsonl   papercuts.jsonl
         │                   │                  │
         └───────────────────┼──────────────────┘
                             │
                             v
  ┌──────────────────────────────────────────────────────────────────┐
  │ logs/  (gitignored -- holds prompt text!)                        │
  └──────────────────────────────────────────────────────────────────┘
                             │
                             v      <-- the step everyone skips
  ╔══════════════════════════════════════════════════════════════════╗
  ║ SKILLS READ IT          /harness-stats                           ║
  ║ (you still invoke       /papercuts                               ║
  ║  them -- weekly)        /memory-hygiene                          ║
  ╚══════════════════════════════════════════════════════════════════╝
                             │
                             v
  fix ONE thing: a rule, a hook, a permission
                             │
                             └──> back into the harness
```

Logs that nobody reads are just disk usage. The arrow that closes the loop
is a habit, not a script — which is why it is the one that fails.

## 1. Delegation log

```bash
cp toolkit/scripts/log-delegation.sh <your-harness>/.claude/hooks/
chmod +x <your-harness>/.claude/hooks/log-delegation.sh
```

Wire it in `.claude/settings.json`:

```json
"PostToolUse": [
  {"matcher": "Task|Agent",
   "hooks": [{"type": "command",
              "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/log-delegation.sh\"",
              "timeout": 5}]}
]
```

**Verify:** ask your agent to delegate something (any subagent), then
`cat logs/delegations.jsonl` — one JSONL line per delegation.

`logs/` is already in this repo's `.gitignore`; add it to yours. The log
contains prompt text and task descriptions — it is not for committing.

A month later this log answers: which agents actually run, which fail,
where routing misfires. Note what it cannot answer: for background
delegations `duration_ms` and `tokens` are always `null`, because
PostToolUse fires when the task *starts*. The `bg` field exists so you can
tell "no metrics by design" from "metrics went missing".

Its sibling, `toolkit/scripts/log-teammate.sh` (matcher `SendMessage`), does the
same for Agent Teams messages. Same copy-and-wire, needs
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

## 2. Papercuts: the friction log

If you do only one thing from this file, do this one. It is the most valuable
habit in the whole workshop, and it costs two minutes to set up.

```bash
cp toolkit/scripts/papercut.sh <your-harness>/.claude/hooks/
chmod +x <your-harness>/.claude/hooks/papercut.sh
```

It is a CLI, not a hook — you and your agents call it directly:

```bash
bash .claude/hooks/papercut.sh tool-failure "MCP server timed out on startup" mem0-local
```

Categories: `tool-failure`, `stale-doc`, `broken-link`,
`missing-permission`, `routing-gap`, `env`, `other`. Anything else is
coerced to `other`, so you cannot break it by guessing wrong.

Then add the rule to your `CLAUDE.md` — this is the part that makes it
work:

> Friction encountered during work — a dead-end tool call, a broken
> link, a stale instruction, a repeated permission denial — is RECORDED,
> not silently pushed through: run `.claude/hooks/papercut.sh`. Recording
> a papercut never replaces finishing the task.

Without that rule, only you log papercuts. With it, your agents log the
friction they hit — and they hit far more of it than you see.

**Verify:** record one papercut about something that annoyed you during the
workshop — you will still remember at least one. Then `cat
logs/papercuts.jsonl`. That single line is your feedback loop, already running.

## 3. The readers (this is the half that closes the loop)

You just wired two writers. Now copy their readers — `toolkit/skills/` has both:

```bash
mkdir -p <your-harness>/.claude/skills
cp -r toolkit/skills/harness-stats toolkit/skills/papercuts <your-harness>/.claude/skills/
```

Restart `claude`, then type `/papercuts`. The agent reads the log, groups it by
category and by target, shows what repeats, and drafts one fix.

`/harness-stats` does the same for delegations: who actually works, which tasks
no specialised agent claimed, what you asked for repeatedly (a candidate for a
skill of its own).

Both **propose and never apply**. A review that edits your CLAUDE.md by itself
is a review you stop trusting.

`toolkit/skills/memory-hygiene` is the third one — it audits the mem0 store from the
memory block instead of a log. See `toolkit/skills/README.md`.

## 4. Token / cost awareness

- `/cost` in a session shows the current spend.
- Teams and subagents multiply context windows — if you build fleets, log
  token usage per agent (the delegation log is the place).
- Cheap wins first: a rewrite-proxy for shell output, code-graph queries
  instead of grep-and-read — see `resources.md`.

## The habit

Logs only pay off if something reads them. Now something does — but invoking it
is still on you. Schedule it: a weekly `/papercuts` plus `/harness-stats`.
Recurring complaints become harness fixes — a rule, a hook, a permission. That
loop is the difference between a harness that improves and one that rots.

In production this is a morning hook compiling a digest. Start with a
calendar reminder; the scripts in `toolkit/scripts/` are the same ones that feed
that digest.

Everything else you could still build is listed in `CHECKLIST.md`.
