# Example tasks for a personal harness (brainstorm seeds)

Steal freely — these are shapes, not prescriptions. Good harness tasks
are recurring, multi-source, and boring to do by hand.

## Investigation / triage

- Crash triage: pull top crashes for the latest release, deobfuscate,
  find the blame commit, draft the ticket.
- "Why is this metric weird": read the dashboards' underlying queries,
  correlate with releases and merged PRs, produce a hypothesis report.
- Incident first-pass: collect logs, recent deploys, related tickets
  into one timeline before you even join the call.

## Code & review

- Review my PR against the team's conventions before a human sees it.
- Trace a field end-to-end across repos (mobile → backend → analytics).
- Impact analysis: who breaks if I change this API?

## Process / glue

- Morning digest: what landed in our repos, red PRs, sprint movement.
- Draft Jira tickets from raw findings, in the team's format, with
  acceptance criteria.
- Release notes from merged PRs since the last tag.
- Meeting prep: everything we know about topic X from docs, tickets and
  past decisions, one page.

## Knowledge

- "Where is X described" across scattered docs and Confluence.
- Keep a decisions log: after each design discussion, extract what was
  actually decided and store it with a date.
- Onboarding answers: a new teammate asks anything, the harness answers
  from the repo map + decisions memory.
