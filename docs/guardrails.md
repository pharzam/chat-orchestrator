# Guardrails — the known pitfalls, and the numbers you must not move

This document is the target of gate step 2, "Honor the guardrails", in
[`engineering-discipline.md`](engineering-discipline.md). It holds the pitfalls a
task author must take into account **before** writing code, so the team does not
re-derive a known trap every time.

It merges two kinds of guardrail that many projects keep in separate files —
**decision gates** (pre-registered pass/fail rules) and **validation** (how you check
you are not fooling yourself). Both exist here, and both are read before work starts.

## In plain terms

The worst mistake this project can make is to say that a conversation is safe, or
that a paid call did no harm, when the evidence does not show it: a green result that
hides a skipped test, a retry that repeats a paid call, or a guess in place of a
value that nobody supplied. What stops it is that every promise has a named test, an
unknown stays unknown, and the pass/fail numbers are written down before a run.

## 1. Pre-registered decisions — or the goalposts move

A decision rule chosen **after** seeing the result is a fitted parameter, not a
rule. Write the pass/fail numbers first, somewhere they cannot be quietly edited.

- **What must be pre-registered:** the pass rule of Gate A (formatting, build,
  `go vet`, the tests and the race detector, with a missing prerequisite or a skipped
  mandatory test counted as a failure); the release floors of Gate C (section 19 of the
  problem statement: at least 80% of the answerable cases answered, at least 95%
  correct abstentions, 100% valid citations, at least 95% supported claims, at least
  90% correct intent or action, at least 90% of the conversation facts kept through a
  summary and 100% of the critical constraints, and at least 95% of the generated text
  in the requested language); the thresholds of the Decision Model profile (an intent
  choice is accepted at a top probability of at least 0.70 with a margin of at least
  0.20; an assessment is `no` at p of 0.20 or less and `yes` at p of 0.80 or more, 0.85
  for `evidence_sufficient`); the initial engineering defaults (100 active turns, 100
  waiting requests, a 60-second queue and a 180-second deadline); and, for each task,
  its Budget maximum and its Cycle cap.
- **Where the numbers freeze:** the problem statement, a raw fact that never changes
  (revision 3.0, hashed in `docs/setup/facts.sha256`); the versioned policy profile of
  each provider and model, for the thresholds (`R-DEC-07`); the traceability file, for
  the acceptance assertions (`R-TRACE-01`); and the plan-review comment of each issue,
  for its Budget maximum and its Cycle cap. A threshold or an assertion is not weakened
  after a failure is seen, unless a reviewed baseline change says so (`R-TRACE-04`).
- **The bands, not a single line:** prefer **Pass / Investigate / Fail** to a
  single pass line on a noisy measure. Define "Investigate" with a rule written
  before you look — for example, one re-examination whose scope is fixed in
  advance; landing there twice counts as Fail.

### 1.1 The invariants of the problem statement

These six rules bind every solution in this repository. They come from section 1.2 of
the problem statement, [`facts/problem-statement-brief.md`](facts/problem-statement-brief.md),
which is frozen: a change needs a new revision of that document, not an edit here. Each
entry gives the rule with its requirement ID, the trap that breaks it in silence, and the
check that catches a violation. A check value is a path plus the gate that runs it (`hook`
or `ci:<job>`), or the words `no check yet`. A script that exists but that no gate runs
is `no check yet`. This repository has no product code yet, so no check of these rules
exists yet.

- **Inv-1** — At the default configuration the service allows no more than 100 active
  turns, and no more than one active turn in each session (`R-INV-01`). A turn is active
  from the time that its session is eligible and a global slot is assigned to it. It keeps
  its slot while it waits for dependency capacity and during finalization, until its outcome
  is resolved (`R-TIME-05`). A request that waits for session or global admission holds no
  active slot, and an idle session holds none (section 1.2 of the problem statement). Trap: a
  slot that is released while an active turn waits for a dependency or finalizes, so a 101st
  turn runs, or two turns of one session run at once.
  Check: no check yet
