---
name: memory-hygiene
description: >
  Review the decisions memory in mem0 and keep it trustworthy: find duplicates,
  entries missing a reason or metadata, and facts that have gone stale. Proposes
  merges and supersessions. Use when asked to clean up memory, check what is in
  the store, or before relying on it for something important.
---

# /memory-hygiene — keep the store worth trusting

A curated store beats a large one. This skill is the periodic pass that keeps
memory from rotting into a pile of half-true statements.

The failure mode it prevents is specific: a store that has quietly gone wrong is
worse than no store at all, because the agent cites it as fact and stops
guessing out loud.

Input: `$ARGUMENTS` — optional topic to narrow the review (default: everything).

## Algorithm

1. `list_memories` (it returns the whole store, not a page). If it is empty, say
   so and stop.
2. Report the size and the metadata coverage first: how many entries have
   `status`, how many have `verified_at`, how many have neither. Coverage is the
   headline number — entries without metadata cannot be audited later.
3. Find the four problems, each as a list of specific entries:
   1. **Duplicates and near-duplicates.** Run `search_memory` with each entry's
      own text; entries that retrieve each other with high similarity are
      candidates to merge. Propose which one survives and what the merged text
      should say.
   2. **Missing the why.** Entries that state a decision without its reason.
      These are unrevisable: nobody can tell later whether the reason still
      holds. Flag each one and, where the reason is recoverable from context,
      propose the improved text.
   3. **Stale by age.** Entries whose `verified_at` is old *and* whose subject
      is the kind of thing that changes (versions, pricing, ownership,
      deadlines, "currently we use X"). Age alone is not staleness — a design
      rationale from a year ago may be perfectly current. Judge by subject, not
      only by date.
   4. **Contradictions.** Two entries that cannot both be true. This is the most
      valuable find and the reason to run this at all: a contradiction means the
      agent's answer depends on which entry the search happens to return.
4. Propose fixes explicitly, per entry, and **do not apply them without
   confirmation**:
   - `update_memory` to add `status: superseded` — the correct move for an
     outdated fact. Keep the old entry; the history is the point.
   - `update_memory` to add the missing reason or metadata.
   - `delete_memory` **only** for genuine duplicates and for entries that were
     never decisions at all (status reports, transient facts). Deleting a real
     decision because it is old destroys the record of why things are the way
     they are.
5. Finish with the one-line verdict: is this store currently trustworthy for
   answering questions about past decisions, and if not, which entry is the
   biggest liability.

## Judgement rules

- **Verbatim writes cut both ways.** Nothing paraphrased your entries on the way
  in (`infer=False`), so a badly worded entry stays badly worded until someone
  fixes it. That someone is this skill.
- **Superseded beats deleted.** An entry marked superseded still answers "why
  did we ever do it that way".
- Zero problems found is a normal, reportable outcome. Do not manufacture work.

## Constraints

- Never delete or rewrite an entry without showing the user exactly what changes
  and getting a yes.
- Memory content is local. Never quote entries into an external system.
- Report what you could not check — if the store is large and you sampled, say
  what you sampled.
