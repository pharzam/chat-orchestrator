# T-vu2j: take the tree of the second setup run into `main`

Issue [#6](https://github.com/pharzam/chat-orchestrator/issues/6). On this branch, the commit `ced82d1` copies the tree of
`layup-setup-2` (`e2b402b`), with the four paths of `T-a0rt` as the base `7d7b387` has them; the merge of this branch
will take it into `main`. `port.sh` of the pilot (pharzam/layup#97) staged the copy, and the author committed it with the hooks. No text of the copy is written by hand. The evidence is [`runs/T-vu2j/evidence.md`](../../runs/T-vu2j/evidence.md).

## Decision notes

- **O-148, as O-151 scoped it, and O-154** (#6, comment 6014917221). For this task only, the copy replaces six records with
  the versions of the second run, an exception to the immutability rules of `docs/facts/README.md` and `docs/adr/README.md`.
  The versions of the second run are authoritative. Those of the first run are superseded, and they stay at `cec749a`:
  [`F-0001`](https://github.com/pharzam/chat-orchestrator/blob/cec749a92cc31a07d67cbf7bc74b07dcd85e84ee/docs/facts/F-0001-setup-answers.md), [`F-0002`](https://github.com/pharzam/chat-orchestrator/blob/cec749a92cc31a07d67cbf7bc74b07dcd85e84ee/docs/facts/F-0002-marker-answers.md), [the index of facts](https://github.com/pharzam/chat-orchestrator/blob/cec749a92cc31a07d67cbf7bc74b07dcd85e84ee/docs/facts/README.md),
  [`facts.sha256`](https://github.com/pharzam/chat-orchestrator/blob/cec749a92cc31a07d67cbf7bc74b07dcd85e84ee/docs/setup/facts.sha256), [`armature.pin`](https://github.com/pharzam/chat-orchestrator/blob/cec749a92cc31a07d67cbf7bc74b07dcd85e84ee/docs/setup/armature.pin) (`date=`) and [`ADR-0009`](https://github.com/pharzam/chat-orchestrator/blob/cec749a92cc31a07d67cbf7bc74b07dcd85e84ee/docs/adr/0009-pin-the-baseline.md) (`Date:`).
  Their record is `setup/record.tsv` at `2a339bb` (`layup-records`, then `layup-records-1` by O-152). From the merge on,
  the immutability rules apply to the versions of the second run.
- **O-149.** One review round on each frozen head, with the four lenses, inside the cycle cap (2 in the plan review, 3
  from O-156, 4 from O-157): a workaround under R4, which two operators approve on #6; #4 is its removal issue.
- **O-150.** The task adds two files of its own: this file and its evidence.
- **O-152.** `docs/engineering-discipline.md:20` and `README.md:62` name the branches `layup-setup` and `layup-records`.
  After the merge, `t7-3.sh` will make `layup-records-1` at `2a339bb`, move `layup-records` to `8bc105c` and make
  `layup-setup` at `e2b402b`, with the Operator's login and authorization, so that the text holds without a change.
- **O-156, O-157** (pharzam/layup#97, comments 6016940589, 6018174925). Rounds 3 and 4 found material defects at the
  caps of 2 and 3; each time the Operator raised the cap by one, for one more fix cycle, test first, and one round.

**The binary of the second run, and the review of T-evad** (#6, comment 6014917221). The evidence records the binary.
If the review of T-evad (pharzam/layup#97) changes fixes 1 to 3, a setup run with the merged binary, from the same
inputs, must give a setup head whose tree equals the tree of `layup-setup-2`, except the values that come from
`pin.time`: the dates of `armature.pin`, `ADR-0009`, `F-0001`, `F-0002` and the index of facts, and the two hashes of
`facts.sha256` that cover `F-0001` and `F-0002`. If it does not, this task opens again.

**Open items, not material** (#6, comment 6014917221): the notes of the pass in the evidence, and
`docs/engineering-discipline.md:22`, which names steps of the hook that are comments and do not run.

## Before the copy, and gate step 7

The author read [`docs/guardrails.md`](../guardrails.md), [ADR-0007](../adr/0007-record-task-resource-use.md) and
[ADR-0009](../adr/0009-pin-the-baseline.md). The pass of the evidence meets "a filled value read as a running check";
`port.sh` sets and checks a relative `core.hooksPath`; the check failed first, and its tests have mutations. The brief
and its hash do not change. Stale documents: the pass of the evidence, and O-152. No entry in §2: the lesson of the
lost markers is in §2 of LAYUP's guardrails on LAYUP's branch `T-evad` (commit `52a06eb`; that branch is not merged
into LAYUP's `main` yet), and a reader of this repository does not run that setup.

## Verdict

Written at the close-out, after the last review round.

## Resource record (ADR-0007: recorded, not budgeted)

Written at the close-out, after the last review round.
