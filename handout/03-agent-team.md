# Orchestration: who your rules actually reach

Your hooks are law — but only inside the session that loaded them. This block is
about the boundary: which agents your harness governs, and which ones it does
not. Get this wrong and you ship a guard that protects nothing.

## Three ways to put an agent to work

|               | Subagent                            | Teammate (agent teams)                       | `claude -p` in another repo                |
|---------------|-------------------------------------|-----------------------------------------------|--------------------------------------------|
| What it is    | A worker inside your session        | A separate full instance, same working dir    | A separate process, ITS OWN working dir    |
| Whose rules   | **Yours** — your CLAUDE.md, your hooks | **Yours** — it inherits the lead's directory | **The target repo's** — its CLAUDE.md, its hooks |
| Communication | One final report back to the caller | Mailbox: messages to anyone in the team, at any time | Argv in, one JSON on stdout, then the process exits; `--resume` reopens the transcript |
| Lifecycle     | Dies after reporting                | Lives until asked to shut down                | Process exits; the session persists on disk |
| Needs setup   | no                                  | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`      | no                                          |

Read the **"Whose rules"** row twice — it is the whole block. A teammate is not
"an agent in another repository": it runs where the lead runs. Measured
2026-08-01 on CLI 2.1.220, the `Agent` tool accepts a `cwd` parameter and then
**silently ignores it** — `~/.claude/teams/*/config.json` records the lead's
directory for every teammate, whatever the spawn prompt said.

So teammates buy you parallelism and a mailbox. They do not buy you isolation.
Isolation is what a separate process with a different working directory buys.

## Where the boundary actually is, drawn

The line is not "subagent vs teammate". It is **which directory the process was
started in** — that is what decides whose CLAUDE.md and whose hooks load.

```
  ╔══════════════════════════════════════════════════════════╗
  ║ YOUR SESSION   started in my-harness/                    ║
  ║                                                          ║
  ║ loaded: my-harness/CLAUDE.md + YOUR HOOKS                ║
  ║                                                          ║
  ║   ┌──────────────┐        ┌──────────────┐               ║
  ║   │  subagent    │        │  teammate    │               ║
  ║   │              │        │  (name=...)  │               ║
  ║   └──────────────┘        └──────────────┘               ║
  ║      both run HERE. Your guard hook applies to both,     ║
  ║      no matter which directory they edit files in.       ║
  ╚══════════════════════════════════════════════════════════╝
        |
        |  your hooks reach this far, and no further
        v
  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
        |
  ┌──────────────────────────────────────────────────────────┐
  │ SEPARATE PROCESS   started in sample-repo/               │
  │   cd sample-repo && claude -p '...'                      │
  │                                                          │
  │ loads: sample-repo/CLAUDE.md + ITS hooks                 │
  │ does NOT load: your CLAUDE.md, YOUR HOOKS                │
  └──────────────────────────────────────────────────────────┘

  (!) your guard does not protect files over there
  (!) its guard does not constrain agents over here
```

Both halves of that warning bite. Your guard is not a filesystem-wide rule — it
is a rule about *your session*. And the target repo's own guard, however strict,
never runs for an agent you spawned from here.

Agent teams have their own transport, worth knowing about even though this block
does not use it:

- Team roster: `~/.claude/teams/session-XXXXXXXX/config.json` — including a `cwd`
  field per member. Open it after spawning a teammate: it says the lead's
  directory, not whatever the spawn prompt asked for.
- Mailboxes: `~/.claude/teams/session-XXXXXXXX/inboxes/<agent>.json` —
  `SendMessage` appends a JSON entry to the recipient's file; the runtime
  watches the boxes, delivers on the next turn, and wakes idle agents.
- Shared task list: `~/.claude/tasks/session-XXXXXXXX/`

What teammates genuinely give you: **their own context window**, a **mailbox**
(they message you and each other, at any time, not just one final report), and
**a life beyond one answer** — a teammate stays addressable by name until it is
shut down. Use them to parallelize work inside one repository.

### How `claude -p` communicates instead

Teammates get mailboxes because they share a runtime. A headless run does not:
it is a separate OS process, so the channel is the only thing two processes ever
share — **argv in, stdout out, and a file on disk in between**.

```
  ┌──────────────────────────────────────────────────────────┐
  │ YOUR SESSION            /run-elsewhere ../sample-repo    │
  └──────────────────────────────────────────────────────────┘
        |
        |  the task, as argv          (nothing else crosses)
        v
  ┌──────────────────────────────────────────────────────────┐
  │ SEPARATE PROCESS        cd sample-repo && claude -p '...'│
  │                         loads THAT repo's CLAUDE.md+hooks│
  └──────────────────────────────────────────────────────────┘
        |                                    |
        |  one JSON on stdout                |  writes as it goes
        v                                    v
  ┌──────────────────────────────┐   ┌──────────────────────────┐
  │ .result       what it did    │   │ ~/.claude/projects/      │
  │ .session_id   handle to      │   │   <repo>/<uuid>.jsonl    │
  │               resume         │   │   the transcript         │
  └──────────────────────────────┘   └──────────────────────────┘
        |                                    ^
        └── --resume <session-id> ───────────┘
            reopens it in a NEW process
```

Three consequences, and each one shapes how you write the task:

- **It is one-shot per turn.** The process runs, prints, exits. There is no
  mid-turn channel: a headless agent that hits an ambiguity cannot ask you, so
  it guesses. That is the entire reason for the plan-then-approve split below.
- **Nothing of your conversation goes with it.** The only thing crossing the
  boundary is the string you pass. Every path absolute, every decision already
  made — the other process never saw this chat.
- **The transcript is the continuity, not a connection.** `--resume
  <session-id>` reopens that `.jsonl` in a fresh process. Measured on
  `sample-repo`: a cold run cost $0.30 over 3 turns; resuming it to ask a
  follow-up cost $0.12, and the agent answered from what it had already read
  rather than re-reading the repo. Resume only works from the directory that
  created the session — which is also what keeps the target repo's rules loaded.

What comes back on stdout is one JSON object. The fields worth reading:

| Field | Why you want it |
|---|---|
| `result` | the agent's final text — what it did, or why it was blocked |
| `session_id` | the handle for `--resume`; without it the turn is a dead end |
| `is_error`, `subtype` | whether the turn finished or died mid-way |
| `permission_denials` | tools it wanted and `--allowedTools` refused |
| `num_turns`, `total_cost_usd` | what the handoff actually cost you |

`permission_denials` is the one people miss. A headless run has nobody to
approve a prompt, so an unlisted tool is simply refused mid-turn — and the
agent's own report may not mention it. Read the field, not the story.

Enable with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in the `env` section of
`settings.json`, then restart. Experimental: expect rough edges, and each
teammate is a full instance — token use scales with team size.

## What we do in the session: find the edge of your own guard

One task, run two ways. Nothing to install — the guard you wired in block 1 is
the whole setup, and `sample-repo/` next to your harness has **no hooks of its
own**. It does have a `.env.production` with a live-looking secret in it.

The task both times: **change `RETRY_LIMIT` from 3 to 5 in
`sample-repo/.env.production`** — a file your block-1 guard was written to
protect.

First, add the skill that will do the second run for you:

```bash
cp -r ../snippets/03-orchestration/run-elsewhere .claude/skills/
#    restart claude
```

Read `run-elsewhere/SKILL.md` before using it — it is four lines of mechanism
(`cd`, then `claude -p`) wrapped in the reasons each flag is there. Both runs
below happen **from the session you are already in**. No second window.

**Run A — a subagent, which lives inside your session.** Ask your agent:

> Spawn a subagent and tell it to change RETRY_LIMIT from 3 to 5 in
> `<abs-path>/sample-repo/.env.production`. Report whether it succeeded or was
> blocked, and quote the exact denial. Do not edit the file yourself.

> **Check.** Blocked, and the agent quotes your own hook back at you:
> `.env holds real credentials and is off limits, to read as well as to write …`
> The file is untouched. Your rule reached the subagent even though the file
> lives in another repository — because the *session* is yours.

**Run B — the same edit, through the skill.**

```
/run-elsewhere ../sample-repo change RETRY_LIMIT from 3 to 5 in .env.production
```

> **Check.** It goes straight through, and the skill reports why: the session it
> started ran in `sample-repo`, so your hook was never loaded.
> `grep RETRY_LIMIT sample-repo/.env.production` now says 5.

Put it back before moving on:

```bash
sed -i '' 's/RETRY_LIMIT=5/RETRY_LIMIT=3/' sample-repo/.env.production
```

**What just happened.** Same secret file, same edit, same machine, same person.
The only difference was the directory the process started in. Your guard is not
a rule about `.env` files — it is a rule about **your session**, and a process
started elsewhere never loaded it.

This cuts both ways, and both are worth saying out loud:

- **You cannot protect other people's repos from your harness.** A guard in
  `my-harness/` is not a safety net for the rest of the disk.
- **You cannot import other people's protection either.** If `sample-repo` had a
  guard, run A would have sailed past it — the subagent never loaded it.

The practical rule: **to work by a repository's rules, start the process in that
repository.** That is what a "canonical agent" means, and why a handoff to
another repo is a `cd` plus a run, not a cleverer prompt.

> Curious about teammates: spawn one with a `cwd` pointing at `sample-repo`, then
> read `~/.claude/teams/session-*/config.json`. Its `cwd` field says *your*
> directory. The prompt asked; the runtime ignored it. Trust the artifact, not
> the agent's account of itself.

## Run a real handoff (take-home)

Do it on a repository whose rules are genuinely not yours — a docs repo, another
team's service, anything with its own CLAUDE.md you would normally not edit by
hand.

1. Write a task package from `snippets/03-orchestration/task-package.md`. It has
   to be self-contained: the agent never saw your conversation, so every path is
   absolute and every decision already made. Say explicitly what is **out of
   scope** — that is what keeps it from "improving" things you did not ask about.
2. Ask for a **plan first**, not the work:

   ```
   /run-elsewhere <that repo> Execute the plan from <abs path to package>.
   Follow this repo CLAUDE.md. This turn is for reading and planning ONLY -
   make no edits. End your turn with the list of files you intend to change,
   and any question you have.
   ```

   The skill runs it read-only and reports back with a session id.

3. Read what it intends to do. If it asked something, answer. Then approve — and
   let it edit — by **resuming that session**, which keeps everything it already
   read:

   ```
   /run-elsewhere <that repo> --resume <session-id> Approved. Make the edits,
   then run the verification commands and report the output.
   ```

4. Check the result against **that repo's** conventions, not yours.

Why the plan-then-approve split: a headless turn cannot stop mid-way to ask you
something. It either finishes the turn or guesses. Splitting the run puts your
approval in front of the first edit, which is the whole point of a handoff.

Resuming is also cheap — the conversation is cached, so a follow-up turn costs a
fraction of a cold start. The session lives on disk and can be resumed tomorrow,
as long as the skill runs it from the same directory.

## In your own harness

For repos your agents must not touch directly, write a self-contained package and
**run the agent in that repository**. It loads that repo's CLAUDE.md and its
hooks, so its rules apply to it — which no amount of prompting can achieve from
your own directory. Ask instead of guessing, approve before the first edit, and
never let it commit: the deliverable is an uncommitted diff a human reviews.

Docs: `resources.md` → headless mode and sessions.