- **Inv-2** — A logical request commits at most one user and assistant pair and one
  increment of the conversation version (`R-INV-02`). Trap: a retry or a duplicate that
  passes a check-then-insert race and commits a second turn.
  Check: no check yet
- **Inv-3** — A successful chat response is sent only after its complete outcome is durably
  committed (`R-INV-03`). Trap: a reply written to the client before the commit returns, so
  a crash leaves a client with an answer that the transcript does not hold.
  Check: no check yet
- **Inv-4** — The next turn in a session loads the latest committed conversation state
  after the turn before it is resolved (`R-INV-04`). Trap: a turn that starts from a stale
  read while its predecessor is still committing.
  Check: no check yet
- **Inv-5** — A failed, cancelled or uncertain attempt does not appear as a completed turn
  in the transcript (`R-INV-05`). Trap: a partial answer or a half pair that is saved for
  the sake of a later retry.
  Check: no check yet
- **Inv-6** — Cache state, provider conversation handles and process memory are never the
  authoritative record of a conversation (`R-INV-06`). Trap: a design that works only while
  a cache or a provider session is warm.
  Check: no check yet

## 2. Known pitfalls — the traps specific to this domain

The failure modes that this project has to expect, from the problem statement. For each:
the trap, why it is silent, and the check that catches it. The acceptance families `A01`
to `A38` (section 18.2 of the problem statement) are those checks, once they exist.

- ❌ **A reply that outruns its commit.** The handler writes the response, and then the
  transaction commits, or the commit is lost. It is silent because every test that does not
  stop the process between the two passes. The check: the atomic-commit and
  lost-acknowledgement tests (`A09`) and the crash points of `A08`; a response is never
  built from state that is not yet committed.
- ❌ **A timeout read as "the call did not happen".** A paid call that timed out may have
  been accepted by the provider. Treating it as free lets a retry run it again, and the
  charge doubles. It is silent because the fake that a test uses fails cleanly. The check:
  the dispatch marker and the state `uncertain` (`R-IDEM-11`, `R-IDEM-12`), tested at each
  crash point of `A08` and by `A23`.
- ❌ **A retry against a changed conversation.** Request A1 retries after request A2 has
  committed, and answers a question in the light of a conversation that has moved. It is
  silent because the retry succeeds. The check: the retry-version guard (`R-IDEM-06` to
  `R-IDEM-08`), tested by `A22`.
- ❌ **A check-then-insert race.** Two copies of one request, two processes, or an admission
  and a deletion each pass a check, and then both write. It is silent because a
  single-threaded test never interleaves them. The check: atomic claims and the epoch check
  inside the transaction (`R-IDEM-03`, `R-WRITER-04`), with the barrier tests of `A04`,
  `A07`, `A17` and `A18`; use barriers and controlled clocks, not sleeps (`R-TEST-03`).
- ❌ **Unknown usage turned into zero.** A provider that reports no usage, or a cached input
  that is counted twice, gives a total that looks exact. It is silent because the sum is a
  number. The check: `reported`, `estimated` and `unknown` kept apart, and the
  provider-specific accounting tests (`R-USAGE-02`, `R-USAGE-03`, `A14`).
- ❌ **An invented value.** A KB endpoint, a price, a model ID, a credential or a limit that
  nobody supplied, written as if it were real, makes a green test that proves nothing about
  the real system. It is silent because a fake accepts it. The check: contract closure
  before Gate A is called complete (`R-CONTRACT-01`, `R-CONTRACT-03`), and a missing input
  that keeps its gate `blocked` or `unverified` (`A33`).
- ❌ **A green gate over a skipped test.** A missing compiler, image or module, or a
  mandatory test that is skipped, ends with exit 0. It is silent because the summary line
  still says "ok". The check: the offline gate fails on a missing prerequisite, and CI
  refuses a skipped test that is shown as passed (`R-TEST-05`, `R-TRACE-02`, `A20`).
