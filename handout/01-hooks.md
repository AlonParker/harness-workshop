# Hooks: wire three into YOUR harness

A hook is a shell command the Claude Code runtime executes at a fixed
lifecycle point. A rule in CLAUDE.md is a *request* the model may forget;
a hook is *law* — the runtime runs it, the model can't skip it.

You wire all three into `my-harness/`, copying ready fragments from
`snippets/01-hooks/` — **one at a time**, checking each before the next. Nothing
is typed from scratch: a typo in JSON costs you the block, and typing teaches
nothing. What you do instead is *read* each fragment, which takes half a minute
per script.

## Where hooks sit in one turn

```
  you type a prompt
        │
        v
  ╔════════════════════════════════════════════════════════════╗
  ║ UserPromptSubmit                                           ║
  ║   (2) inject.  Runs every single turn.                     ║
  ║   stdout is APPENDED to your prompt                        ║
  ╚════════════════════════════════════════════════════════════╝
        │
        v
  ┌────────────────────────────────────────────────────────────┐
  │ MODEL  thinks, decides to call a tool                      │
  └────────────────────────────────────────────────────────────┘
        │
        v
  ╔════════════════════════════════════════════════════════════╗
  ║ PreToolUse                                                 ║
  ║   (3) guard.  Can ALLOW / DENY / rewrite.                  ║
  ║   sees the tool + its arguments as JSON on stdin           ║
  ║   exit 2 + stderr = blocked, and the stderr text           ║
  ║   goes back to the model                                   ║
  ╚════════════════════════════════════════════════════════════╝
        │
        ├── DENY: exit 2 -- the tool never runs,
        │         stderr goes to the model, which retries
        │
        │   ALLOW:
        v
  ┌────────────────────────────────────────────────────────────┐
  │ TOOL   Edit / Bash / Task / ...                            │
  └────────────────────────────────────────────────────────────┘
        │
        v
  ╔════════════════════════════════════════════════════════════╗
  ║ PostToolUse                                                ║
  ║   logging (see 04-tracing.md)                              ║
  ╚════════════════════════════════════════════════════════════╝
        │
        │   (both paths rejoin here: blocked or done,
        │    control returns to the model)
        v
  ┌────────────────────────────────────────────────────────────┐
  │ MODEL  writes the answer                                   │
  └────────────────────────────────────────────────────────────┘
        │
        v
  ╔════════════════════════════════════════════════════════════╗
  ║ Stop                                                       ║
  ║   (1) sound.  Turn finished.                               ║
  ╚════════════════════════════════════════════════════════════╝

  Also useful: SessionStart (before your first prompt -- inject
  context or print a cheat-sheet) and Notification (the agent
  needs your input).
```

The numbers (1)(2)(3) are the three exercises below. Note the asymmetry: inject
only *adds text*, guard can *stop the machine*. That is the whole spectrum
of hook power, and you build both ends of it.

## 0. Wiring

Hooks are declared in `.claude/settings.json` of your project, which starts as
`{}`. The four JSON files in `snippets/01-hooks/` are *pieces* of the `hooks`
section, not whole files.

**Add them ONE AT A TIME, and check each before the next.** This is not
politeness about pacing: when three new hooks land together and something is
wrong, you cannot tell which one — and the failure is usually silent (a hook that
errors is simply skipped). One at a time, every check has exactly one suspect.

After the first snippet your `settings.json` looks like this and nothing else:

```json
{
  "hooks": {
    "Stop": [
      {"hooks": [{"type": "command",
                  "command": "afplay /System/Library/Sounds/Glass.aiff",
                  "async": true}]}
    ]
  }
}
```

Then you verify it, then you merge the next one *into* that object — a new key
under `"hooks"`, keeping what is already there. The exercises below go in order,
each with its own check. What the file looks like once all four are in is at the
end of this page; do not skip ahead and paste it.

Scripts go to `.claude/hooks/`, `chmod +x` them. Restart `claude` after
changing settings — forgetting the restart, and forgetting `chmod +x`, are the
two failures that cost people the most time here.

