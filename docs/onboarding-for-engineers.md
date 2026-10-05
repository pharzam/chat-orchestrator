# Onboarding for engineers

> **Who this is for.** Software engineers joining this project who do **not**
> necessarily know the project's domain. You know how to build software. This
> document teaches you the project's terminology and the one or two facts that
> shape every decision, then hands you off to the deeper docs.
>
> **Read this first.** Every other document is written for someone already fluent
> in the terminology. This one gets you to that point. Budget half an hour.

## 1. Problem statement

`chat-orchestrator` is a backend service, written in Go, that keeps **durable
conversations**. A client opens a *session*, asks questions one at a time, and gets
answers that are grounded in an external **knowledge base** (KB). The client can
disconnect, or the service can restart, and the client can come back to the same
stored session and go on: the conversation lives in a database, not in memory.

For each question the service combines three capabilities that it does not own:

- the **KB**, which finds the evidence;
- a **Decision Model**, which gives typed judgments (is the question clear, is the
  evidence enough, does the evidence conflict). The first real Decision Model is
  TypeSafe AI Jev;
- a large language model (**LLM**), which writes the answer and the summaries. The
  two LLM protocols that the service must speak are Anthropic Messages and
  OpenAI-compatible Chat Completions.

The service owns the rest: the HTTP API, the conversation rules, the order of
work, the retries and the cost records.

The project was set out to answer one question: *can such a service be built so
that a conversation is never corrupted by a retry, a crash or a second process,
and so that waiting work and paid calls stay bounded, with every promise tied to a
named test?* The whole contract is the problem statement,
[`facts/problem-statement-brief.md`](facts/problem-statement-brief.md) (document
PSB-CHAT-001, revision 3.0). In this document "the brief" means that file, and
`R-XXX-nn` is the ID of one of its requirements. The brief says that it is the
complete product baseline (section 1).

## 2. Crash course: the domain

The words below are the same as in [glossary.md](glossary.md), but taught in
prose, in the order in which each one needs the one before it.

### 2.1 Session, turn, logical request, attempt

- A **session** is one stored conversation. Its owner is the pair
  `(tenant_id, subject)` that the service reads from the client's signed token. A
  client can never name another owner (`R-AUTH-03`).
- A **turn** is one user message and the conversational response to it.
- A **logical request** is one question that the client sends, named by
  `(tenant_id, subject, session_id, request_id)`. The client chooses the
  `request_id`, so it can send the same question again after a network error and
  mean *the same request*.
- An **attempt** is one admitted execution of a logical request. A retry is a new
  attempt of the same logical request.
- A **provider call** is one outbound call that can cost money: a Decision Model
  call, a summary call, a generation call, a KB call that is billable.

### 2.2 What "committed" means

A turn is **committed** when, in *one database transaction*, the service writes the
user message, the assistant message, their sources, the new **conversation
version** and the saved result of the logical request (`R-STATE-03`). The service
sends a successful reply only after that commit (`R-INV-03`). A failed, cancelled
or uncertain attempt leaves no half turn in the transcript (`R-INV-05`).

The conversation version goes up by exactly one for each committed turn
(`R-INV-02`). A cache, a provider's own conversation handle or process memory is
never the record of a conversation (`R-INV-06`): after a restart, the database is
all that there is.

There are three successful conversational outcomes (`R-API-10`). Each one is a
committed turn:

| `action` | When | Example reason codes |
| --- | --- | --- |
| `answer` | The evidence is enough, or the question is about the conversation itself, or it is small talk | `grounded`, `conversation_meta`, `smalltalk` |
| `ask_clarification` | The question is unclear, or the intent is ambiguous | `needs_clarification`, `intent_ambiguous` |
| `cannot_answer` | There is no, little or conflicting evidence; the question is out of scope; the model refused | `no_evidence`, `conflicting`, `out_of_scope`, `provider_refusal` |

