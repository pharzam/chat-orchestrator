# chat-orchestrator

*Persistent, knowledge-grounded conversations with decision models.*

> A Go backend service that keeps durable conversations, answers from an external
> knowledge base, and bounds its waiting work and its paid calls.

**What this is.** `pharzam/chat-orchestrator` is a software project under
construction. The product is defined by its problem statement,
[`docs/facts/problem-statement-brief.md`](docs/facts/problem-statement-brief.md)
(document PSB-CHAT-001, revision 3.0). The repository has no service code yet. It has
an engineering-discipline system — a quality gate, guardrails, decision records, a
glossary, a facts convention and a task backlog — and the gates of a Go project.

## Start here

1. **[`docs/onboarding-for-engineers.md`](docs/onboarding-for-engineers.md)** — read this first
   (~30 min). It states the [Problem statement](docs/onboarding-for-engineers.md#1-problem-statement)
   and teaches the project's vocabulary.
2. **[`docs/engineering-discipline.md`](docs/engineering-discipline.md)** — how we work: the
   quality gate every substantive task passes, plus branches, tests, reviews, and
   ADRs. Read before your first commit.
3. **[`AGENTS.md`](AGENTS.md)** — if you are a coding agent, start here instead. It
   summarises [`docs/engineering-discipline.md`](docs/engineering-discipline.md)
   and [`docs/issue-workflow.md`](docs/issue-workflow.md), and indexes the rest.
   The long documents stay authoritative.

## What's inside

| Piece | What it holds |
|-------|---------------|
| [`AGENTS.md`](AGENTS.md) | The agent entry point: the quality gate, the checks, a pointer to the R1–R13 rules, and which document is authoritative for each. |
| [`CLAUDE.md`](CLAUDE.md) | One line, `@AGENTS.md`, so Claude Code loads the same guide. No second copy to drift. |
| [`docs/agents/`](docs/agents/) | What the entry points are and what they may not become ([ADR-0004](docs/adr/0004-ship-agent-entry-points.md)). |
| [`docs/onboarding-for-engineers.md`](docs/onboarding-for-engineers.md) | The first door: the problem statement and a domain crash course. |
| [`docs/engineering-discipline.md`](docs/engineering-discipline.md) | The quality gate, the reusable solution-selection standard, and every working practice. |
| [`docs/issue-workflow.md`](docs/issue-workflow.md) | The issue-first workflow (R1–R13): the ticket policy the gate assumes. |
| [`docs/glossary.md`](docs/glossary.md) | The shared vocabulary the other docs assume. |
| [`docs/guardrails.md`](docs/guardrails.md) | Known pitfalls, the invariants of the problem statement, pre-registered pass/fail rules, and validation. |
| [`docs/adr/`](docs/adr/) | Architecture Decision Records — the *why* behind structural choices — plus [`adr-lint.sh`](docs/adr/adr-lint.sh), the discipline test that keeps them honest. |
| [`docs/facts/`](docs/facts/) | The problem statement and the setup answers, kept as immutable facts. |
| [`docs/prd/`](docs/prd/) | Product Requirements Documents derived from the facts, plus [`prd-lint.sh`](docs/prd/prd-lint.sh), the discipline test that keeps them honest. |
| [`docs/tests/`](docs/tests/) | The testing conventions — the test levels, a pattern per level, the security, scaling, and Definition-of-Done checklists, and test-to-requirement traceability. |
| [`tests/`](tests/) | The repo-root directory for the product tests. It is empty until the first test is written. |
| [`docs/tasks/`](docs/tasks/) | The task index — [`backlog.md`](docs/tasks/backlog.md) and [`completed.md`](docs/tasks/completed.md). |
| [`docs/setup/`](docs/setup/) | The pin of the baseline ([`armature.pin`](docs/setup/armature.pin)), the list of the hashes of the facts, the protection of the default branch, and the open gaps. |
| [`.githooks/`](.githooks/) | Git hooks that enforce the cheap gate locally: a commit-message check, and a pre-commit runner of the discipline linters. Its lint, test and security steps are comments and do not run. Install with `sh .githooks/install.sh`. |
| [`.gitattributes`](.gitattributes) | It keeps the scripts and hooks at line-feed endings, without which none of them runs on a Windows checkout, and pins the handful of fixtures whose bytes must not change. |
| [`docs/ci/`](docs/ci/) | The workflow templates of the baseline (GitHub Actions and GitLab CI), which are inert, and the linter scripts `pr-link-lint.sh` and `review-record-lint.sh`, which the workflows of this repository run. |
| `.github/workflows/` | The CI jobs of this repository: the jobs of the baseline, and one job for each gate kind of the Go stack. |
| `go.mod`, `docs/gates.tsv` | The Go module of the product, and the list of its gate kinds. |
| [`docs/templates/`](docs/templates/) | Inert GitHub/GitLab issue and pull-request files that embody the issue-first workflow. |

## How this repository was set up

This repository was set up from a pinned engineering-discipline baseline by
`layup setup`. [`docs/setup/armature.pin`](docs/setup/armature.pin) holds the source of the
baseline and the commit that it was copied from, and
[ADR-0009](docs/adr/0009-pin-the-baseline.md) records the pin. Each step of the setup
that changes the tree is one commit with the message `chore: setup <step>`. The
record of each step, and the source of each value that the setup wrote, is on the
orphan branch `layup-records`, in `setup/record.tsv`. The gate of this repository runs
without the tool that made it.

## Working here

Every change starts from an issue and lands through a pull request that links it. The
ruleset of the setup makes the gate jobs of the Go stack the required checks of the default
branch; they block a merge only after the ruleset is applied on GitHub and a read-back
confirms it. The baseline's own jobs run on each pull request and do not block a merge.
[Which checks run](docs/onboarding-for-engineers.md#which-checks-run) lists every check and
says which ones are inactive. The product rules are in
the problem statement, and the first work is to close its open contracts and to build
the modules that do not depend on them (`R-CONTRACT-01`).
