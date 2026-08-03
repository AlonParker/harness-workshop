# Decisions memory: build one in YOUR harness

Two kinds of memory that must not be mixed:

- **documentation memory** — a semantic index over docs ("where is X
  described");
- **decisions memory** — what the team decided and why. This is what you
  build now.

## The two halves, and why one is useless alone

```
  WRITE (rare, deliberate)          READ (every relevant turn)
  ════════════════════════          ══════════════════════════

  a decision gets made              you ask a question
        │                                 │
        v                                 v
  ┌───────────────────────┐         ┌───────────────────────────┐
  │ YOU formulate:        │         │ RETRIEVAL                 │
  │   the fact            │         │   the inject hook from    │
  │   the WHY             │         │   the hooks block         │
  │   status              │         │   "search_memory first"   │
  │   verified_at         │         │   on EVERY prompt         │
  └───────────────────────┘         └───────────────────────────┘
        │  add_memory                     │  search_memory
        v                                 v
  ╔═══════════════════════╗         ╔═══════════════════════════╗
  ║ mem0-local (MCP)      ║         ║ the SAME collection       ║
  ║   --> embedder        ║         ║   cosine + BM25, merged   ║
  ║   --> BM25 encoder    ║         ║   (meaning + exact terms) ║
  ║   --> Qdrant :6333    ║         ║   returns the stored text ║
  ║       your collection ║         ╚═══════════════════════════╝
  ║                       ║               │
  ║ text stored VERBATIM  ║               v
  ║ no LLM rewrites it    ║         answer cites YOUR entry,
  ║ (infer=False)         ║         not a guess
  ╚═══════════════════════╝

  (!) store without retrieval    = a database nobody queries
  (!) retrieval without curation = the agent confidently cites
                                   garbage
```

Both halves or nothing. Steps 1-2 below bring in the store and fill it; step 3
proves that retrieval already fires — you built that half in the hooks block,
which is why it came first.

## 1. Bring mem0 into your harness

You installed the stack before the workshop (`mem0/README.md`): Qdrant in
podman, a ~100-line MCP server, no API keys, nothing leaving your machine. It
already lives inside your harness at `my-harness/mem0/`, which is what keeps the
harness self-contained — the relative path in the config works unchanged, and
you can carry the whole directory home.

What is left is to point Claude at it. From `my-harness/`:

```bash
cp ../snippets/02-memory/.mcp.json .mcp.json
```

Read it before you restart: it is the file that tells Claude Code which local
process to launch, with which collection and which embedder. Then restart
`claude`.

**Verify:** ask "which mem0 tools do you have?" — it lists all five:
`add_memory`, `search_memory`, `list_memories`, `update_memory`,
`delete_memory`. If it lists none, the server did not start; fix that before
continuing, the rest of this block depends on it. (Give it ~26 seconds on
session start — that handshake is slow, not broken.)

The collection name is already set to `my_harness_memory` in the snippet. You do
not need to change it: your Qdrant is local, so there is nobody to collide with.
In a real harness you name the collection after the project, because one Qdrant
serves several stores — and mind the trap: renaming it *after* you have written
entries starts an empty collection, and the old one is still there, just
invisible.

## 2. Seed a ready-made base

```bash
uv run --directory mem0 python seed.py
```

**This takes about half a minute** once the embedder model is cached, and
longer the very first time, when it still has to be downloaded. Roughly 10 s of
that is importing torch, 6 s is loading the embedder, and the rest is writing
15 entries. It prints each entry as it lands, so you can watch it work — start
it and listen; the facilitator talks while it loads.

What you just loaded: fifteen decisions from a fictional **reports service**
team — how they hand large reports to users, what they rejected and why, which
conventions they adopted. Not your decisions. Somebody else's, so that you can
search a store before you have written anything into it.

**Verify:** the script prints how many entries it wrote. Run it again and it
writes 0 — it is idempotent, so a second run cannot duplicate anything.

## 3. Retrieve — and watch both halves work at once

Ask about one of those decisions **in your own words**, and **without** telling
it to search:

- "how do we hand large reports to users?"
- "why did we not go with headless Chrome?"
- "what are our retry rules?"

Two things get proven at the same time here:

- **the search is semantic.** None of those questions share the wording of the
  entries they find. This is what separates memory from grepping a file.
- **retrieval fired on its own.** You wired nothing for it in this block — it is
  the inject hook you wrote twenty minutes ago in `01-hooks.md`, arriving on
  every prompt whether the model remembers to search or not.

That is the whole reason the hooks block comes first. A rule in `CLAUDE.md`
asking for the same thing is a request the model can forget; the hook is not.

**Done when** the answer cites a specific entry *with its reason*, not a guess.

**Curious what else is in there?** `list_memories` returns the whole store. Ask
your questions first, though — otherwise the exercise in semantic search turns
into reading a table.

## 4. Add real entries of your own

Now the same thing, but yours. Write 2–3 **real** decisions from your team (a
chosen library, a rejected approach, a convention and its reason) via
`add_memory` — one atomic fact per call. Ask the agent, so you see what the tool
call looks like:

```
Use add_memory to store this: we hand reports over as S3 pre-signed URLs
rather than email attachments - mail gets cut off at 25 MB and reports run
to 300. Metadata: status: accepted, verified_at: <today>, topic: reports.
```

**Name the tool.** "Store this in memory" is ambiguous: Claude Code may have a
file-based memory of its own, and the sentence reads just as well as an
instruction to write there. You would see "saved", and mem0 would stay empty —
the same silent success this whole block is teaching you to distrust. Say
`add_memory` and there is nothing to guess.

**Expect it to answer "that is already stored".** That example is deliberately
one of the fifteen seeded decisions, so a well-behaved agent searches before it
writes, finds `RPT-207`, and declines to add a duplicate. That is the correct
outcome and worth seeing once: the store does not grow to sixteen, and nothing
was lost. Deduplication runs at two levels here — `seed.py` matches on exact
text, and the agent matches on meaning, which is the one that catches the same
decision written in different words. Then run it again with a decision of your
*own* and watch a new entry actually land.

The shape worth copying:

| Part | Example |
|---|---|
| the fact | "reports go out as S3 pre-signed URLs, not attachments" |
| **the why** | "mail gets cut off at 25 MB, reports run to 300" |
| `status` | `accepted` |
| `verified_at` | today's date |
| `topic` | one word, for filtering |

Two rules that matter more than they look:

- **The `text` is stored verbatim.** No LLM rewrites it (`infer=False`), so
  whatever you type is what future sessions read. Write it self-contained —
  it will be retrieved without any surrounding context.
- **The *why* is not optional.** An entry without a reason is a rule nobody
  can ever re-evaluate.

**Write down a question for one of your *own* entries** — phrased in *different
words* than the entry itself. You will ask it in the next step, and it has to
target something you wrote: the seeded example would answer from `RPT-207` and
prove nothing about your own writing. If your entry is about a library you
picked, ask "what do we render with?" — none of the words you stored.

## 5. Interrogate a fresh session

Restart `claude` — fresh context, no chat history — and ask your own question
from step 4, in your own words.

**Done when** the answer cites your entry *with its reason*. If you happened to
ask using the same words you stored, ask again differently — that would be a
substring check, not a semantic one, and the whole point is the latter.

Then ask the question this whole seeded base exists for:

```
What are the rules about who can see a report?
```

That question matches **no single entry**. The search returns five, two of which
say opposite things:

| Entry | `verified_at` | Says |
|---|---|---|
| `RPT-127` | 2026-04-09 | account admins can read every report in their account |
| `SEC-88` | 2026-06-18 | strictly per-user; nobody, admins included, reads another's |

Both are stored with `status: accepted` — nobody went back to mark the old one
when the security review overruled it. So the model gets two contradictory
facts, and the answer worth having is not a quote from whichever scored higher.

**Done when** the answer *names the contradiction* and reasons about it — most
plausibly that `SEC-88` is two months newer and cites a security review, so it
supersedes `RPT-127`. That is the difference between a store that returns
fragments and one that supports a decision: no single entry contains that
conclusion, it only exists across several.

Two things follow, and the second is the uncomfortable one:

- **Retrieval is not the whole job.** Five entries came back; four of them are
  context, not the answer. Something has to weigh them, and that something is
  the model reading metadata you bothered to write.
- **This works by luck, not by rule.** The dates were in the store, so the model
  *could* rank them. Nothing forced it to look. Mark the loser `status:
  superseded` and the signal becomes explicit — but even then it is a signal,
  not a guarantee. To make it a rule you need one more line in `CLAUDE.md` or in
  your inject hook: "never cite entries with `status: superseded` as current".
  Which is exactly why rules sit on top of a store, and why hooks came first.

If your run answers with only one of the two and never mentions the other, that
is worth seeing too: ask "is there anything in memory that contradicts this?"
and watch the second entry appear. Retrieval had it all along.

## Hygiene rules (paid for in production)

- Record only **accepted** decisions and **verified** findings — not
  drafts, not chat noise, not anything derivable from the code itself.
- Metadata is mandatory: `verified_at`, status.
- Memory reflects the moment of writing — before relying on a fact,
  check it is still alive.
- A hallucination written into memory is worse than no memory: the agent
  cites it as fact forever after.
- Keep the store curated, not append-only: a periodic watchdog pass
  (dedupe, flag stale entries) is a real production pattern — a morning
  hook dispatches it.

## Keeping it clean

A store you stopped trusting is worse than no store: the agent cites it as fact
and stops saying "I am guessing". `toolkit/skills/memory-hygiene` is the periodic pass —
it lists the store, finds duplicates, entries with no reason, facts that have
gone stale, and outright contradictions, then proposes fixes without applying
them.

Copy it the same way as the others (`toolkit/skills/README.md`) and run it when you
notice you have stopped believing an answer.

## Take-home practice: the dump

`02-memory-dump.md` is three days of a messy fake team Slack — a **different**
team from the one whose decisions you seeded: the seed is a reports service, the
dump is a notification service. The topics are kept apart on purpose, so the
answers to this exercise are not already sitting in your store.

Curating it into 4–6 entries trains the muscle this block is really about —
deciding what *not* to remember — on material where you have no prior knowledge
to lean on.

It is built around four traps, including a decision that gets narrowed two
days after it was announced and a "fact" that becomes false three hours
after someone states it. Compare your result with
`02-memory-dump-answers.md` **after** you have done it.
