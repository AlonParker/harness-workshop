"""Seed the decisions store with a ready-made base, so the memory block starts
with something to retrieve instead of an empty store.

Run from your harness directory:

    uv run --directory mem0 python seed.py

Idempotent: entries already present (matched on exact text) are skipped, so
running it twice does not duplicate anything.

Both the collection name AND the user id are hardcoded to match
snippets/02-memory/.mcp.json. Neither is read from the environment on purpose:
they live in .mcp.json, which configures the MCP *server* process — this script
is launched separately from a terminal and never sees that environment.

Get either one wrong and the failure is silent and identical: the seed writes
15 entries, the store reports 15 entries, and search_memory returns nothing.
Every mem0 read is filtered by user_id, so seeding as $USER while the server
searches as "me" hides the whole base behind a filter. That is not theoretical
— it is what happens if you let DEFAULT_USER fall back to $USER here.
"""

import json
import os
import sys
from pathlib import Path

# Both must match snippets/02-memory/.mcp.json. Change one and you must change
# the other, or you seed one store and search a different one.
COLLECTION = "my_harness_memory"
USER_ID = "me"

os.environ.setdefault("MEM0_COLLECTION", COLLECTION)
os.environ.setdefault("MEM0_USER_ID", USER_ID)

# Reuse the server's CONFIG rather than restating it: one definition of the
# stack means the seed cannot drift from what the MCP server reads. DEFAULT_USER
# is imported too, but only resolves correctly because MEM0_USER_ID is set above
# before server.py is imported.
sys.path.insert(0, str(Path(__file__).parent))
from server import CONFIG, DEFAULT_USER  # noqa: E402

from mem0 import Memory  # noqa: E402

SEED_FILE = Path(__file__).parent / "seed-decisions.json"


def say(msg: str) -> None:
    """Print immediately.

    stdout is not a tty under `uv run`, so Python block-buffers it: without an
    explicit flush every line below would sit in the buffer and appear all at
    once at the end — which is exactly what makes a 70-second seed look like a
    hang. Measured: ~10 s of imports and ~6 s of model loading happen before
    the first entry is even written.
    """
    print(msg, flush=True)


def main() -> int:
    entries = json.loads(SEED_FILE.read_text())

    say(f"collection: {CONFIG['vector_store']['config']['collection_name']}")
    say(f"importing torch and transformers (~10 s)...")
    say(f"loading the embedder (~6 s on a warm cache, longer on first run)...")
    memory = Memory.from_config(CONFIG)

    existing = memory.get_all(filters={"user_id": DEFAULT_USER}, top_k=1000)
    known = {m.get("memory", "").strip() for m in existing.get("results", [])}

    total = len(entries)
    written = skipped = 0
    for i, entry in enumerate(entries, 1):
        text = entry["text"].strip()
        if text in known:
            skipped += 1
            say(f"  [{i}/{total}] skip (already present)")
            continue
        # infer=False: stored verbatim, no LLM rewrites the text.
        memory.add(
            text,
            user_id=DEFAULT_USER,
            metadata=entry.get("metadata") or None,
            infer=False,
        )
        written += 1
        # The text itself is the only useful label here: these entries have no
        # id or title, and a bare counter tells you nothing about what landed.
        preview = text if len(text) <= 60 else text[:57] + "..."
        say(f"  [{i}/{total}] {preview}")

    say(f"seeded {written} entries, skipped {skipped} already present")
    say(f"store now holds {written + len(known)} entries")

    if written == 0 and skipped:
        say("nothing new — the store was already seeded")
    return 0


if __name__ == "__main__":
    sys.exit(main())
