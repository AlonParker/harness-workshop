#!/bin/bash
#
# Repo preflight check — run by the orchestrator BEFORE delegating work
# to a subagent that will touch the given repo(s).
#
# Usage: repo-preflight.sh <abs-repo-path> [<abs-repo-path>...]
#
# For each repo:
#   - reports the current branch and uncommitted changes
#   - fetches the remote (if any)
#   - fast-forwards a CLEAN repo on a base branch (main/master/dev/develop)
#     or an epic branch (epic/*) — epic branches are shared integration
#     branches and are valid starting points for feature work
#   - prints NEEDS_ATTENTION when the orchestrator must stop and ask the user:
#     uncommitted changes, non-base/non-epic branch, or a diverged branch
#
# Exit code is always 0 — the textual report is the contract.

BASE_BRANCHES="main master dev develop"

for repo in "$@"; do
  name=$(basename "$repo")
  if [ ! -d "$repo/.git" ]; then
    echo "[$name] SKIP: not a git repository"
    continue
  fi

  branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
  dirty=$(git -C "$repo" status --porcelain 2>/dev/null | grep -v '\.DS_Store' | head -5)
  has_remote=$(git -C "$repo" remote 2>/dev/null | head -1)

  is_base=no
  for b in $BASE_BRANCHES; do [ "$branch" = "$b" ] && is_base=yes; done
  case "$branch" in epic/*) is_base=yes ;; esac

  if [ -n "$dirty" ]; then
    echo "[$name] NEEDS_ATTENTION: uncommitted changes on branch '$branch':"
    echo "$dirty" | sed 's/^/    /'
    continue
  fi

  if [ "$is_base" != "yes" ]; then
    echo "[$name] NEEDS_ATTENTION: on non-base/non-epic branch '$branch' (clean). Ask the user: continue here, or switch to a base branch first?"
    continue
  fi

  if [ -z "$has_remote" ]; then
    echo "[$name] OK (local-only repo, no remote): branch '$branch', clean"
    continue
  fi

  git -C "$repo" fetch --quiet 2>/dev/null
  behind=$(git -C "$repo" rev-list --count "HEAD..origin/$branch" 2>/dev/null || echo 0)
  ahead=$(git -C "$repo" rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo 0)

  if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
    echo "[$name] NEEDS_ATTENTION: branch '$branch' diverged from origin (ahead $ahead / behind $behind)"
  elif [ "$behind" -gt 0 ]; then
    if git -C "$repo" pull --ff-only --quiet 2>/dev/null; then
      echo "[$name] OK: '$branch' fast-forwarded ($behind commits pulled)"
    else
      echo "[$name] NEEDS_ATTENTION: '$branch' is $behind commits behind and fast-forward failed"
    fi
  elif [ "$ahead" -gt 0 ]; then
    echo "[$name] NEEDS_ATTENTION: '$branch' has $ahead unpushed local commits"
  else
    echo "[$name] OK: '$branch' up to date, clean"
  fi
done
exit 0
