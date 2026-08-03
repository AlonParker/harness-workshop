# The checklist: everything you could build, and what we actually do today

Read this before the workshop. It is the map.

**There are 16 SESSION items — 1 for the scaffold, 5 hooks, 6 memory, 4
orchestration. Close them and the workshop worked for you.**

You do not type any of them from scratch: every fragment is ready in
`snippets/`, split into `01-hooks/`, `02-memory/`, `03-orchestration/`. You copy
it into `my-harness/` and check that it works. A typo in JSON costs you the
block, and typing teaches nothing.

The whole tracing layer (section 5) is take-home by design — it is pure
copy-and-wire and needs nothing from the session.

Everything marked TAKE-HOME is *designed* to be unfinished when we say
goodbye — the scripts and the instructions are already in your hands, and the
whole point of the take-home part is that you can finish it without me. Nobody
completes this list in one session. That is not a failure mode, it is the plan.

- `[ ] SESSION` — we do it together, I am there when it breaks
- `[ ] TAKE-HOME` — you have everything needed; do it when you need it

Each item says **what to do**, **how you know it worked**, and **where it is
written down**. Skip the "how you know" and you get a harness that looks wired
and does nothing — that exact bug shipped in an earlier version of this repo.

---

## 0. Before the session

| | Item | How you know | Where |
|---|---|---|---|
| `[ ] pre` | Claude Code installed, logged in, model answers | `claude --version` ≥ 2.1.178 | `setup/pre-workshop.md` |
| `[ ] pre` | `jq` and `python3` present | `bash setup/check.sh` all green | `setup/check.sh` |
| `[ ] pre` | Repo cloned, check green | last line says "You are ready" | — |
| `[ ] pre` | **mem0 + Qdrant installed** (podman, uv, model, `.mcp.json`) | `bash setup/check.sh` — all five mem0 checks green | `my-harness/mem0/README.md` |

The memory block runs on mem0; there is no file-based fallback. The install
is over a gigabyte of downloads, so it cannot be done during the session —
do it at least a day ahead.

---

## 1. Your harness

The scaffold already exists: `my-harness/` in this repo. Nothing to create.

| | Item | How you know | Where |
|---|---|---|---|
| `[ ] SESSION` | Run `claude` from inside `my-harness/` | ask "which directory are you working in?" — it says `my-harness` | `my-harness/README.md` |
| `[ ] TAKE-HOME` | Write your `CLAUDE.md`: what this harness is for, 3 house rules | fresh session, ask "what are my rules?" — it quotes them | `my-harness/CLAUDE.md` — fill in its TODOs |
| `[ ] TAKE-HOME` | Pick your #1 real task from the brainstorm and write it down as the harness's purpose | it names a task you actually do weekly | `handout/example-tasks.md` |
| `[ ] TAKE-HOME` | Read the five-layer plan for when you keep building | you know what layers 4-5 would add | `handout/00-draft-plan.md` |

## 2. Hooks — the layer that makes rules law

Copy the fragments **one at a time** from `snippets/01-hooks/` and check each
before the next.

| | Item | How you know | Where |
|---|---|---|---|
| `[ ] SESSION` | Sound on `Stop` **and a different one** on `Notification` | you hear it when the answer lands, and the two sounds differ | `01-hooks.md` §1 |
| `[ ] SESSION` | The inject hook on `UserPromptSubmit` | ask "what extra instructions came with my prompt?" — it quotes your line | `01-hooks.md` §2 |
| `[ ] SESSION` | The guard hook on `PreToolUse`, protecting `.env.production` | change `RETRY_LIMIT` → refused; **ask for the API key in words** → also refused (that is why `Read` is in the matcher); edit `CLAUDE.md` → **works** | `01-hooks.md` §3 |
| `[ ] SESSION` | Read `guard-env.sh` — JSON on stdin, deny on stdout, reason goes back to the model | you can say why a guard that only says "no" is one you stop using, and why it lists names instead of matching `*.env.*` | `01-hooks.md` §3 |
| `[ ] SESSION` | Know what the guard does **not** cover | you can name two ways past it: `@.env.production` (the CLI expands it while assembling the prompt, so no tool call happens) and `cat .env.production` (`Bash` is not in the matcher, on purpose — see §3) | `01-hooks.md` §3 |
| `[ ] TAKE-HOME` | Add a second `case` branch with a file from your **own** project | trigger it on purpose; the agent reports being blocked | `01-hooks.md` §3 |
| `[ ] TAKE-HOME` | Read the other five mechanics you did not use | you know which one to reach for next | `05-hook-mechanics.md` |
| `[ ] TAKE-HOME` | A `session-motd.sh` cheat-sheet (costs zero tokens) | your commands print at session start | `toolkit/scripts/session-motd.sh` |
| `[ ] TAKE-HOME` | A `prompt-router.sh` for your own keywords | a prompt with your keyword gets the routing line | `toolkit/scripts/prompt-router.sh` |
| `[ ] TAKE-HOME` | A status line: model, context bar, directory, topic | the bottom line shows `[####------] 43%` and you stop being surprised by compactions | `snippets/04-extras/`, `05-hook-mechanics.md` |

Both halves of the guard check are mandatory. Without the second one you can walk
away with a harness where the agent can edit nothing — and find out at home.

## 3. Memory — decisions that outlive the session

The block starts with a **ready-made** decisions base, so you can search before
you have written anything. Run the seed first: about half a minute on a warm
cache, and it prints each entry as it lands, so you can see it working. The
facilitator talks while it loads.