## 1. Sound on Stop (2 min)

Copy `snippets/01-hooks/01-stop-sound.json` into your `.claude/settings.json` —
it is the shortest hook that exists: no script, just a command. The `Stop` event
fires when the agent finishes a turn.

Then copy `02-notification-sound.json` **as a separate step**. `Notification`
fires when the agent needs your input, and it carries a *different* sound on
purpose: `Stop` says "done", `Notification` says "I am waiting for you". The
second one is what actually saves you time.

The command is plain `afplay` with a macOS system sound. No `paplay` fallback, no
terminal bell — everyone here is on a Mac, and two extra `||` branches only make
a two-line hook harder to read.

**Verify:** ask anything; when the answer lands, you hear it. And check the two
sounds are *different* — otherwise you cannot tell the two events apart. Silence:
did you restart `claude`? Is the JSON still valid (`jq . .claude/settings.json`)?
Does `afplay /System/Library/Sounds/Glass.aiff` make a noise on its own?

## 2. Inject: a line in every prompt (5 min)

`UserPromptSubmit`: whatever the script prints to stdout is appended to every
prompt you send.

```bash
cp ../snippets/01-hooks/inject-reminder.sh .claude/hooks/
chmod +x .claude/hooks/inject-reminder.sh
```

plus `snippets/01-hooks/03-userpromptsubmit.json` into `settings.json`, then
restart `claude`. Open `snippets/01-hooks/inject-reminder.sh` — it is three lines
(a shebang, one `echo`, `exit 0`), and worth reading so you can see there is no
magic in it: whatever reaches stdout is appended to your prompt.

**Verify:** ask "what extra instructions came with my prompt?" — the agent quotes
your line back.

**Do not reword that line.** In the next block this hook becomes the retrieval
trigger for your decisions memory, verbatim. A `CLAUDE.md` rule asking for the
same thing is a request the model can forget; this line arrives on every single
turn whether it remembers or not. Want it in your own words — do that *after* the
memory block, not before.

## 3. Guard: block edits to a protected file (6 min)

`PreToolUse` with matcher `Read|Edit|Write`: the tool call arrives as JSON on
stdin, and printing a deny decision blocks it.

```bash
cp ../snippets/01-hooks/guard-env.sh .claude/hooks/
chmod +x .claude/hooks/guard-env.sh
```

plus `snippets/01-hooks/04-pretooluse.json` into `settings.json`, then restart.

The protected file is **`.env.production`**, which ships in your harness with a
live-looking secret in it. Credentials are the right thing to practise on: a
rewritten `settings.json` you restore from git, but a secret the agent
overwrites is gone, and one it copies into a diff is worse than gone. It works as
shipped; nothing to fill in.

**Open `snippets/01-hooks/guard-env.sh` and read it properly** — it is the most
interesting of the three, and three things are visible right in the code:

- the tool call arrives as **JSON on stdin**, hence `jq -r
  '.tool_input.file_path'`. The agent does not "announce" an intention; the hook
  reads the actual arguments.
- the decision is **JSON printed to stdout** with `permissionDecision: deny`.
- `permissionDecisionReason` **goes back to the model** — and that text decides
  whether it understands what to do next or just gets stuck.

That last point is the lesson: this guard does not merely say "no", it names the
sanctioned path ("tell me which key you need and what for"). A guard with no way
forward leaves the agent stuck and you annoyed; a guard that redirects is the one
you still have in a month. Watch for it in the run: a blocked agent typically
comes back naming the key it wanted and why, which is exactly the hand-off the
reason asked for.

**Why an explicit list and not `*.env.*`.** The short pattern would be one line,
but it also matches the template files people keep beside their secrets
(`.env.example`, `.env.sample`) — committed placeholders that an agent *should*
be free to edit. Carving them back out needs a second branch placed *above* the
first, and the rule is then only correct as long as nobody reorders the two. A
guard whose correctness depends on line order is one you break the day you extend
it. Matching the **basename** against a list that names exactly what is protected
has neither problem: the branches do
not overlap, and adding `.env.test` tomorrow cannot silently unprotect anything.