Saying "I cannot answer, and here is why" is a *result*, not an error. An
infrastructure failure (the KB is down, a model call is invalid) commits nothing
and returns an error in the `application/problem+json` form (`R-ERR-01`).

### 2.3 The states of a request, and why one of them is `uncertain`

Every logical request has a stored state. The legal moves are in the brief
(`R-IDEM-19`):

```text
 queued ──► running ──► committing ──► completed
    │          │            │
    └──────────┴─────┬──────┘
                     ▼
       retryable │ uncertain │ failed_final
           │
           └──► queued   (the same request, admitted again, guarded)
```

- `completed` is final and replayable: the same request sent again gets the saved
  answer back, with the header `Idempotent-Replayed: true`, and makes no new
  external call (`R-IDEM-09`).
- `retryable` means that the work stopped in a way that leaves no unresolved paid
  call, so the client can send the same request again and it can resume safely.
- `failed_final` is a known, non-retryable failure. A new `request_id` is needed.
- `uncertain` is the state to understand first. The service sent a paid call, and
  then a timeout, a disconnect or a crash came, so it does **not know** whether the
  provider did the work. The service does not guess and does not repeat the call
  by itself: the same-key answer is `409 OUTCOME_UNCERTAIN` (`R-IDEM-09`,
  `R-IDEM-11`).

Before each paid call the service writes a **dispatch intent** marker to the
database, and it does not send the call if it cannot write the marker
(`R-IDEM-12`, `R-IDEM-13`). The guarantee is: **at most one durable turn for each
logical request**. The brief says that exactly one *provider charge* across any
network failure is not promised (section 5.4).

### 2.4 One writer at a time

Only one process may change the database and send paid calls. The process takes a
PostgreSQL session **advisory lock**, then writes a new, higher **`instance_epoch`**
to a control row, and every write checks that epoch in its own transaction. A
process that cannot take the lock stays *not ready*: it admits no work and runs no
recovery (`R-WRITER-01` to `R-WRITER-06`). The deployment also uses one replica
with a replacement strategy that does not overlap (`R-PROFILE-03`). This is called
**fencing**: an old process, even a slow one, cannot change the database after a
new one starts. (It cannot take back a call that a provider has already accepted;
that is what `uncertain` is for.)

### 2.5 Bounded work: slots, queues and deadlines

The service admits at most **100 active turns** at one time, and at most one active
turn in each session (`R-INV-01`). Work that cannot start waits in a bounded queue:
100 waiting requests in all, 2 per session, 10 active and 10 waiting per
*principal* (the owner identity). A request waits at most 60 seconds, and one
attempt has a total deadline of 180 seconds (`R-SCHED-*`, `R-TIME-01`, the table
in `R-CONFIG-01`). When the queue is full, the answer is `429` with
`Retry-After`, and nothing is stored (`R-IDEM-04`). Inside one session the order
is first in, first out, by the order in which the server admitted the requests
(`R-SCHED-02`).

### 2.6 The path of one turn

```text
 authenticate and validate ─► claim the request ─► wait for a slot
        ─► bind the session version ─► prepare bounded history (summaries)
        ─► classify the intent        (Decision Model)
        ─► retrieve authorized evidence   (KB)
        ─► assess the evidence        (Decision Model: three judgments)
        ─► generate the answer when the policy allows   (LLM)
        ─► validate the answer and its citations ─► commit atomically
```

The three judgments are `needs_clarification`, `evidence_sufficient` and
`evidence_conflicting`, each one `yes`, `no` or `uncertain` (`R-DEC-05`,
`R-DEC-06`). A **policy table** turns them into one action, and the *first row that
matches* decides (`R-POLICY-01`): an upstream error stops the turn; a needed
clarification comes next; then no evidence; then conflict; then insufficient
evidence; and only if everything is clear is an answer generated. The model that
writes the answer cannot change the action that was chosen (`R-LLM-05`).

