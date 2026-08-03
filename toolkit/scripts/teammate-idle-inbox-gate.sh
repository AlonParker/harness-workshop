#!/usr/bin/env bash
# TeammateIdle gate: keep a teammate awake while its Agent Teams inbox holds
# pending (undelivered) messages from other agents.
#
# Fixes the checkpoint delivery race in lead/teammate workflows: a teammate
# sends its checkpoint, goes idle, and the lead's approval lands in the inbox
# file without waking it - previously requiring a manual "approval is in your
# inbox" nudge from the lead.
#
# Mechanics (verified 2026-07-17 against ~/.claude/teams/*/inboxes/*.json):
# - The inbox file is a JSON array; DELIVERED messages are removed from it, so
#   any entry from another agent = pending. The `read` flag is unreliable
#   (never flips) — do not use it.
# - Exit 2 blocks the idle and sends stderr to the teammate as feedback.
# - A per-teammate state file dedupes by msg_id so a stuck entry can wake the
#   teammate at most once, never loop it forever.
set -euo pipefail

input=$(cat)

python3 - "$input" <<'PY'
import glob, json, os, sys

hook_input = json.loads(sys.argv[1])
teammate_id = hook_input.get("teammate_id") or ""
# teammate_id may be "name@session-xxx" or a bare name/id.
name = teammate_id.split("@", 1)[0]
if not name:
    sys.exit(0)

candidates = glob.glob(os.path.expanduser(f"~/.claude/teams/*/inboxes/{name}.json"))
if not candidates:
    sys.exit(0)  # no inbox — nothing to gate
inbox_path = max(candidates, key=os.path.getmtime)

try:
    with open(inbox_path) as f:
        inbox = json.load(f)
except (json.JSONDecodeError, OSError):
    sys.exit(0)  # unreadable mid-write — don't block idle on infra noise

state_path = os.path.join(os.path.dirname(inbox_path), f".idle-gate-fired-{name}.json")
try:
    with open(state_path) as f:
        fired = set(json.load(f))
except (FileNotFoundError, json.JSONDecodeError, OSError):
    fired = set()

pending = [
    m for m in inbox
    if isinstance(m, dict)
    and m.get("from") not in (name, teammate_id)
    and m.get("msg_id")
    and m["msg_id"] not in fired
]
if not pending:
    sys.exit(0)

fired.update(m["msg_id"] for m in pending)
with open(state_path, "w") as f:
    json.dump(sorted(fired), f)

senders = ", ".join(sorted({m.get("from", "?") for m in pending}))
print(
    f"Your inbox has {len(pending)} pending message(s) from: {senders}. "
    "They will be delivered to you now — read them and act on them "
    "(e.g. an approval you were waiting for) before going idle.",
    file=sys.stderr,
)
sys.exit(2)
PY
