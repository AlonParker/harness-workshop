# Draft plan: my personal AI harness

**Take-home.** The workshop builds layers 1-4 in `my-harness/`, which already
exists — you do not need this file to get started.

What it is for: the whole picture, including the two layers we do not reach on
the day, for when you keep building. Paste it into Claude in your harness and
replace the placeholders with YOUR task ideas from the brainstorm — the layers
below stay.

---

## Goal

A personal harness on top of Claude Code: a set of rules, hooks, memory
and agents that turns "chatting with a model" into a system that does my
recurring work. First target task: `<your #1 task from the brainstorm>`.

## Principles

- The harness lives in its own repo; my work repos are siblings it
  operates on (paths like `../my-app`).
- Agents never commit or push in work repos; results stay as uncommitted
  changes for me to review.
- Anything that must ALWAYS happen is a hook, not a hope: rules in
  CLAUDE.md are requests, hooks are law.
- Memory stores only accepted decisions and verified findings, with
  dates. Never drafts, never guesses.

## Layers to build (in order)

### 1. Skeleton

- `CLAUDE.md` — who this harness is, the map of my repos, hard rules.
- `.claude/settings.json` — hook wiring, permissions.
- `.gitignore` — local logs, personal settings.

### 2. Hooks

- Completion sound on `Stop` — know when the agent needs me.
- `UserPromptSubmit` inject — a reminder line added to every prompt
  (later: "search memory first").
- A `PreToolUse` guard — block edits to files agents must not touch.

### 3. Decisions memory

- mem0 + Qdrant on localhost, my own collection.
- Entry discipline: the fact (verbatim, self-contained), `status:
  accepted|superseded`, `verified_at`, and the WHY. CLAUDE.md + the inject
  hook make the agent call `search_memory` before answering.
- Later: a watchdog pass that dedupes and flags stale entries.

### 4. Orchestration

- One domain subagent per work repo / area, routed from CLAUDE.md.
- For repos my agents must not edit directly: a task package plus
  `cd <that repo> && claude -p '<package>'`, continued across turns with
  `--resume`. Starting the process there is what makes that repo's CLAUDE.md
  and hooks apply — a subagent or a teammate stays under MY rules wherever it
  writes.
- Agent teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) for parallel work
  inside one repo: own context per teammate, mailboxes, they outlive a reply.

### 5. Tracing / logs

- PostToolUse JSONL logger → which agents run, how often, what fails.
- A friction log ("papercuts") — dead ends get recorded, then fixed in
  batches.
