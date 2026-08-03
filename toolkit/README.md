# Toolkit — whole pieces to copy into your own harness

Two libraries, and one idea that only makes sense when you see them together:

```
  ┌──────────────────────────────────────────────────────┐
  │ toolkit/scripts/   10 hook scripts   they WRITE      │
  │        │                                             │
  │        v            logs/*.jsonl                     │
  │        │                                             │
  │ toolkit/skills/     3 skills         they READ       │
  └──────────────────────────────────────────────────────┘
```

A log nobody reads is disk usage. A reader with nothing to read is a skill that
reports zero. Wire a writer, then wire its reader - that pairing is the tracing
layer, and it is why these two directories now sit under one roof.

| Writer (`scripts/`)   | Reader (`skills/`) | Through            |
|-----------------------|--------------------|--------------------|
| `log-delegation.sh`   | `harness-stats`    | `logs/delegations.jsonl`  |
| `log-headless-run.sh` | `harness-stats`    | `logs/headless-runs.jsonl` |
| `papercut.sh`         | `papercuts`        | `logs/papercuts.jsonl`    |
| -                     | `memory-hygiene`   | your mem0 store          |

`memory-hygiene` is the odd one out on purpose: it audits the memory block's
store rather than a log, and needs no script in front of it.

## Nothing here is wired

This repository does not execute any of it. No `settings.json` in the workshop
kit registers these hooks, and no skill here is installed. That is deliberate -
you read a script before you let it run in your own harness, and a workshop
repo that quietly logged your prompts would be teaching the wrong lesson.

To use a piece, copy it out:

```bash
cp toolkit/scripts/papercut.sh   <your-harness>/.claude/hooks/
cp -r toolkit/skills/papercuts   <your-harness>/.claude/skills/
```

Then register the hook and restart `claude`. Per-directory detail lives in
`scripts/README.md` (wiring, the fail-silent invariant, requirements) and
`skills/README.md` (what a skill is, how to write your own).

## Distinct from `snippets/`

`snippets/` holds fragments you paste **during** the session - a JSON block into
`settings.json`, a few lines into a file that already exists. The toolkit holds
complete files you copy **whole** and mostly do not edit. Group A scripts work
unmodified; Group B has placeholders marked in `scripts/README.md`.

Both are take-home. The difference is what you do with them, not when.
