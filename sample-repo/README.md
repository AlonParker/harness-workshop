# notify-svc (workshop sample repo)

A stand-in for "a repository owned by another team". It exists so the
orchestration block has a target that is **not** your harness and whose rules
you did not write.

What matters here is not the code — there is none — but the three files that
carry the rules:

| File           | What it does in the exercise                              |
|----------------|-----------------------------------------------------------|
| `CLAUDE.md`    | this repo's house rules; a teammate loads them, a subagent in your harness never sees them |
| `config.json`  | the file the task asks to change                           |
| `CHANGELOG.md` | rule 1 says a config change must be recorded here too      |

You never run `claude` from your harness *against* this directory expecting its
rules to apply — that is precisely the mistake the exercise makes visible.