| | Item | How you know | Where |
|---|---|---|---|
| `[ ] SESSION` | `cp snippets/02-memory/.mcp.json .mcp.json`, restart (mem0 already sits in `my-harness/mem0/`) | ask "which mem0 tools do you have?" — all five | `02-memory.md` §1 |
| `[ ] SESSION` | Seed the base: `uv run --directory mem0 python seed.py` | it prints how many entries it wrote | `02-memory.md` §2 |
| `[ ] SESSION` | Ask about a seeded decision **in your own words**, without saying "search memory" | it goes to `search_memory` **on its own** and answers with an entry *and its reason* | `02-memory.md` §3 |
| `[ ] SESSION` | Seed 2–3 **real** decisions of your own, each with the *why* | every entry has `status` + `verified_at` + a reason | `02-memory.md` §4 |
| `[ ] SESSION` | Interrogate a **fresh** session about your own entry | it answers from memory, and you asked in different words than you stored | `02-memory.md` §5 |
| `[ ] SESSION` | Ask the base a question no single entry answers ("who can see a report?") | the answer **names the contradiction** between `RPT-127` and `SEC-88` and reasons from their dates, instead of quoting whichever scored higher | `02-memory.md` §5 |
| `[ ] TAKE-HOME` | Curate the fake Slack thread into 4–6 entries, then check yourself | you caught the decision that was narrowed later, and the "fact" that went false the same day | `02-memory-dump.md` → `-answers.md` |
| `[ ] TAKE-HOME` | Run a hygiene pass with `/memory-hygiene` | it names the contradiction, the missing reason, or the metadata gap that the seed contains on purpose | `toolkit/skills/memory-hygiene` |

Retrieval needs no wiring in this block: the inject hook you wrote in section 2
*is* the trigger. That is why hooks come first.

The contradiction question is the shortest exercise here and the whole argument
for metadata: you watch the model rank two "accepted" facts by their dates, and
you feel what a store without dates would have cost you.

## 4. Orchestration — where your rules stop reaching

Two runs of one task. Nothing to install: the guard from block 2 is the setup.

| | Item | How you know | Where |
|---|---|---|---|
| `[ ] SESSION` | Run A: subagent from `my-harness/` edits `sample-repo/.env.production` | **blocked** — it quotes your own block-1 guard back at you, file untouched | `03-agent-team.md` |
| `[ ] SESSION` | Run B: the same edit, launched from `sample-repo/` | **succeeds** — `grep RETRY_LIMIT` says 5; your hook never ran | `03-agent-team.md` |
| `[ ] SESSION` | Say out loud what differed between A and B | only the directory the process started in — not the agent type, not the file | `03-agent-team.md` |
| `[ ] SESSION` | Put it back: `sed -i '' 's/RETRY_LIMIT=5/RETRY_LIMIT=3/' sample-repo/.env.production` | `grep` says 3 again | `03-agent-team.md` |
| `[ ] TAKE-HOME` | Run a real handoff: plan turn → your approval → `--resume` to edit | your approval lands **before** the first edit, and the session keeps its context | `03-agent-team.md` |
| `[ ] TAKE-HOME` | Write one task package for a real handoff | it has Goal / Context / Steps / Acceptance / Out of scope | `snippets/03-orchestration/task-package.md` |
| `[ ] TAKE-HOME` | Install the idle-inbox gate before you rely on teams | a teammate stops going idle on undelivered messages | `toolkit/scripts/teammate-idle-inbox-gate.sh` |
| `[ ] TAKE-HOME` | Log teammate traffic | `logs/teammates.jsonl` grows during a run | `toolkit/scripts/log-teammate.sh` |

Agent Teams is experimental and the last two items only matter once you actually
use teammates — for parallel work **inside one repository**, which is what they
are for. Measured 2026-08-01 on CLI 2.1.220: a teammate inherits the lead's
working directory, so it is not a way to run an agent by another repo's rules.
The idle-inbox gate is not a nice-to-have: without it a teammate can go to sleep
holding an unread answer from you, and the run just stalls.

## 5. Tracing and papercuts — entirely take-home

We do not build this layer during the session; there is no time for it and it
needs nothing from me. Everything here is copy-and-wire, and it is the layer
you will thank yourself for in a month.

| | Item | How you know | Where |
|---|---|---|---|
| `[ ] TAKE-HOME` | Copy `log-delegation.sh` in and wire `PostToolUse` | delegate anything → a line appears in `logs/delegations.jsonl` | `04-tracing.md` §1 |
| `[ ] TAKE-HOME` | Copy `papercut.sh` in and record your first papercut | `cat logs/papercuts.jsonl` shows your line | `04-tracing.md` §2 |
| `[ ] TAKE-HOME` | Copy the two reader skills in (`/harness-stats`, `/papercuts`) | type `/papercuts` — it reports on the line you recorded | `04-tracing.md` §3 |
| `[ ] TAKE-HOME` | Add the papercut rule to your `CLAUDE.md` | your *agents* start logging friction, not just you | `04-tracing.md` §2 |
| `[ ] TAKE-HOME` | `logs/` in `.gitignore` | `git status` stays clean after a session | — |
| `[ ] TAKE-HOME` | A weekly habit: run `/papercuts` + `/harness-stats`, fix one thing | one hook or rule changed because a log told you to | `04-tracing.md` |

Start with the papercut rule in `CLAUDE.md` — it is the single
highest-leverage line in this whole checklist. Your agents hit far more
friction than you ever see; that rule is how they tell you.

---

## The minimum that makes it a harness

If the session runs short, or you get pulled away, do only these two:

1. **One hook that enforces something** — anything, however small. It is the
   difference between a chat and a system.
2. **Three decisions in memory, retrievable from a fresh session.** Without
   retrieval it is a database nobody queries.

Everything else on this list is an amplifier. Those two are the thing itself.

And one for the evening after: **record your first papercut.** It takes two
minutes, and the feedback loop either exists or it does not.
