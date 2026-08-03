# Skill library

Three skills to copy into **your own** harness. Like `toolkit/scripts/`, they are
deliberately not active in this repository — nothing here runs them.

## What a skill is, and why these exist

A skill is a named procedure the agent loads on demand: you type `/papercuts`,
the agent reads the instructions and follows them. It is the third kind of thing
in a harness, next to hooks and scripts:

| | What it is | When it runs |
|---|---|---|
| hook | shell command at a lifecycle point | automatically, the runtime decides |
| script | a tool you or your agents call | when called |
| **skill** | a procedure the agent follows | when you invoke it by name |

These three exist because the tracing layer is otherwise half-built. The
scripts in `toolkit/scripts/` **write** logs; nothing **reads** them. A log nobody reads
is disk usage — so each skill here is the reader for something you wired up.

| Skill | Reads | Pairs with |
|---|---|---|
| `harness-stats` | `logs/delegations.jsonl`, `logs/headless-runs.jsonl` | `toolkit/scripts/log-delegation.sh`, `toolkit/scripts/log-headless-run.sh` |
| `papercuts` | `logs/papercuts.jsonl` | `toolkit/scripts/papercut.sh` |
| `memory-hygiene` | your mem0 store | the memory block (`handout/02-memory.md`) |

## Install

```bash
mkdir -p <your-harness>/.claude/skills
cp -r toolkit/skills/papercuts <your-harness>/.claude/skills/
```

Restart `claude`, then type `/papercuts`. The directory name is the command
name; `SKILL.md` is the whole skill.

## Writing your own

Read one of these three and you have the format: YAML frontmatter with `name`
and `description`, then instructions in Markdown. Two things worth copying:

- **The `description` is how the agent decides to use it.** Write it as "what
  this does and when to use it", not as a title. This is also what makes a skill
  fire without you typing the command.
- **State what the data cannot tell you.** All three of these have a section on
  their own blind spots. A report that presents gaps as findings is worse than
  no report.

The stricter pattern to steal: these skills **propose and do not apply**. A
review that edits your CLAUDE.md by itself is a review you will stop running.
