---
name: papercuts
description: >
  Review the friction log (logs/papercuts.jsonl) — dead-end tool calls, stale
  docs, broken links, permission denials, routing gaps recorded by you and your
  agents. Aggregates by category and target, surfaces what repeats, and drafts
  harness fixes as proposals. Use when asked what friction has piled up or how
  to turn it into improvements.
---

# /papercuts — turn recorded friction into fixes

This is the reader for `papercut.sh`, and the half of the feedback loop that
actually closes it. Recording friction changes nothing until something reads it.

Input: `$ARGUMENTS` — optional period like `7d` or `30d` (default: everything).

Schema per line: `{ts, session_id, agent, category, target, note}`. Categories:
`tool-failure`, `stale-doc`, `broken-link`, `missing-permission`, `routing-gap`,
`env`, `other`.

## Algorithm

1. Read `logs/papercuts.jsonl` at the project root. If missing or empty, say
   that nothing has been recorded yet and stop.
2. If a period was given, filter by `ts` (ISO-8601 UTC).
3. Aggregate with `jq -s` and report:
   1. **By category:** counts, sorted. The shape of the distribution is the
      finding — a pile of `stale-doc` means your docs lie to your agents; a pile
      of `missing-permission` means your allowlist is too tight.
   2. **By agent:** who hits the most friction. An agent that suffers far more
      than the others usually has a wrong tool list or a wrong brief.
   3. **Recurring targets:** `target` values appearing more than once, and
      near-duplicate `note` texts. These are the primary fix candidates —
      something that tripped up several sessions is not bad luck.
   4. **Recent sample:** the last ~10 entries verbatim, so the raw texture is
      visible and not just counts.
4. For each recurring cluster, draft **one concrete fix as a proposal** — a
   CLAUDE.md rule, a correction to an agent's brief, a permission allowlist
   entry, a hook change, or a doc repair. Do not apply it.
5. Pick the single highest-value fix and say so. A review that proposes nine
   fixes gets none of them done.

## Reading the log honestly

- **Recency bias:** the log only knows what got recorded. Categories you never
  use look solved when they are actually invisible.
- **One entry is not a signal.** Fix what repeats; note the singletons and move
  on.
- If the log is empty after a week of real work, the problem is the rule in your
  CLAUDE.md, not the absence of friction. Agents record friction only when told
  to.

## Constraints

- Read-only: propose fixes, never apply them, and never edit the log.
- The log is local and gitignored. Never quote its contents into an external
  system (a ticket, a chat, a PR) — it holds notes about your own tooling and
  may name internal paths.
- Tolerate malformed lines: skip whatever `jq` cannot parse instead of failing.
