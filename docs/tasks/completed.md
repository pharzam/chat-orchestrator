# Completed

Append-only log of finished tasks, backlog-listed or not, most recent first.

## How to keep this file readable

**One line per task — keep it that way.** When a task in [backlog.md](backlog.md)
is done, move its line here unchanged except for a leading completion date:
`**YYYY-MM-DD** — **<ID>** — <summary> (<links>)`. Any detail worth keeping — the
design, the bugs caught, the verification story — lives in `tasks/<id>.md`, linked
as `[detail](<id>.md)`; it does **not** go inline here. This is a dated index, not
a changelog narrative. The git history and commit messages hold the blow-by-blow.

**A task that never had a backlog line** has no line to move: write its entry
here directly, in the shape above.

## Log

<!-- Most recent first. Example shape:
- **YYYY-MM-DD** — **‹ID›** — ‹one-sentence summary of what the task found or delivered› ([‹link›](...); [detail](‹id›.md))
-->

- **2026-10-06** — **T-vu2j** — Takes the tree of the second setup run into `main`, and keeps the change of `T-a0rt` ([#6](https://github.com/pharzam/chat-orchestrator/issues/6); [detail](T-vu2j.md))
- **2026-10-05** — **T-a0rt** — The section "Which checks run" names the applied ruleset 24509051 of `main` ([#2](https://github.com/pharzam/chat-orchestrator/issues/2); [detail](T-a0rt.md))