### 2.7 Evidence is data, not instructions

What the user writes, what the KB returns and what a summary says are all
**untrusted data**. They can never change a credential, an endpoint, a role, a
policy or an instruction to the model (`R-KB-09`). The service does not fetch URLs
that a user supplies and does not run a tool that a model picks (`R-KB-11`). A
generated domain answer may reference only the evidence items that were supplied to
its call, and it must cite at least one of them before it can be committed as
`answer / grounded` (`R-LLM-07`). An invalid, invented or missing required reference
fails the turn with `CITATION_INVALID` (`R-LLM-08`). The KB citation rule does not
apply to smalltalk, which makes no KB call (`R-POLICY-02`), or to a conversation-meta
answer, which answers only from authorized transcript material and labels its
references as conversation history, not as current KB authority (`R-POLICY-03`).

### 2.8 Context and summaries

A model call must fit the window of the model that it goes to. The context has a
fixed order: stable instructions, a bounded **summary**, the complete turns since
that summary, the current evidence and the current question (`R-CTX-01`). A summary
is **derived state**: it is bounded to 4 KiB, it records which messages it covers
(`covered_seq`), and the original transcript stays available (`R-STATE-07`,
`R-CTX-08`). A summary is written only when the budget needs one, at most twice for
one attempt (section 11).

### 2.9 Caching and cost

Providers can reuse a stable beginning of a prompt (*native prompt caching*). The
service builds its prompts so that the beginning is byte for byte the same across
requests and restarts (`R-CACHE-06`). A correct answer, an authorization decision
and the continuity of a session never depend on a cache hit (`R-CACHE-02`). Every
inference attempt has a durable **usage record**. Each number in it is `reported`,
`estimated` or `unknown`, and an unknown number is never turned into zero
(`R-USAGE-02`).

## 3. What the system actually does

Take one question, `POST /v1/chat` with `{request_id, session_id, question}`.

1. The service checks the signed token (RS256), reads the owner, and checks that
   the session belongs to that owner. A session that does not exist, was deleted
   or belongs to someone else gives the same `404`, so a caller cannot probe for
   sessions (`R-AUTH-04`).
2. It *claims* the logical request in PostgreSQL. If the same key is already
   there, the stored state decides what the client gets: a replay, a
   `409 REQUEST_IN_PROGRESS`, a `409 OUTCOME_UNCERTAIN` or a re-admission.
3. It waits for a slot, then follows the path in section 2.6. Before each paid
   call it writes the dispatch marker; after each call it saves the result.
4. It commits the turn in one transaction and answers. If the answer to the
   client is lost, the client asks `GET /v1/sessions/{id}/requests/{request_id}`
   and reads the saved result: the database is the reference, not the socket.
5. After a crash, the next process takes the lock and reads the journal before it
   accepts any new work: it finishes committed records, marks work that never
   reached a provider as `retryable`, and marks unreconciled calls `uncertain`
   (`R-IDEM-20`, `R-IDEM-21`).

## 4. Why it is hard

Three facts make this project difficult, and each one stops the obvious design.

1. **A paid call can end in doubt.** A timeout does not prove that the provider
   did not get the call. The obvious design, *retry when it times out*, can double
   a charge and can run the retry against a conversation that has already changed
   (`R-IDEM-08`). So the service has the state `uncertain`, the dispatch marker and
   the version guard on a retry.
2. **100 turns at one time, in order inside each session, and no one starves.**
   With a cold estimate of 30 seconds a turn, a 60-second wait budget and a 100
   waiting-request cap, the queue is sized from numbers, and a request that cannot
   start in time is refused at once rather than made to wait (`R-SCHED-08`). A
   waiting request holds no slot, so a busy session does not block the others.
