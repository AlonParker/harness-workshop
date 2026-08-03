# notify-svc — rules of THIS repository

This repo is owned by another team. Whoever works here plays by these rules,
not by the rules of the harness that sent the task.

## House rules

1. **`config.json` is the deployment config.** Every change to it must also add
   a line to `CHANGELOG.md` under `[Unreleased]`, in the same edit.
2. **Ask, do not invent.** If the task does not say which channel, provider or
   ticket number to use, ask the lead. Never guess a value and never leave a
   `TODO` in `config.json`.
3. **No commits.** Leave the change in the working tree; a human reviews it.
