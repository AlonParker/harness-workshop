# Resources & further reading

Take-home material: the tools used today, the official documentation, and
two articles that put "harness" into an industry context.

## Official Claude Code documentation

| Topic                                                                  | Link                                                 | Workshop block |
|------------------------------------------------------------------------|------------------------------------------------------|----------------|
| Hooks reference (events, JSON in/out, decision blocks)                 | https://code.claude.com/docs/en/hooks                | 1              |
| Hooks guide (recipes, security notes)                                  | https://code.claude.com/docs/en/hooks-guide          | 1              |
| Settings (`settings.json`, permissions, scopes)                        | https://code.claude.com/docs/en/settings             | 1              |
| Memory (`CLAUDE.md`, auto-memory)                                      | https://code.claude.com/docs/en/memory               | 2              |
| Subagents                                                              | https://code.claude.com/docs/en/sub-agents           | 3              |
| Headless / CLI mode (`claude -p` — how we spawned the clean agent)     | https://code.claude.com/docs/en/cli-reference        | 3              |
| Agent teams (experimental)                                             | https://code.claude.com/docs/en/agent-teams          | 3              |
| MCP (connecting external tools: Crashlytics, Jira, vector stores)      | https://code.claude.com/docs/en/mcp                  | demos          |
| Agent SDK (building your own agents/daemons on the same engine)        | https://docs.anthropic.com/en/api/agent-sdk/overview | outlook        |

Agent teams: spawned teammates with a shared task list and inter-agent
messaging, for parallel work inside one repository. Experimental; enabled via
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. A teammate runs in the **lead's**
working directory, so it is not the way to run an agent by another repo's rules
— that is a `claude -p` started in that repo, which is what the production
handoff mechanism does. Sessions and `--resume`:
https://code.claude.com/docs/en/agent-sdk/sessions

## Articles

### Anthropic — Effective harnesses for long-running agents

https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

How to make an agent survive work that spans many context windows. Key
ideas, several of which you met today in miniature:

- A harness manages environment setup, progress tracking and incremental
  completion — the model alone doesn't.
- Split roles: an initializer agent sets up, a coding agent continues —
  each with its own prompt (compare: our orchestrator vs clean spawn).
- Externalize state: a structured feature list (pass/fail per item) and
  progress logs instead of relying on the model's recall — the same move
  as our decisions store, at project scale.
- Every session starts with a standard ritual: read the log, check git
  history, run baseline tests, pick ONE next item.
- Verify end-to-end (browser automation), not just unit tests — code
  that "looks right" isn't evidence.
- An `init.sh` that restores the environment cheaply each session.

### Birgitta Böckeler (martinfowler.com) — Harness engineering

https://martinfowler.com/articles/harness-engineering.html

A vocabulary for what we built today. Harness = "everything in an AI
agent except the model itself":

- Two control types: **guides** (feedforward — prevent bad output before
  it happens) and **sensors** (feedback — observe and self-correct). Our
  guard hook is a guide; the PostToolUse logger is a sensor.
- Prefer deterministic controls (linters, tests, type checkers) where
  possible — fast and reliable; save probabilistic ones (AI review) for
  where semantics matter.
- Three maturity areas: maintainability (mostly solved), architecture
  fitness, behavior/correctness (least mature).
- Humans don't vanish — a good harness routes human attention to where
  it matters most.
- Timing: cheap checks before commit; expensive sensors post-integration.

## Tools used or shown today

| Tool                                    | What it did                               | Where to get it                                 |
|-----------------------------------------|-------------------------------------------|-------------------------------------------------|
| Claude Code                             | the agent + hook runtime                  | see official docs above                         |
| `jq`                                    | JSON parsing inside hooks                 | `brew install jq` · `apt install jq`            |
| mem0 (OSS library)                      | vector memory for decisions (bonus track) | https://github.com/mem0ai/mem0                  |
| the MCP server that wires it in         | `my-harness/mem0/server.py` in this repo       | ~100 lines, yours to read and change            |
| Qdrant                                  | the vector store behind mem0              | https://qdrant.tech                             |
| podman                                  | runs Qdrant (Docker is not allowed here)  | `brew install podman` · `apt install podman`    |
| `uv`                                    | runs the mem0 MCP server                  | https://docs.astral.sh/uv/                      |
| MCP servers (Crashlytics, Atlassian, …) | demos: crash triage, ticket drafts        | https://code.claude.com/docs/en/mcp             |
| codebase-memory-mcp (code graph)        | demo: "who calls X" across modules        | https://github.com/DeusData/codebase-memory-mcp |
| rtk (token-optimizing CLI proxy)        | the Rewrite demo                          | https://www.rtk-ai.app · `brew install rtk`     |

## Where to go next in your repo

Check whether the repo you work in daily already carries agent
instructions — a `CLAUDE.md`, a `docs/agents/` directory, existing skills
or hooks. If it does, you are extending a harness rather than starting
one, and the fastest win is adding your first hook to what is already
there.

The layers we did not cover today: per-module expert subagents, a shared
team memory store with hygiene rules, and package-based handoff for
cross-team changes. `CHECKLIST.md` lists them with pointers.

Start with one hook and three memory entries — that is how the production
harness in the demo started too.