3. **A model answer is not a test result.** A service that answers
   `cannot_answer` to everything keeps almost every safety rule and fails the
   product. So, besides the deterministic tests, the brief fixes release floors on
   a labelled set before the first run: at least 80% of answerable cases answered,
   at least 95% correct abstentions, 100% valid citations (`R-QUAL-05`).

## 5. How this project works

### The one cultural thing to understand

**An unknown stays unknown.** The brief refuses to invent an endpoint, a price, a
model ID, a credential or a limit that nobody supplied, and it forbids a claim of
live success without evidence (`R-CONTRACT-03`). This repository works the same
way: a value has a recorded source, and a check that did not run, or a test that
was skipped, is a failure and never a pass (`R-TEST-05`, `R-TRACE-02`). Do not fight
this; it is the reason that the results can be trusted.

Consequences you will meet immediately, and which are not negotiable:

- A reply goes to the client only after the commit
  ([`guardrails.md`](guardrails.md), `Inv-3`).
- A failed, cancelled or uncertain attempt never appears as a completed turn
  ([`guardrails.md`](guardrails.md), `Inv-5`), and a doubtful paid call is never
  repeated silently (the pitfalls of section 2 of the same file).
- No secret enters Git, a prompt, a log or a fixture (`R-SEC-02`).
- The product is not "complete" while a required contract, a safety test, live
  cache evidence or a quality gate is blocked, failed or unverified (`R-GATE-07`).
- This repository's setup and its gate are reported *apart* from the completeness
  of the product (`R-GATE-06`).

### Repo layout

| Path | What |
|------|------|
| [`facts/problem-statement-brief.md`](facts/problem-statement-brief.md) | The problem statement, stored as it came: the contract of the whole product. |
| [`AGENTS.md`](../AGENTS.md) | The agent entry point — the gate in brief and a pointer to the R1–R13 rules, in one short file. [`CLAUDE.md`](../CLAUDE.md) imports it for Claude Code. |
| [`engineering-discipline.md`](engineering-discipline.md) | **How we work**: the quality gate, solution selection, branches, worktrees, commits, tests, reviews, and ADRs. Read before your first commit. |
| [`glossary.md`](glossary.md) | The shared vocabulary. Skim it; come back constantly. |
| [`facts/`](facts/) | Facts collected from the customer, stored as-is as immutable evidence. Derived requirements cite them by `F-NNNN` ID. |
| [`prd/`](prd/) | Product Requirements Documents, derived from the facts; each `REQ`/`NFR` cites an `F-NNNN` fact. |
| [`issue-workflow.md`](issue-workflow.md) | The issue-first rules (R1–R13): the ticket policy the gate assumes. |
| [`tasks/backlog.md`](tasks/backlog.md) | What to work on next. |
| `go.mod`, `docs/gates.tsv` | The Go module of the product and the list of its gate kinds, written by the setup of the project. |
| `.github/workflows/` | The continuous-integration jobs: the baseline's own jobs and one job for each gate kind. |
| [`setup/armature.pin`](setup/armature.pin) | The pinned baseline that this repository was set up from. |

### Which checks run

This table says what runs now. The documents of `docs/tests/` and `docs/ci/` say where a check
is meant to run; they do not say that it runs. A command that the setup wrote into a comment, a
template or an example does not turn that check on. A hook runs only in a clone where
`sh .githooks/install.sh` was run. A check that is inactive, or open, is never reported as
passed. Keep this table in step with the files that it names.

