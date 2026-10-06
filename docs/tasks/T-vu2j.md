# T-vu2j: take the tree of the second setup run into `main`

Issue [#6](https://github.com/pharzam/chat-orchestrator/issues/6). The commit `ced82d1` copies the tree of `layup-setup-2`
(`e2b402b`, the second setup run) into `main`, with the four paths of `T-a0rt` as the base `7d7b387` has them. The
script `port.sh` of the pilot (pharzam/layup#97) made it; no text of the copy is written by hand. The evidence is
[`runs/T-vu2j/evidence.md`](../../runs/T-vu2j/evidence.md).

## Decision notes

- **O-148, as O-151 scoped it.** For this task only, the copy replaces `F-0001`, `F-0002` and `ADR-0009` with the
  versions of the second run. This is an exception to the immutability rules of `docs/facts/README.md` and
  `docs/adr/README.md`. The versions of the second run are authoritative. The versions of the first run are superseded,
  and they stay in the history of `main` at `cec749a`: [`F-0001`](https://github.com/pharzam/chat-orchestrator/blob/cec749a92cc31a07d67cbf7bc74b07dcd85e84ee/docs/facts/F-0001-setup-answers.md),
  [`F-0002`](https://github.com/pharzam/chat-orchestrator/blob/cec749a92cc31a07d67cbf7bc74b07dcd85e84ee/docs/facts/F-0002-marker-answers.md) and [`ADR-0009`](https://github.com/pharzam/chat-orchestrator/blob/cec749a92cc31a07d67cbf7bc74b07dcd85e84ee/docs/adr/0009-pin-the-baseline.md). From
  the merge on, the immutability rules apply to the versions of the second run.
- **O-149.** Each frozen head gets one review round with four lenses (semantic agreement, one reading, the
  acceptance criteria, an adversarial hunt), inside the cycle cap of 2. This is a workaround under R4: two operators
  approve it on #6, and #4 is its removal issue.
- **O-150.** The task adds two files of its own: this file and its evidence.
- **O-152.** `docs/engineering-discipline.md:20` and `README.md:62` name the branches `layup-setup` and
  `layup-records`. After the copy, the steps and the record of `main` are those of the second run. So after the merge,
  `t7-3.sh` makes `layup-records-1` at `2a339bb` (the record of the first run), moves `layup-records` to `8bc105c` and
  makes `layup-setup` at `e2b402b`, with the Operator's login and authorization. The text does not change.

## Before the copy, and gate step 7

The author read [`docs/guardrails.md`](../guardrails.md), [ADR-0007](../adr/0007-record-task-resource-use.md) and
[ADR-0009](../adr/0009-pin-the-baseline.md). "A filled value read as a running check": the pass of the evidence checks
each changed clause of the hook and CI texts. "An absolute `core.hooksPath`": `port.sh` sets `.githooks` and checks it.
"A check that cannot fail": the check failed first (the red runs), and its tests have mutations. The brief and its
hash do not change (section 4); the pin keeps the commit and the tree (ADR-0009). Stale documents: the pass of the
evidence, and O-152. No entry in §2 of the guardrails: the lesson of the lost markers belongs to the setup of LAYUP,
and it is in §2 of LAYUP's guardrails; a reader of this repository does not run that setup.

## Verdict

Written at the close-out, after the last review round.

## Resource record (ADR-0007: recorded, not budgeted)

Written at the close-out, after the last review round.
