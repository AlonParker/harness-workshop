# Build Your Own Harness — workshop materials

Participant materials for the "Advanced Claude Code: Hooks, Memory &
Orchestration" workshop. During the session you scaffold your OWN harness
project and wire its first layers; this repo is your toolkit and
take-home.

A **harness** is everything around the model that turns "chatting with an
agent" into a system: rules it cannot forget (hooks), decisions that
survive the session (memory), work handed to agents in other repos
(orchestration), and a feedback loop (tracing).

## What you will have built by the end

```
                              YOU
                               │  a prompt
                               v
  ╔══════════════════════════════════════════════════════════╗
  ║ (1) HOOKS   the runtime enforces; the model cannot skip  ║
  ║                                                          ║
  ║   UserPromptSubmit --> inject a standing rule, every turn║
  ║   PreToolUse       --> guard: block an edit (exit 2)     ║
  ║   Stop             --> sound: "your turn"                ║
  ╚══════════════════════════════════════════════════════════╝
                               │
                               v
  ┌──────────────────────────────────────────────────────────┐
  │ THE MODEL      CLAUDE.md = what it SHOULD do (soft)      │
  └────────────┬────────────────────────────┬────────────────┘
      "what did we decide?"          delegates work
               v                            v
  ╔═════════════════════════╗   ╔════════════════════════════╗
  ║ (2) MEMORY              ║   ║ (3) ORCHESTRATION          ║
  ║                         ║   ║                            ║
  ║  add_memory  --> store  ║   ║  subagent --> your session ║
  ║  search_memory <-- hook ║   ║  claude -p --> ITS OWN repo║
  ║                         ║   ║     its CLAUDE.md, skills, ║
  ║  the fact, the WHY,     ║   ║     hooks, MCP, mailbox    ║
  ║  status, verified_at    ║   ║                            ║
  ║                         ║   ║  needs YOUR fact? it ASKS  ║
  ║  mem0 + Qdrant, local   ║   ║                            ║
  ╚═════════════════════════╝   ╚════════════════════════════╝
               │                            │
               └─────────────┬──────────────┘
                             v
  ╔══════════════════════════════════════════════════════════╗
  ║ (4) TRACING   the loop that keeps it from rotting        ║
  ║                                                          ║
  ║   PostToolUse --> logs/delegations.jsonl (who ran/failed)║
  ║   papercut.sh --> logs/papercuts.jsonl    (friction: your║
  ║                   AGENTS log it too, and hit far more)   ║
  ║                             │                            ║
  ║   SKILLS read them:  /harness-stats   /papercuts         ║
  ║   weekly: read, fix ONE thing, feed it back to (1)       ║
  ╚══════════════════════════════════════════════════════════╝
```

Four layers, in that order — each one leans on the previous. Hooks make the
rules real; memory gives the rules context; orchestration multiplies the
whole thing; tracing tells you where it hurts.

You will not finish all four in one session, and you are not meant to. See
`handout/CHECKLIST.md` for what we do together and what you take home.

## Before the workshop

```bash
git clone <this repo> && cd harness-workshop
bash setup/check.sh
```

Everything must be green — see `setup/pre-workshop.md`. We build live;
broken setups are not fixable during the session.

## What's here

| Path                                | What it is                                                  | When you use it                          |
|-------------------------------------|-------------------------------------------------------------|------------------------------------------|
| **`my-harness/`**                   | **your harness — an empty scaffold; run `claude` from here** | **the whole workshop**                   |
| **`snippets/`**                     | **ready fragments to copy in, split by block**              | **every block**                          |
| **`handout/CHECKLIST.md`**          | **the map: every layer, marked session vs take-home**       | **read first**                           |
| `setup/`                            | environment check, optional local mem0 + Qdrant             | before the session                       |
| `handout/00-draft-plan.md`          | the five-layer plan for when you keep building after today  | take-home                                |
| `handout/example-tasks.md`          | seed ideas for "what my harness should do"                  | brainstorm                               |
| `handout/01-hooks.md`               | wire three hooks into your project (sound / inject / guard) | hooks block                              |
| `handout/02-memory.md`              | build a curated decisions memory + hygiene rules            | memory block                             |
| `handout/02-memory-dump.md`         | curation practice: 3 days of a fake team Slack, 4 traps     | take-home                                |
| `handout/02-memory-dump-answers.md` | the reference curation — open it *after* you try            | take-home                                |
| `handout/03-agent-team.md`          | agent teams: what the demo showed + replay it at home       | take-home                                |
| `handout/04-tracing.md`             | logs, papercuts, cost — the feedback loop                   | take-home (one evening)                  |
| `handout/05-hook-mechanics.md`      | reference: the eight things a hook can do                   | when you need a hook to do something new |
| `snippets/03-orchestration/`        | the `/run-elsewhere` skill, teams env snippet, task-package template | orchestration block & take-home  |
| `snippets/04-extras/`               | a status line: model, context-usage bar, directory, topic   | take-home                                |
| `handout/resources.md`              | official docs, articles, tools                              | after                                    |
| **`toolkit/`**                      | **whole pieces to copy into your own harness: ten hook scripts that write logs, three skills that read them** | **tracing block & take-home** |
| `sample-repo/`                      | a stand-in for "another team's repo": its own CLAUDE.md, no hooks of its own, a `.env.production` with a secret | orchestration block |

## The layers, in one screen

1. **Hooks** — shell commands the runtime executes at lifecycle points.
   A CLAUDE.md rule is a request; a hook is law. You write three.
2. **Memory** — a curated decisions store (`status`, `verified_at`,
   the why), retrieval wired via CLAUDE.md + an inject hook. Garbage in
   memory is worse than no memory.
3. **Orchestration** — subagents and teammates work inside YOUR session and
   under YOUR hooks; a `claude -p` run started in another repository works
   under THAT repo's rules. Knowing which is which is the block.
4. **Tracing** — JSONL logs of delegations, a friction log, and the skills
   that read them. The loop that makes the harness improve instead of rot.
   Take-home: everything is written, you copy and wire it.

Work through them in order — each layer builds on the previous one. Layers 1–3
we build together; layer 4 is yours for the evening after.