| Check | Where | State | Blocks a merge |
|-------|-------|-------|----------------|
| Hook provenance check, `adr-lint`, `prd-lint`, the discipline self-tests, `link-lint` | `.githooks/pre-commit`, steps 0 to 1f | Runs, in a clone with the hooks installed | No (local) |
| Lint (format check and `go vet`), unit tests, integration tests, end-to-end tests, security scan | `.githooks/pre-commit`, steps 2 to 4 | **Inactive.** Each step is a comment in the file. A step that holds a command still does not run; a step with an open gap has no command. The command of the lint line has a known limitation: when `git ls-files` fails and the working directory holds a file named `git ls-files failed` that `gofmt` accepts, the failure is lost. Do not turn that line on while this limitation remains. | No |
| Conventional Commits on the commit message; no direct push to `main` | `.githooks/commit-msg`, `.githooks/pre-push` | Run, in a clone with the hooks installed. `git push --no-verify` bypasses the second. | No (local) |
| `adr-lint`, `prd-lint`, `discipline-tests`, `link-lint`, `nested-checkout-check` | `.github/workflows/ci.yml`, on a pull request to `main` and on a push to `main` | Runs | No |
| `conventional-title`, `pr-link`, `review-record` | `.github/workflows/pr-title.yml`, `pr-link.yml` and `review-record.yml`, on a pull request; `pr-link` runs `docs/ci/pr-link-lint.sh` and `review-record` runs `docs/ci/review-record-lint.sh` | Runs | No |
| Gate jobs `static` and `test` | `.github/workflows/gates.yml`; the command of each job is a row of `docs/gates.tsv` | Active: each job runs the command of its row on a pull request | Yes, by the ruleset 24509051 (below) |
| Gate jobs `layout`, `boundary` and `contract` | `.github/workflows/gates.yml` | Pending: no command. A change of a Go file fails them; a change of other files leaves them `clear`. | Yes, by the ruleset 24509051 (below) |
| The gate script of `R-TEST-05` (format check, build, `go vet`, tests, tests with `-race`, offline) | — | **Not in this repository.** The gate jobs are not that script: `static` checks every Go file of the tree, `vendor/` included, and `test` runs `go test -count=1 ./...` with no race run. | — |
| A coverage check | — | **Inactive.** The coverage floor is an open gap (`docs/gates/coverage-floor.txt`). | — |
| The workflow templates of `docs/ci/` (`github-actions-*.yml`, `gitlab-ci.yml`) | `docs/ci/` | **Inert.** No job runs a template. The workflows of this repository are separate files in `.github/workflows/`. The linter scripts of `docs/ci/` are not inert: the workflows run them. | — |

The ruleset of the setup makes the five gate jobs the required checks of `main`, and no
other check. It is prepared in `docs/setup/branch-protection.json`, and the setup hands its
application on GitHub to the Operator (step S13). The five gate jobs block a merge only after
the ruleset is applied on GitHub and a read-back of the ruleset confirms it. The Operator
applied it on 2026-10-05 as the ruleset `layup: the default branch` (id 24509051), and a
read-back of the rules of `main`, without a login, showed the five required checks. Since
then, the five gate jobs block a merge.

### What to read next, in order

0. [`AGENTS.md`](../AGENTS.md) — the one-page summary, if you are a coding agent
   (or a human who wants the shape before the detail).
1. [`facts/problem-statement-brief.md`](facts/problem-statement-brief.md) — the
   contract. Read sections 1, 5, 7 and 9 first; the rest is reference.
2. [`engineering-discipline.md`](engineering-discipline.md) — how we work.
3. [`issue-workflow.md`](issue-workflow.md) — the issue-first rules the gate assumes.
4. [`glossary.md`](glossary.md) — skim, then reference.
5. [`guardrails.md`](guardrails.md) — the pitfalls and the frozen numbers.
6. [`tasks/backlog.md`](tasks/backlog.md) — what needs doing.

### Where the project stands

The repository was set up from the pinned baseline by `layup setup` (the first
pilot of that tool, in October 2026), and it has no product code yet. The brief
says what has to come first: the contracts that are not yet closed, above all the
wire contract of the KB, which the source material has not supplied
(`R-CONTRACT-01`); the independent modules that can be built and tested before they
are closed; and the offline gate (Gate A). Live integration (Gate B) and the model
quality run (Gate C) stay blocked until their inputs exist (`R-CONTRACT-02`). Keep
this paragraph in step with the backlog.
