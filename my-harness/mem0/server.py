"""Thin local MCP server over the mem0 OSS library.

Fully local stack:
- vector store: Qdrant in podman (localhost:6333)
- embeddings:   sentence-transformers, in-process (multilingual)

No LLM anywhere in the write path: memories are stored verbatim
(infer=False) — the calling agent is responsible for formulating atomic
facts and deduplicating via search_memory first. No memory content ever
leaves the machine, and no API key is involved anywhere in this file.

This is the production server from a real harness, with one line changed:
the collection name is read from the environment so you can namespace your
own store. See README.md.
"""

import os

from mcp.server.fastmcp import FastMCP
from mem0 import Memory

DEFAULT_USER = os.environ.get("MEM0_USER_ID", os.environ.get("USER", "user"))

CONFIG = {
    # This section is what keeps the stack local. mem0 always constructs an LLM
    # provider; drop this block and it defaults to OpenAI and refuses to start
    # without OPENAI_API_KEY. Naming ollama avoids that.
    #
    # Ollama itself is never contacted: init only builds an httpx client, and
    # the send path is unreachable because every write below is infer=False.
    # Hence model "unused" — it is never resolved. Do NOT install Ollama.
    "llm": {
        "provider": "ollama",
        "config": {
            "model": "unused",
            "ollama_base_url": "http://localhost:11434",
        },
    },
    "embedder": {
        "provider": "huggingface",
        "config": {
            "model": os.environ.get("MEM0_EMBEDDER_MODEL", "intfloat/multilingual-e5-small"),
        },
    },
    "vector_store": {
        "provider": "qdrant",
        "config": {
            "host": os.environ.get("QDRANT_HOST", "localhost"),
            "port": int(os.environ.get("QDRANT_PORT", "6333")),
            # Namespace your own store. Changing this after you have written
            # memories starts an empty collection — the old one is still there.
            "collection_name": os.environ.get("MEM0_COLLECTION", "workshop_memory"),
            # Must match the embedder above. multilingual-e5-small is 384-dim;
            # swap the model and Qdrant will reject every vector until you fix
            # this number too.
            "embedding_model_dims": int(os.environ.get("MEM0_EMBEDDING_DIMS", "384")),
        },
    },
}

mcp = FastMCP("mem0-local")
memory = Memory.from_config(CONFIG)


@mcp.tool()
def add_memory(text: str, metadata: dict | None = None, user_id: str = DEFAULT_USER) -> dict:
    """Store a memory verbatim (no LLM extraction — the text is saved as-is).
    Formulate an atomic, self-contained fact and search_memory for duplicates
    first. metadata is a flat dict of filterable fields; a useful convention
    is: repo, topic, date, source, verified_at."""
    return memory.add(text, user_id=user_id, metadata=metadata, infer=False)


@mcp.tool()
def search_memory(query: str, user_id: str = DEFAULT_USER, limit: int = 5) -> dict:
    """Semantic search over stored memories. Returns the most relevant entries.

    Phrase the query in the language your memories are written in. Retrieval is
    hybrid (dense e5-small + BM25) and the BM25 encoder extracts no terms from
    Cyrillic, so a Russian query against an English store quietly falls back to
    dense-only — and with it goes the ability to match literal tokens like
    ticket keys, symbol names or table names."""
    # mem0's search() takes top_k, not limit; a `limit=` kwarg is silently
    # swallowed by **kwargs and ignored (defaulting to top_k=20). Map explicitly.
    return memory.search(query, filters={"user_id": user_id}, top_k=limit)


@mcp.tool()
def list_memories(user_id: str = DEFAULT_USER, limit: int = 1000) -> dict:
    """List all stored memories for the user."""
    # get_all() defaults to top_k=20, silently truncating the store; pass a high
    # explicit top_k so hygiene passes see the whole store.
    return memory.get_all(filters={"user_id": user_id}, top_k=limit)


@mcp.tool()
def update_memory(memory_id: str, text: str) -> dict:
    """Replace the text of an existing memory by its id."""
    return memory.update(memory_id, text)


@mcp.tool()
def delete_memory(memory_id: str) -> dict:
    """Delete a single memory by its id."""
    memory.delete(memory_id)
    return {"deleted": memory_id}


if __name__ == "__main__":
    mcp.run()
