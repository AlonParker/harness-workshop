# Pre-workshop setup (do this 2–3 days before)

Environment problems are not fixable during the workshop — the schedule has
no slack. Complete these four steps and send a screenshot of the green
check to the facilitator.

## 1. Install Claude Code

Follow the internal onboarding doc, or:

```bash
npm install -g @anthropic-ai/claude-code
claude --version
```

The finale uses the experimental Agent Teams feature, which needs Claude
Code **2.1.178 or newer** — if you installed it a while ago, update.
`setup/check.sh` verifies the version for you.

Log in once (`claude` → follow the prompt) and make sure you can get a
reply from the model.

You also need `jq` and `python3` — the exercises use both. macOS:
`brew install jq` (python3 ships with the Xcode tools). Debian/Ubuntu:
`sudo apt install jq python3`.

## 2. Clone this repository

```bash
git clone <repo-url> harness-workshop
cd harness-workshop
```

Read `handout/CHECKLIST.md` first — it is the map of everything we build,
and it marks honestly what we do together on the day and what you take
home. Nobody finishes all of it during the session; that is the design,
not a failure.

## 3. Run the environment check

```bash
bash setup/check.sh
```

Everything must be green. If anything is red, fix it or ping the
facilitator **before** the workshop day.

## 4. Install the memory store (mem0 + Qdrant) — REQUIRED

**This one is not optional, and it is the step most likely to bite you.**
A third of the workshop is the memory block, and it runs on a real local
vector store. There is no file-based fallback: if this is not installed,
you sit out that block.

What it needs:

- `podman` for the Qdrant container. Not Docker — Docker is not allowed on
  corporate machines here.
- `uv`, which runs the MCP server.
- A first-time download. Measured on one machine: **~840 MB** of Python
  packages plus **~470 MB** for the embedding model. Your numbers will
  differ; the order of magnitude will not.

Over a gigabyte of downloads is not something a live session recovers from.
**Do it at least a day ahead**, and send the green check.

Follow `my-harness/mem0/README.md` end to end, including the smoke test at the
bottom. Then re-run `bash setup/check.sh` — it verifies all five pieces
(podman, uv, Qdrant on :6333, the python env, and `.mcp.json`).

Nothing leaves your machine: no API keys are involved anywhere in that
setup, and you can verify that by reading the ~100-line server.

## What you need on the day

- Your laptop with the green check.
- A pair partner (we work in pairs).
- Basic bash. No domain-specific knowledge required.
