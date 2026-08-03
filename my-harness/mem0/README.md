# The mem0 track: a real local memory store

**Required, and it must be done before the workshop day.** The memory block
runs on this store — there is no file-based fallback. The first install pulls
well over a gigabyte, so it is not something we can fix during the session.

Most of the time is waiting on downloads — start it and go do something else.

## What you get, and what it costs

Everything runs on your machine:

- **Qdrant** in podman — the vector store, `localhost:6333`
- **sentence-transformers** in-process — the embedder,
  `intfloat/multilingual-e5-small` (384 dims, handles Russian and English)
- **fastembed** in-process — the BM25 keyword encoder, `Qdrant/bm25`, which is
  what lets you retrieve by literal token and not just by meaning
- **an MCP server** (`server.py`) exposing five tools to Claude Code

**No API keys. Nothing leaves your machine.** No cloud account, no token to
paste, no telemetry — check `server.py` yourself, it is ~100 lines.

## How the pieces fit

```
  YOUR SESSION
  ┌──────────────────────────────────────────────────────────────┐
  │ Claude Code                                                  │
  └──────────────────────────────────────────────────────────────┘
        │  MCP (stdio, local pipe)
        v

  ON YOUR MACHINE (localhost only)
  ╔══════════════════════════════════════════════════════════════╗
  ║ server.py            "mem0-local", 5 MCP tools               ║
  ║   add_memory . search_memory . list_memories                 ║
  ║   update_memory . delete_memory                              ║
  ╚══════════════════════════════════════════════════════════════╝
        │                                    │
        │  text                              │  vector + filters
        v                                    v
  ┌──────────────────────────────────────────────────────────────┐
  │ EMBEDDER  (in-process)          │ BM25 ENCODER (in-process)  │
  │   sentence-transformers,        │   fastembed, Qdrant/bm25   │
  │   multilingual-e5-small         │   term weights + IDF       │
  │   + XLMRoberta tokenizer:       │   --> sparse vector        │
  │     250k vocab, 512 tok max     │                            │
  │   + 12-layer encoder            │   latin only: no terms     │
  │   --> vector[384]               │   from Cyrillic            │
  └──────────────────────────────────────────────────────────────┘
        │                                    │
        │  meaning                           │  literal tokens
        v                                    v
  ╔══════════════════════════════════════════════════════════════╗
  ║ QDRANT   (podman :6333)                                      ║
  ║   collection = your name                                     ║
  ║   vector[384] + sparse bm25 + payload                        ║
  ║   hybrid: cosine + BM25, merged into one score               ║
  ║   volume: survives restart                                   ║
  ╚══════════════════════════════════════════════════════════════╝

  (!) no LLM in this picture
  (!) no network egress
```

Read the write path once and the whole design follows:

```
  add_memory("we chose PushMate because ...")
      │
      ├─ tokenize   text --> 36 subword tokens
      │              (512 max, silently truncated beyond that)
      │
      ├─ encode     tokens --> vector[384]   (~10 ms, CPU)
      │
      ├─ BM25       text --> sparse vector   (fastembed)
      │              term weights, not meaning
      │
      └─ upsert     {vector[384] + sparse, payload: {text VERBATIM,
                                                     user_id, metadata}}
                    --> Qdrant
```

And the read path — note it runs BOTH searches and merges them:

```
  search_memory("which push provider?", limit=5)
      │
      ├─ same embedder --> query vector[384]
      ├─ same BM25     --> query sparse vector
      │
      ├─ Qdrant: cosine top_k, filtered by user_id      (meaning)
      ├─ Qdrant: BM25   top_k, same filter              (literal terms)
      │
      ├─ merge: (dense + bm25) / max_possible, keep top 5
      │
      └─ returns the stored TEXT (+ score)
                    --> into the model's context
```

**Why two searches and not just the vector.** A dense vector encodes *meaning*,
which is exactly wrong for identifiers: `AF-4278` and `AF-4249` sit almost on
top of each other in embedding space, so a dense-only search for one happily
returns the other. BM25 matches the literal token and, with IDF weighting, a
rare token like a ticket key dominates the score. Measured on a real store of
123 memories: dense-only put the right entry nowhere in the top 3 for the query
`AF-4278`; with BM25 it came first with a 10x margin over the runner-up.

The trap is that this fails *silently*. Drop `fastembed` and mem0 disables
keyword search with no error at all — retrieval still returns plausible results,
just the wrong ones for any literal lookup.

**What is deliberately missing is the interesting part.** A typical mem0 setup
puts an LLM in the write path to "extract facts" from your text. We pass
`infer=False`, so there is none: your text is stored byte-for-byte. The
embedder is not a language model — it cannot paraphrase, summarise or
hallucinate, it only turns text into 384 numbers for similarity search. That is
why the store can never contain a decision you did not write, and why
formulating the fact is *your* job.

Honest costs, so nothing surprises you:

|                                |                                         |
|--------------------------------|-----------------------------------------|
| First `uv sync`                | ~840 MB of packages, plus ~25 MB for fastembed/onnxruntime |
| First model load               | ~470 MB for the embedder, about a minute |
| First BM25 encode              | downloads the `Qdrant/bm25` model once, a few seconds |
| MCP handshake at session start | **~26 seconds**                         |
| RAM while a session is open    | ~150 MB Qdrant + ~500 MB embedder + ~100 MB BM25 encoder |

That 26-second handshake is what trips people up: the session looks frozen.
It is not. Do not kill it at second 20.

## Why a hand-written server instead of an off-the-shelf one