- ❌ **A cache hit that changes the answer.** An answer, an authorization decision or a
  session that works only while a cache is warm. It is silent because tests run with a warm
  cache. The check: the same turns with a cold cache and after a restart give the same
  result (`R-CACHE-02`, `A02`, `A13`).
- ❌ **Untrusted text taken as an instruction.** A KB passage or a user message that says
  what to do changes a policy, a role or an endpoint. It is silent because a model follows
  the text politely. The check: `A37`, and the live measure in Gate C; evidence is data
  (`R-KB-09`).
- ❌ **A malformed decision read as a doubt.** A missing or invalid output of the Decision
  Model is acted on as if it were `uncertain`. It is silent because the policy table has a
  row for `uncertain`. The check: malformed output is `DECISION_INVALID` and no turn is
  committed (`R-DEC-08`, `R-POLICY-01`), tested by `A10` and `A11`.
- ❌ **A result that is easy to pass by saying nothing.** `cannot_answer` to every question
  keeps most safety rules and fails the product. It is silent because the safety tests stay
  green. The check: the Gate C floors on the answerable cases, counted with their
  denominators and with errors counted as failures (`R-QUAL-05`).
- ❌ **A filled value read as a running check.** A command that the setup wrote into a comment, a
  template or an example does not turn that check on: the file only looks configured. It is silent
  because nothing fails, and the line reads like a check that runs. The check: the table
  [Which checks run](onboarding-for-engineers.md#which-checks-run) names each check and its state,
  and a check that is inactive or open is never reported as passed (`R-TEST-05`, `R-TRACE-02`).

### Writing a lesson back

A trap caught once should not be re-derived by the next task, so a lesson does not
stay on the issue that learned it. When a task ends, its author asks whether the task
taught a trap the next reader could hit; if it did, the lesson is written **here** as a
new `❌` pitfall — the trap, why it is silent, and the check that catches it — in the
same pull request. Gate step 7 asks the question, so the rule is applied rather than
merely written (see [Keeping documentation current](engineering-discipline.md#keeping-documentation-current)).

This is the one **cross-task** reach that the discipline adds on purpose.
[R6](issue-workflow.md#r6--agent-to-agent-communication-through-the-issue) and
[R7](issue-workflow.md#r7--decision-transparency-on-every-action) already keep the
coordination and the reasoning on the issue, and
[Honesty and evidence](engineering-discipline.md#honesty-and-evidence) already reports a
failure as a failure — but each is scoped to *one* issue thread. A lesson on issue #N is
discoverable only by someone who reads #N; §2 is where it reaches issue #N+1.

**The filter — or §2 grows until nobody reads it.** Write back only a trap that would
**catch the next reader**: a silent failure mode, a check that looked green for the
wrong reason, a footgun in the baseline or the domain. Do **not** write back a one-off with
no general lesson, a restatement of a rule that already lives elsewhere, or the
blow-by-blow of the task — those belong to the issue thread and the commit history.
Volume is the failure mode here, not absence: a pitfall list nobody finishes reading
guards nothing.

### Gate pitfalls

The gate is only as real as the thing that runs it. These traps let it report
success without having done its job.

- ❌ **An absolute `core.hooksPath`.** Worktrees **share** `.git/config`, so an
  absolute path binds every worktree to one checkout's hooks. A check added on a
  branch then does not run on that branch's own commits: the hook reports success
  having run something other than what the branch says it runs. It is silent
  because the hook still runs, still passes, and still uses the *right* files —
  only the *set of checks* comes from elsewhere. **The check:** install with a
  **relative** path, `git config core.hooksPath .githooks`, which git resolves per
  working tree. The `pre-commit` hook's own block 0 then refuses to run when the
  resolved hooks directory lies outside the tree being committed to, and
  [`.githooks/tests/provenance-check.sh`](../.githooks/tests/provenance-check.sh)
  proves it against real worktrees, reporting how many cases it ran rather than a
  count written down here to go stale.
  **A relative path escapes just as surely:** `../elsewhere/.githooks` is as
  foreign as any absolute one, so the check resolves the value instead of trusting
  that relative means local.
  **No path at all is the same trap:** with `core.hooksPath` unset git falls back
  to `.git/hooks`, which a linked worktree reaches through the shared *common* git
  directory. So block 0 judges the resolved directory whatever set it, and names
  the source it actually found — telling an operator to fix a setting they never
  set is its own dishonest report.
  **Bound on the damage:** CI invokes each check script directly and never through
  `core.hooksPath`, so this costs a local round trip, not a landed bug — a
  developer-experience gap, not an open gate.
- ❌ **A check that cannot fail.** A grep whose pattern also matches its own error
  message, a fixture harness that compares only exit codes, a coverage floor that
  counts zero as success. The check: for every assertion, make it fail on purpose
  once and read the reason — a green nobody attacked is not evidence.
- ❌ **A check that runs but does not block.** CI is green, the pull request
  merges, and nothing connects the two: no check is required on the default
  branch, so the green was a run result, not a merge control, and a red would
  have merged the same way. It is silent because the run result looks identical
  either way. The check:
  [make the checks required](ci/README.md#make-the-checks-required) on the
  default branch, and take the branch API read as the evidence — not the green run.

- ❌ **A check the change supplies is not a control.** CI checks out the pull
  request's own head and then runs the check from that checkout, so **the script
  that judges the change comes from the change**. Measured: a branch that replaces
  `docs/links/link-lint.sh` with `exit 0` passes that job — and replacing
  `docs/tests/run-discipline-tests.sh` as well turns **every** required job green
  over a dead link in the tree. Gutting a linter alone does not, because the
  fixture harness asserts exit codes and 19 `bad-*` cases stop failing; the runner
  is the single point.
  **The trap inside the remedy:** each script roots its scan at its own directory
  (`dirname $0`), so running the default branch's copy *where it sits* lints the
  wrong tree and reports OK. That was measured too, while building the fix.
  **The check:** every job in [`ci.yml`](../.github/workflows/ci.yml) restores the
  check scripts from the default branch **in place** before running them, so the
  branch's copy is never the judge.
  **Bound on the damage, and it is not nil:** a `pull_request` event runs the
  workflow as the branch has it, so a branch that edits `ci.yml` removes the
  restore step — closed only by review of `.github/**`, which wants a `CODEOWNERS`
  entry and a second human the forge knows about. Restoring also stops a bypass,
  not a merge: once a weakened check lands it *is* the default branch's copy. And
  a change that *improves* a check is judged by the older copy, so it lands in two
  steps. These checks are a control against forgetting, not against an operator
  who edits the check.

### Testing pitfalls

These traps are not domain-specific: they hurt every project's test suite, so the
baseline ships them filled. Keep them, and add the project's own above.

- ❌ **Testing after the code.** A test written to fit code that already "works"
  tends to encode the code's bugs as expected behaviour. The check: write the test
  first and watch it fail for the right reason
  ([strict TDD](engineering-discipline.md#requirements-traceability)).
- ❌ **Tests that depend on external state.** A test that reads a shared database, a
  live network, the wall clock, or another test's leftovers passes or fails for
  reasons unrelated to the code. The check: isolate and control every dependency,
  with a fresh fixture per run — see
  [`tests/scaling-checklist.md`](tests/scaling-checklist.md).
- ❌ **Tests that pass for the wrong reason.** A test that asserts nothing, asserts
  the wrong thing, or never actually exercises the path reports a safety that is not
  there — worse than no test. The check: confirm the test fails when the behaviour
  is broken; the red step is the proof.
- ❌ **Stale tests after a requirement changes.** When a requirement changes but its
  test does not, the suite now guards the old behaviour and blocks the new. The
  check: the [old-tests conflict rule](engineering-discipline.md#testing) — fix the
  code, update the requirement with a written reason, or retire the test; never
  weaken a passing old test.
- ❌ **Tests that slow down as the project grows.** A suite that creeps past the
  hook's patience gets skipped, and a skipped gate is no gate. The check: keep the
  cheap levels fast and cheap-first, push slow ones to CI, and bound each with
  `‹test timeout›` — see [`tests/scaling-checklist.md`](tests/scaling-checklist.md).

### Reference-sweep pitfalls

A change that edits references or a rule's wording across the tree has three silent
failure modes worth keeping.

- ❌ **A blanket find-and-replace over a renamed record's citations.** When a record
  moves or a directory is renumbered, the same bare token can name *different*
  records in two places — a bare `ADR-0005` is the living `docs/adr/` record to one
  reader and the archived `docs/decisions/` one to another, because the two sequences
  once shared numbers. A global replace of the token silently rewrites the citations
  you must **not** touch alongside the ones you must; and the reverse — a citation the
  sweep's pattern never matched (a compound like `ADR-0003/0005`, a token in a code
  span or a `.sh`/`.yml` comment, one split across a line break) — is silently *left*
  pointing at the wrong record. It is silent because **no linter catches it**:
  `link-lint` checks only that a *link* resolves, and a bare textual mention resolves
  to nothing, so a citation that now sends a reader to the wrong record still passes
  every check. **The check:** classify each occurrence by its **link target**, not its
  token — a link into `../adr/` is the living record and stays, a link into
  `../decisions/` is the archive and is rewritten — and read every *bare* mention by
  hand, in every token shape, since it carries no path to classify it. A
  pre-registered grep that must finish returning only the intended survivors (the
  mapping table and deliberate historical prose) is the closest thing to a gate; run
  it against the whole tree, not only the files you expected to touch.
- ❌ **A repoint that orphans a bare back-reference.** Repointing a citation can
  strand a *different* reference that named the target only through it. A comment
  reading `section 6 says …` leaned on a nearby `D-0003 section 6` for its antecedent;
  repoint every `D-0003 section 6` and the bare `section 6` is left pointing at a
  structure only the deleted record holds — wrong on a project's tree, and sharing
  **no token** with the thing you renamed. It is silent because a grep keyed on the
  obvious token (`D-000N`) cannot match a bare `section 6`, so the pre-registered
  check goes green over the survivor. **The check:** grep for the *shapes* a reference
  takes, not only the token — a bare `section N`, a `§`, a pronoun (`that section`,
  `the record`) whose antecedent you removed — and read the neighbourhood of every
  citation you changed, not the citation alone.
- ❌ **Editing a rule whose decision record is archived.** A rule lives in two places
  — its operative statement in a living doc, and the immutable decision record that
  first set it under `docs/decisions/`. Change the living one and the archived one
  still asserts the old, and **no check compares them** (`adr-lint` never reads
  `docs/decisions/`; `link-lint` checks resolution, not agreement). You cannot rewrite
  the immutable body to match; discharge the divergence with a `Status`-line
  **amendment pointer** on the archived record. **The check:** grep the whole tree —
  archive and forge templates included — for the old wording, and reconcile each living
  mirror or point each immutable one; a dated log entry recording history stays.
- ❌ **A hand-mirrored count or check-set that no linter guards.** The set of discipline
  linters — and how many there are — is spelled out by hand across many living
  docs, among them [`engineering-discipline.md`](engineering-discipline.md), this file,
  [`tests/test-levels.md`](tests/test-levels.md), the two `tests/README.md` files,
  [`ci/README.md`](ci/README.md) and
  [`.githooks/README.md`](../.githooks/README.md). Add or remove a check and every one
  can go stale, and a **removed** check leaves its name behind as a linter that no longer
  exists — a `link-lint` run stays green, because it resolves a *link*, not a claim. It is
  silent because the sentence still reads well and the count still looks deliberate: the
  baseline once said `three`, `four` and `five` at once, and named an `agent-entry` linter that
  had been cut. **The check:** when you add or remove a discipline check, grep the whole
  tree for the check-set enumeration — the old name and each spelled count — and reconcile
  every living mirror in the same change; the immutable ADR and archived decision copies
  stay as history.

## 3. Validation — how you check you are not fooling yourself

A result is **untrusted** until it passes the checks below, and the pass is a
recorded event, not a memory. Order the checks cheap-first, so a failure stops the
expensive ones.

| # | Check | Pass condition | Cost |
|---|-------|----------------|------|
| 1 | `gofmt -l` on the tracked Go files except those under `vendor/`, `go build ./...` and `go vet ./...` (the gate script, `R-TEST-05`) | exit 0, and `gofmt` lists no file | seconds |
| 2 | `go test ./...` (unit, contract, store and end-to-end tests, with a local PostgreSQL) | exit 0, no mandatory test skipped | minutes |
| 3 | `go test -race ./...` | exit 0 | minutes |
| 4 | Gate B: the live check of the real KB, the pinned Jev profile and a real LLM | evidence recorded; `blocked` or `unverified` when an input is missing | hours, with credentials and paid calls |
| 5 | Gate C: the quality run, twice, on the frozen labelled set | each floor of section 19 met in each run | hours, with paid calls |

Notes on how to read a failure: rows 1 to 3 are the offline gate (Gate A), the required gate
of `R-TEST-05`, and a failure there is a defect in the change. The script of that gate is not in
this repository yet, and the gate jobs of the Go stack in `docs/gates.tsv` are not that script.
Rows 4 and 5 need credentials and paid calls, so they run once for each release
profile, and again when a decision model, a threshold, a core prompt, a summary policy or
a generation model changes (`R-QUAL-08`); a `blocked` or `unverified` result is reported as
such, never as a pass (`R-TRACE-03`).

**The automated gate is this validation layer, mechanized.** The cheap, always-on
checks — the [discipline linters](engineering-discipline.md#testing) the baseline
ships (ADR, PRD and link) and their
[fixture self-tests](engineering-discipline.md#testing), the
[test levels](engineering-discipline.md#testing), lint, a security
scan, and the [commit-format](engineering-discipline.md#commit-messages)
check — run in the [`pre-commit` hook](engineering-discipline.md#git-hooks) for
fast local feedback and in [CI](engineering-discipline.md#continuous-integration)
as the authority. Treat those checks as pre-registered pass/fail rules under
section 1: they predate any single result and are not edited to make a change
pass. Wire the "cheap enough to wire into CI" checks from the table above into
both layers. In this repository the lint, test-level and security steps of the hook are comments
and do not run, and the gate jobs of CI are those of the Go stack, not the gate script of
`R-TEST-05`; [Which checks run](onboarding-for-engineers.md#which-checks-run) lists what runs now.

## 4. Mechanics

- **Frozen rules do not get edited.** Changing a guardrail after it is set means a
  new version with a written reason, the old one preserved. Legitimate reasons
  exist (a bug in the measure); silent edits do not.
- **This document holds the structure; the problem statement holds the frozen values.**
  The raw file [`facts/problem-statement-brief.md`](facts/problem-statement-brief.md) and its
  hash in `docs/setup/facts.sha256` are the primary copy; the numbers mirrored here are
  history, after the fact, never the primary copy.

## Sources

The thresholds and the checks come from the problem statement,
[`facts/problem-statement-brief.md`](facts/problem-statement-brief.md): sections 18 to 21 give the
gates and the acceptance, and section 22 lists the technical sources (the RFCs, the TypeSafe AI,
PostgreSQL, Go and provider documentation) that it cites for protocol and platform facts.
