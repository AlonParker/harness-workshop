---
name: harness-stats
description: >
  Aggregate the local delegation and headless-run logs
  (logs/delegations.jsonl, logs/headless-runs.jsonl) into a report: delegations
  per agent, error rates, tasks that no specialised agent claimed, recurring
  task descriptions, and what handoffs to other repositories cost. Use when
  asked how the harness is behaving, which agents are busiest, where routing
  misfires, or what the `claude -p` handoffs are spending.
---

# /harness-stats — read your own delegation log

This is the reader for `log-delegation.sh` and `log-headless-run.sh`. Without it
the logs just grow.

Two logs, because work leaves this harness by two different doors: delegations
stay inside the session (the runtime logs them via `PostToolUse`), and headless
runs start a separate process in another repository (the skill that launches
them logs that explicitly). A report covering only the first one silently omits
every handoff — and those are the expensive ones.

Input: `$ARGUMENTS` — optional period like `7d` or `30d` (default: everything).

## Algorithm

1. Read `logs/delegations.jsonl` at the project root. If it is missing or
   empty, say so — the `log-delegation.sh` hook fills it, so an empty log means
   either the hook is not wired or you have not delegated anything yet — and
   stop.
2. If a period was given, filter by `ts` (ISO-8601 UTC on every line).
3. Aggregate with `jq -s` and report:
   1. **Per agent:** delegation count and error count, sorted by count. This is
      the "who actually does the work" table.
   2. **Unclaimed work:** records where `agent` is a generic type (`claude`,
      `general-purpose`, `Explore`, `Plan`). Show each one's `desc`. These are
      tasks no specialised agent picked up — each is a candidate for a new
      subagent or a routing rule.
   3. **Recurring tasks:** the most frequent `desc` values, normalised. Anything
      you asked for repeatedly is a candidate for a skill.
   4. **Cost, where it exists:** average `duration_ms` and `tokens` per agent,
      computed **only** over records where those fields are non-null.
4. Read `logs/headless-runs.jsonl` the same way, filtered by the same period. If
   it is missing, say so once and move on — it only exists if `/run-elsewhere`
   (or your own handoff skill) calls `log-headless-run.sh`, and a harness that
   has never handed work to another repo will not have one. Report:
   1. **Per repo:** run count and total `cost_usd`, sorted by cost. This is the
      "where the money goes" table, and it is usually a surprise: a handoff is a
      full session, not a tool call.
   2. **Failures:** records with `is_error: true`, with their `subtype`
      (`error_max_turns` means the turn ran out of room, not that the task was
      impossible). Count `unparsable: true` records separately — those are runs
      whose JSON never arrived, almost always a missing `< /dev/null`.
   3. **Permission denials:** total `denials` and which repos they happened in.
      Non-zero means `--allowedTools` was too narrow for what the run needed —
      the agent's own report often does not mention it, so this number is the
      only honest signal.
   4. **Cache efficiency:** `cache_read` against `cache_creation`, per repo. A
      high read share means `--resume` is being used well; near-zero reads
      across many runs means every turn is paying for a cold start.
5. Close with a short list of proposed changes — a new subagent, a routing rule,
   a skill for a repeated task, a widened `--allowedTools` for a repo that keeps
   hitting denials. Propose only; do not edit anything.

## What this log cannot tell you

Say these plainly in the report rather than presenting gaps as missing data.

**Delegations.** Background delegations log at task **start**, so their
`duration_ms` and `tokens` are `null` by design. The `bg` field distinguishes
"no metrics by design" from "metrics went missing". Cost stats therefore cover
synchronous runs only — report how many records that was.

**Headless runs.** This log is written by a skill, not by the runtime, so it
records only the runs that went through that skill. A `claude -p` typed straight
into a terminal leaves no line at all — the gap is invisible from inside the
log, so never present the totals as "everything this harness spent".

`is_error` has three states and they are not interchangeable: `false` (the run
finished), `true` (it failed), `null` (the field was absent). Do not collapse
`null` into either one — an older log, or a payload shape that changed, is a
different fact from a successful run.

`cost_usd` is what the *provider* billed for that turn, which includes the
target repo's own CLAUDE.md, its hooks, and whatever it read to orient itself.
It is not a measure of how hard your task was.

## Constraints

- Read-only. Never modify the log, your CLAUDE.md, or agent definitions.
- The log is local and gitignored, and it contains prompt text and task
  descriptions. Never quote it into an external system (a ticket, a chat, a PR).
- Tolerate malformed lines: skip whatever `jq` cannot parse instead of failing.