Vendor mem0 MCP wrappers are either archived or sunset, and the ones that
exist route embeddings through a paid API. This server is ~100 lines over the
mem0 OSS library, so "nothing leaves the machine" is something you can verify
by reading it rather than trusting it.

**Why `ollama` is in the dependencies when we never use Ollama.** Fair
question, and the answer is the opposite of what it looks like: that line is
what stops us from using a *cloud* LLM. mem0 always constructs an LLM
provider — omit the `llm` config section and it silently falls back to OpenAI
and refuses to start without `OPENAI_API_KEY`. Naming ollama avoids that, and
the `ollama` package is the import-time dependency that provider needs.

Nothing ever talks to Ollama: initialising the provider only builds an HTTP
client (no network call), and its send path is unreachable because every write
is `infer=False`. That is why the model is literally named `"unused"`. **Do
not install Ollama, and do not remove the dependency.**

Two more details are load-bearing and non-obvious — both work around silent
mem0 defaults:

- `search()` takes `top_k`, **not** `limit`. A `limit=` kwarg is swallowed by
  `**kwargs` and ignored, and you silently get 20 results.
- `get_all()` also defaults to `top_k=20`, silently truncating your store — a
  hygiene pass over "all memories" would quietly see only the first 20.
- `fastembed` must be installed or BM25 is off. mem0 catches the `ImportError`,
  logs a warning far below the tool layer, and carries on dense-only. There is
  no signal at the MCP tool level that half your retrieval is missing.

If you port this elsewhere, keep all three.

One consequence worth knowing before you write your first memory: **BM25
extracts no terms from Cyrillic.** Write your memories in one language and
query in that same language. A Russian query against an English store falls
back to dense-only and loses every literal match.

## Install

### 1. Prerequisites

```bash
python3 --version   # need >= 3.11
uv --version        # the runner that actually starts the server
podman --version
```

podman, not Docker — Docker Desktop is not allowed on corporate machines.

```bash
# macOS
brew install uv podman
# Debian/Ubuntu
sudo apt install podman && curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 2. Everything else, in one command

```bash
bash mem0/run.sh          # from my-harness/
```

It starts Qdrant, installs the Python side, and seeds the decisions base —
checking each step first, so a second run costs seconds instead of a gigabyte.
That matters because the usual failure here is a half-finished install: one step
timed out, you re-ran another by hand, and now you cannot tell which of them
actually took.

The rest of this section is what that script does, step by step, for when you
need to run a piece of it yourself.

### 2a. Qdrant

```bash
bash mem0/qdrant-up.sh
```

Idempotent — run it again any time, your memories survive. On macOS it also
initialises the podman VM on first use (a few minutes, once). Verify:

```bash
curl -s http://localhost:6333/readyz
```

Already have a Qdrant on 6333? Then you do not need the container at all —
point the server at the existing one and give yourself a separate collection:

```bash
QDRANT_PORT=6333 MEM0_COLLECTION=my_own_store   # in .mcp.json env
```

Collections are isolated, so this cannot touch anything already stored there.
To run a *second* Qdrant instead:
`QDRANT_PORT=6334 bash mem0/qdrant-up.sh`.

### 3. Install the Python side

```bash
uv sync --directory mem0
```

This is the big download (~840 MB of packages on the machine this was
measured on).

### 4. Register the server with Claude Code

```bash
cp ../snippets/02-memory/.mcp.json .mcp.json     # from my-harness/
```

The snippet needs no edits. `MEM0_COLLECTION` is already `my_harness_memory`,
which is what `seed.py` writes to — change one and you must change both, or you
will seed one collection and search another. And `--directory mem0` is relative
to the harness, which is where this directory already lives — that is what keeps
the harness self-contained enough to carry home.

Restart `claude`. The server appears as `mem0-local` with five tools:
`add_memory`, `search_memory`, `list_memories`, `update_memory`,
`delete_memory`.

### 5. Smoke test

In a Claude Code session:

1. "Use add_memory to store this: we chose PushMate over SendWave for push
   delivery because SendWave has no delivery receipts (NTF-482, 2026-06)."
   Name the tool — "store this in memory" could just as well land in Claude
   Code's own file-based memory, and you would never know from the reply.
2. Start a **fresh** session — memory that only works in the session that
   wrote it is not memory.
3. Ask: "which push provider did we pick, and why?"

If the answer comes back with the reason and the ticket, the loop is closed.

## Gotchas

- **Change the embedder, change the dimensions.** `MEM0_EMBEDDER_MODEL` and
  `MEM0_EMBEDDING_DIMS` must agree. Qdrant rejects every vector otherwise,
  and the error will not say "you changed the model".
- **Changing `MEM0_COLLECTION` starts an empty store.** The old collection is
  still there, just not the one you are reading. Handy for a clean slate,
  confusing if unintended.
- **Writes are verbatim** (`infer=False`) — no LLM extracts facts for you.
  Whatever text you hand `add_memory` is exactly what is stored, so write one
  atomic, self-contained fact per entry. This is a feature: no model
  paraphrases your decision into something you never decided. It also means
  hygiene is *your* job — see `handout/02-memory.md`.
- **Qdrant keeps running** after you close the terminal (`--restart=always`).
  Stop it with `podman stop workshop-qdrant`.
- **`WARNING Failed to load spaCy full model` on startup is expected.** spaCy
  is only used by mem0's LLM-based fact extraction, which this setup does not
  use (`infer=False` everywhere). Ignore it; do not install `mem0ai[nlp]`.

## During the workshop

You will seed a ready-made decisions base, wire retrieval through
your inject hook, seed real decisions with `add_memory`, and prove it works
from a fresh session. That is `handout/02-memory.md` — this file only gets the
plumbing up.
