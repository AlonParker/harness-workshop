# HOMEWORK — Raw thread dump: #notify-svc, three days of messages

**This is take-home. Nobody does it during the session**, and it is the half of
the memory block the session cannot teach you.

In the session you seeded a store with 15 ready-made entries and watched
retrieval work. Every one of those entries was already clean: atomic, with a
status, a date and a reason. That shows you what good memory *looks like* — not
how to get there. Real input is not a curated JSON file, it is a channel like the
one below.

Budget 20-30 minutes. Do it before you start feeding your own team's decisions
into a store, because a polluted memory is worse than an empty one: it answers
confidently and wrongly, and nothing in the retrieval flow flags it.

> Curate this into your mem0 store with `add_memory` — **4 to 6 entries, no
> more**. Most of what follows does not belong in memory; deciding what to
> drop *is* the exercise.
>
> Before you start, one rule to hold onto: memory is for decisions that are
> **accepted** and still **true**. Not discussions, not status, not anything
> a reader could get from the code itself.
>
> **A note on where these go.** This is a *different* team from the one whose
> decisions you seeded in the session: that was a reports service, this is
> notifications. Nothing here contradicts what is already in your store — the
> topics are kept apart on purpose, so the answers to this exercise were not
> handed to you in advance. If you want the two kept visibly separate, put
> `topic: notify-svc` in the metadata; if you would rather keep the store clean,
> a fresh `MEM0_COLLECTION` works too (remember it starts empty).

---

## Monday

**dasha** 10:02
morning! CI is red again, the flaky test_timeout thing 🙄

**marat** 10:03
restarted, green now. third time this week

**dasha** 10:04
btw where do we keep the service API key? new laptop, setting things up

**marat** 10:06
it's in config.json, `api_key` field at the bottom

**dasha** 10:07
found it thx

**tolik** 11:30
team: SendWave pricing call happened. they cap us at 100 rps per
account and won't lift it on our tier. we hit the cap in the KZ launch
retro, remember

**marat** 11:33
so what's the verdict?

**tolik** 11:41
verdict after the call with @lead: **we drop SendWave. All new channels
go through PushMate.** existing SendWave channels migrate by end of
quarter. this is final, писал в тикете NTF-482

**dasha** 11:42
+1, their SMS receipts were nice though 😢

**marat** 11:45
lunch? the new place does plov on thursdays

**dasha** 13:10
⚠️ security review outcome: API keys must NOT live in config.json
anymore. moved to the secrets manager, config keeps only the reference
name. done for prod today, staging tomorrow

**marat** 13:12
ack. updating the runbook

**tolik** 13:40
anyone object if I bump retry_count to 3? seeing transient 502s
… never mind, it's already 3

**dasha** 15:20
friday demo moved to 16:00 btw

---

## Tuesday

**marat** 09:15
proposal: let's add a `priority` field to channels so we can route
urgent stuff first. thoughts?

**tolik** 09:22
what would it even do? PushMate has no priority concept on their API

**marat** 09:26
fair. we'd have to fake it with separate queues

**dasha** 09:40
I'd rather not until someone actually asks for it

**marat** 09:41
ok, parking it

**tolik** 10:05
heads up: platform team is deprecating the shared Redis cluster in
August. they say every service must move to its own instance. not
optional, there's a migration deadline — INFRA-1190

**marat** 10:07
oof. that touches our rate limiter

**tolik** 10:09
yep. filed NTF-501 to track our side

**dasha** 14:30
notifier.py picks the provider by looking up `channel["provider"]` in the
PROVIDERS dict, in case anyone was wondering how dispatch works

**tolik** 14:31
👍

**marat** 16:50
deployed 2.4.1 to staging

---

## Wednesday

**tolik** 11:00
so re: PushMate — turns out their SMS gateway add-on is billed per
message with no volume discount. for the marketing channel that's
roughly 4x what MailHawk costs us

**dasha** 11:05
so we're not using PushMate for everything after all?

**tolik** 11:20
correction to Monday: **PushMate for push only. Email and SMS stay on
MailHawk.** the "all new channels through PushMate" line was too broad —
it was about replacing SendWave, not about consolidating everything.
NTF-482 updated, added NTF-508 for the marketing channel migration

**marat** 11:22
good, updating the runbook again 🙃

**dasha** 15:45
reminder: nobody merge to main during the freeze tomorrow

**marat** 17:30
the flaky test_timeout is fixed btw, it was a hardcoded 500ms sleep.
PR NTF-511
