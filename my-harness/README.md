# This is your harness

Not a practice folder. This directory is the thing you are building today, and
the thing you take home at the end of the day.

Right now it is nearly empty on purpose: a `CLAUDE.md` with a heading and a
`settings.json` holding exactly `{}`. Everything else you bring in yourself.

**Run `claude` from here**, not from the repo root. The hooks you are about to
add resolve paths relative to this directory.

## What it will do by the end

Three features, built in this order — the order matters:

| Block | What it adds | Why it comes when it does |
|---|---|---|
| **Hooks** | rules the runtime enforces, not rules the model may forget | everything else needs them |
| **Memory** | decisions that outlive the session, retrieved automatically | the retrieval trigger IS a hook from block 1 |
| **Orchestration** | agents working in other repositories, by those repos' rules | pointless if your rules get forgotten |

Where the pieces come from: the `snippets/` directory next to this one, split
into `01-hooks/`, `02-memory/`, `03-orchestration/`. You copy from there into
here. Nothing is typed from scratch — a typo in JSON costs you the block.

## Block 1 — hooks

Copy the fragments **one at a time** and check each before moving on. The JSON
files are *pieces* of the `hooks` section, not whole files: merge them into your
`settings.json`.

```bash
# 1. sound when a turn ends, and a different one when the agent needs you
#    copy ../snippets/01-hooks/01-stop-sound.json into settings.json
#    then ../snippets/01-hooks/02-notification-sound.json
```

> **Check.** Ask anything. Do you hear a sound when the answer lands? Silence:
> did you restart `claude`? Is the JSON valid (`jq . .claude/settings.json`)?
> And are the two sounds *different* — otherwise you cannot tell "done" from
> "waiting for you", and the second one is the one that saves time.

```bash
# 2. a line appended to every prompt you send
cp ../snippets/01-hooks/inject-reminder.sh .claude/hooks/
chmod +x .claude/hooks/inject-reminder.sh
#    copy ../snippets/01-hooks/03-userpromptsubmit.json into settings.json
#    restart claude
```

> **Check.** Ask "what extra instructions came with my prompt?" — the agent
> quotes your line back. It does not: `chmod +x` done? `claude` restarted?
> `bash .claude/hooks/inject-reminder.sh` prints the line?

**Do not reword that line.** In the next block it becomes the retrieval trigger
for your memory, verbatim.

```bash
# 3. a guard that blocks reads AND edits of the .env family
cp ../snippets/01-hooks/guard-env.sh .claude/hooks/
chmod +x .claude/hooks/guard-env.sh
#    copy ../snippets/01-hooks/04-pretooluse.json into settings.json
#    restart claude
```

The file it protects is `.env.production`, which ships here with a live-looking
secret in it.

Open `guard-env.sh` and read it — it is the most interesting of the three.
The tool call arrives as JSON on stdin; the decision is JSON printed to stdout;
and `permissionDecisionReason` goes back to the model. That last part is the
point: a guard that only says "no" leaves the agent stuck, a guard that names
the way forward is one you keep. Note also that it matches the *basename*
against an explicit list rather than a broad `*.env.*`: overlapping patterns
would make the rule depend on which branch comes first, and that is the kind of
guard you break the day you extend it.

> **Check all three.** Ask the agent to change `RETRY_LIMIT` in
> `.env.production` → refused, with the reason from the hook. Ask it **what the
> API key is** → also refused, which is why `Read` is in the matcher: a secret
> in the context window leaks into summaries and diffs. Then ask it to add a line
> to `CLAUDE.md` → works. **Do not skip the last one**: without it you may walk
> away with a harness where the agent can edit nothing.

## Block 2 — memory

```bash
cp ../snippets/02-memory/.mcp.json .mcp.json
#    restart claude - the handshake takes ~26 seconds, that is normal
```

The mem0 infrastructure already sits inside the harness at `mem0/`, which is
what keeps it self-contained and makes the relative path in the config work
unchanged. If the store is not up yet, `bash mem0/run.sh` brings up every piece
it needs and skips whatever is already done.

> **Check.** Ask "which mem0 tools do you have?" — all five: `add_memory`,
> `search_memory`, `list_memories`, `update_memory`, `delete_memory`. None: the
> server did not start — is Qdrant up (`curl -s localhost:6333/readyz`)?

```bash
# seed a ready-made decisions base (a fictional notify-svc team)
uv run --directory mem0 python seed.py
```

> **Check.** The script prints how many entries it wrote.

Now ask about one of those decisions **in your own words**, and **without**
saying "search your memory":

- "what do we send push through?"
- "why didn't we take SendWave?"
- "what are our retry rules?"

> **Check.** The agent went to `search_memory` **on its own** and answered with a
> specific entry *and its reason*. Two things just got proven: the search is
> semantic (none of those questions share words with the entries), and retrieval
> fires by itself — because the inject hook from block 1 is already in place.
> You wired nothing for this.

Then add 2–3 **real** decisions of your own via `add_memory` — one atomic fact
per call, with `status`, `verified_at`, `topic`, and above all **the reason**.
An entry without a why is a rule nobody can ever re-evaluate. Restart, ask in
your own words, and watch a fresh session answer from your entry.

Last, ask the seeded base something no single entry answers: **"what are the
rules about who can see a report?"** Five entries come back and two of them
contradict each other — `RPT-127` says account admins can read every report,
`SEC-88` says strictly per-user. Both are marked `accepted`; only their dates
say which one won. Done when the answer names that conflict and reasons from
the dates instead of quoting whichever scored higher. That conclusion exists in
no entry — only across several, which is the difference between a store that
returns fragments and one you can decide from.

## Block 3 — orchestration

```bash
cp -r ../snippets/03-orchestration/run-elsewhere .claude/skills/
#    restart claude
```

One task, asked two ways from **this same session** — no second window, no
terminal. The guard from block 1 is the rest of the setup.

Ask your agent, in plain words:

> Spawn a subagent and tell it to change RETRY_LIMIT from 3 to 5 in
> `<abs-path>/sample-repo/.env.production`. Report whether it succeeded, and
> quote any denial.

> **Check.** Blocked — the agent quotes your own guard back at you, and the file
> is untouched. Your rule reached the subagent because the *session* is yours,
> even though the file lives in another repository.

Now the same task, through the skill:

```
/run-elsewhere ../sample-repo change RETRY_LIMIT from 3 to 5 in .env.production
```

> **Check.** It goes straight through, and the skill says so: the session ran in
> `sample-repo` and your hook never loaded. Put it back with
> `sed -i '' 's/RETRY_LIMIT=5/RETRY_LIMIT=3/' ../sample-repo/.env.production`.

Same file, same task, same session you are sitting in. What differed is the
directory the *second* process started in. A guard is a rule about **a session**,
not about a file on disk — which is also why `/run-elsewhere` is how you hand
work to a repo whose rules should govern it, and why it can never be a safety
net for the rest of your disk.

## Where the rest is written down

- `../handout/CHECKLIST.md` — every layer, marked session vs take-home
- `../handout/01-hooks.md`, `../handout/02-memory.md`,
  `../handout/03-agent-team.md` — the long version of each block
- `../handout/04-tracing.md` — the layer nobody builds first and everybody
  misses a month later

## Taking it with you

Want to keep building on this after today:

```bash
cp -r my-harness ~/my-harness && cd ~/my-harness && git init
```