**Verify all three — the last one is not optional.**

1. Ask the agent to change `RETRY_LIMIT` in `.env.production` → refused, with the
   reason from the hook.
2. Ask it **"what is the API key in `.env.production`?"** → also refused. This is
   why `Read` is in the matcher: a secret pulled into the context window can end
   up in a summary, a log line, or a diff. For a credentials file, "look but
   don't touch" protects nothing. Ask in words — an `@.env.production` reference
   bypasses the hook entirely, for the reason in the box below.
3. Ask it to add a line to `CLAUDE.md` → **works**. Skip this one and you may
   walk away with a harness where the agent can edit nothing, and find out at
   home.

**The other path to the same bytes, and why the matcher stops here.** A file
tool announces its target in one field, so `Read|Edit|Write` is exact. `Bash`
is not: `cat .env.production` reaches the same bytes, and the filename is buried
in a command string with no field to read. Adding `Bash` to the matcher means
parsing shell — and the parse has to be blunt, because enumerating readers
(`cat`, `less`, `grep`, `source`, a redirect, `$(...)`) leaves the one you forgot
as a bypass.

Blunt is where it bites back. Match on the mere *mention* of a protected name
and you also block `cd other-repo && claude -p 'fix RETRY_LIMIT in
.env.production'` — a handoff that opens no file here at all, and the exact
command block 4 of this workshop is built on. That was measured, not imagined:
an earlier version of this guard shipped with a `Bash` branch and silently broke
the orchestration block. Carving `claude -p` back out then means special-casing
quotes and flag order, which is a shell parser you now maintain.

So the matcher stays at three tools, and the honest consequence is stated rather
than hidden: **`cat .env.production` walks straight past this guard.**

> **A guard is not a sandbox, and `PreToolUse` is not the only way in.** Test it
> with a sentence ("what is the API key in `.env.production`?"), *not* with an
> `@.env.production` reference. An `@`-mention is expanded by the CLI while it
> assembles your prompt — no tool call happens, so `PreToolUse` never fires and
> the file lands in context regardless of this hook. That is not your hook
> failing; it is a different event. Same for `Bash`, and for anything else
> reaching the file outside a matched tool call. Guards encode intent for an
> agent that cooperates; they are not a security boundary against one that does
> not, and they cannot police what you paste in yourself.

**Going further (optional):** add a second `case` branch for a file in your *own*
project — the one agents must never touch. That question has a different answer
for everyone, which is why it is not shipped pre-filled.

## What the finished file looks like

Only for comparing against what you built, once all four snippets are in and each
one checked out. If your file matches this, block 1 is done:

```json
{
  "hooks": {
    "Stop": [
      {"hooks": [{"type": "command",
                  "command": "afplay /System/Library/Sounds/Glass.aiff",
                  "async": true}]}
    ],
    "Notification": [
      {"hooks": [{"type": "command",
                  "command": "afplay /System/Library/Sounds/Funk.aiff",
                  "async": true}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command",
                  "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/inject-reminder.sh\""}]}
    ],
    "PreToolUse": [
      {"matcher": "Read|Edit|Write",
       "hooks": [{"type": "command",
                  "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/guard-env.sh\""}]}
    ]
  }
}
```

## Where this scales (production examples you saw in the demo)

- Inject → a prompt router adding routing instructions to every prompt.
- Guard → a preflight gate that blocks delegating work into a repo with
  uncommitted changes.
- Same PreToolUse event, soft mode: don't block `grep`, suggest a better
  tool (a code-graph query) instead.
- PostToolUse logger → JSONL → observability over the whole harness
  (see `04-tracing.md`).
- Rewrite: the agent types `git status`, the machine runs
  `rtk git status` — a transparent token-saving proxy.

Docs: hooks reference and guide — see `resources.md`.
