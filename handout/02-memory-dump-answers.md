# Dump exercise — what a good curation looks like

Open this **after** you have curated `02-memory-dump.md` yourself. Reading it
first turns a 10-minute skill exercise into a 1-minute copy job.

There is no single right answer, but there is a right *shape*. Five entries
below; four or six is fine if the reasoning holds.

---

## The entries that belong

**1. The provider decision — as amended on Wednesday**

```
add_memory(
  text: "Push delivery goes through PushMate; email and SMS stay on MailHawk.
         SendWave was dropped because it caps us at 100 rps per account and
         will not lift it on our tier. PushMate's SMS add-on is billed per
         message with no volume discount (~4x MailHawk for marketing volume),
         so it is push-only.",
  metadata: {status: "accepted", verified_at: "<Wednesday>",
             topic: "providers", source: "NTF-482, NTF-508"}
)
```

Why this shape: it records the **Wednesday** scope, not Monday's. It keeps
both reasons (the rps cap *and* the SMS pricing), because those are what a
future reader needs in order to revisit the decision if either changes.

**The trap:** if you wrote Monday's "all new channels go through PushMate"
and stopped reading, your store now holds a decision the team explicitly
narrowed two days later. Nothing in the store would tell you that.

**2. API keys are out of config.json**

```
add_memory(
  text: "Service API keys must not be stored in config.json. They live in the
         secrets manager; config.json holds only the reference name. Outcome
         of a security review.",
  metadata: {status: "accepted", verified_at: "<Monday>", topic: "secrets"}
)
```

**3. The shared Redis cluster is going away**

```
add_memory(
  text: "The platform team is retiring the shared Redis cluster in August;
         every service must move to its own instance (mandatory, has a
         deadline). Affects our rate limiter.",
  metadata: {status: "accepted", verified_at: "<Tuesday>", topic: "infra",
             source: "INFRA-1190, NTF-501"}
)
```

Someone else's decision, but binding on you — that counts. Note the ticket
refs: this is the entry most likely to be questioned later ("says who?").

**4. The `priority` field was considered and rejected**

```
add_memory(
  text: "A per-channel `priority` field was proposed and rejected: PushMate's
         API has no priority concept, so it would mean faking it with separate
         queues, and no user has asked for it.",
  metadata: {status: "accepted", verified_at: "<Tuesday>", topic: "design"}
)
```

The one people leave out. A rejected option with its reason is exactly what
stops the same idea being re-proposed every quarter — and it is the kind of
thing that lives nowhere else, because rejected work leaves no code behind.

**5. (Optional) Monday's decision, marked superseded**

If you wrote Monday's version before reading Wednesday, do **not** delete it
— `update_memory` it to `status: superseded` and point at entry 1. That is
the honest history, and it is what the contradiction question in `02-memory.md` is
practising.

---

## What was correctly dropped, and why

| Message | Why it stays out |
|---|---|
| CI red / flaky `test_timeout` (Mon) | transient status |
| "the flaky test is fixed, PR NTF-511" (Wed) | a closed task, not a decision |
| "API key is in config.json" (Mon 10:06) | **actively false by 13:10 the same day.** Recording it would make your store confidently wrong |
| plov, friday demo at 16:00, merge freeze | not about how the system works |
| `retry_count` bump (Tue) | the question answered itself; no decision was made |
| "notifier.py picks the provider from the PROVIDERS dict" (Tue) | derivable from the code. Memory that duplicates code goes stale the moment the code changes |
| "deployed 2.4.1 to staging" | an event, not a decision |
| the `priority` discussion itself (Tue 09:15–09:40) | the *discussion* is noise; the **outcome** is entry 4 |

---

## The four mistakes this exercise is built to catch

1. **Recording the first version of a decision.** Monday's PushMate line was
   narrowed on Wednesday. Threads are chronological; decisions are not final
   just because they were stated confidently.
2. **Recording a fact instead of a decision.** "The API key is in
   config.json" was true for three hours. Decisions have a *why* and survive;
   facts about current state usually do not.
3. **Recording what the code already says.** The dispatch mechanism is one
   `grep` away. Two sources of truth means one of them is wrong soon.
4. **Dropping rejected options.** They feel like non-events. They are the
   cheapest entries you will ever write, and they prevent the most repeated
   work.

---

## If you are running this as a facilitator

Ask for entry counts before showing anything. The spread is the lesson: some
people write two, some twelve. Then ask specifically who recorded the API-key
location — and whether anyone caught the Monday/Wednesday correction. Those two
questions land the whole block.
