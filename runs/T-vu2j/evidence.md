# The evidence of T-vu2j

Task `T-vu2j` ([#6](https://github.com/pharzam/chat-orchestrator/issues/6)): the runs before this file, in their order. A commit cannot hold the result of a check on itself, so the runs of the check on the frozen head, after the close-out and on the merge commit are in `runs/T-evad/tree-equal.txt` of pharzam/layup, and on #6.

## 1. Red: the check before the copy

Both runs read only commits of a fresh clone, before `port.sh` made the worktree and the copy. Both fail, as the plan says: the base lacks the 16 paths of the second run, the two files of the task and its line; `layup-setup-2` drops the change of `T-a0rt`.

```
# tree-equal.sh of pharzam/layup at 22479eb (sha256 562a6b929fb27f84233bddbb4738f81836e3a39f0d914fda22f238025266c753); 2026-10-06T09:03:04Z
$ sh tree-equal.sh CLONE 7d7b3878606c536073bea15a8fbd39ca9d4196c0 e2b402b9e01804ac3c337148be8701034580c8ab --base 7d7b3878606c536073bea15a8fbd39ca9d4196c0 --task-file docs/tasks/T-vu2j.md --evidence-file runs/T-vu2j/evidence.md --log-line --issue pharzam/chat-orchestrator#6
tree-equal: head 7d7b3878606c536073bea15a8fbd39ca9d4196c0 against layup-setup-2 e2b402b9e01804ac3c337148be8701034580c8ab, base 7d7b3878606c536073bea15a8fbd39ca9d4196c0
tree-equal: the files of the task: docs/tasks/T-vu2j.md and runs/T-vu2j/evidence.md
FAIL: .githooks/README.md (M)
FAIL: docs/adr/0009-pin-the-baseline.md (M)
FAIL: docs/ci/README.md (M)
FAIL: docs/engineering-discipline.md (M)
FAIL: docs/facts/F-0001-setup-answers.md (M)
FAIL: docs/facts/F-0002-marker-answers.md (M)
FAIL: docs/facts/README.md (M)
FAIL: docs/issue-workflow.md (M)
FAIL: docs/setup/armature.pin (M)
FAIL: docs/setup/facts.sha256 (M)
FAIL: docs/setup/open-gaps.tsv (M)
FAIL: docs/tasks/backlog.md (M)
FAIL: docs/tests/scaling-checklist.md (M)
FAIL: docs/tests/security-checklist.md (M)
FAIL: docs/tests/test-levels.md (M)
FAIL: tests/README.md (M)
T-a0rt: docs/onboarding-for-engineers.md as in the base
T-a0rt: docs/tasks/T-a0rt.md as in the base
T-a0rt: runs/T-a0rt/evidence.md as in the base
FAIL: T-a0rt: docs/tasks/completed.md has no line of T-vu2j
FAIL: docs/tasks/T-vu2j.md: the task file is not in the head
FAIL: runs/T-vu2j/evidence.md: the evidence file is not in the head
tree-equal: FAIL (findings: 19)
exit 1
$ sh tree-equal.sh CLONE e2b402b9e01804ac3c337148be8701034580c8ab e2b402b9e01804ac3c337148be8701034580c8ab --base 7d7b3878606c536073bea15a8fbd39ca9d4196c0 --task-file docs/tasks/T-vu2j.md --evidence-file runs/T-vu2j/evidence.md --log-line --issue pharzam/chat-orchestrator#6
tree-equal: head e2b402b9e01804ac3c337148be8701034580c8ab against layup-setup-2 e2b402b9e01804ac3c337148be8701034580c8ab, base 7d7b3878606c536073bea15a8fbd39ca9d4196c0
tree-equal: the files of the task: docs/tasks/T-vu2j.md and runs/T-vu2j/evidence.md
FAIL: T-a0rt: docs/onboarding-for-engineers.md differs from the base
FAIL: T-a0rt: docs/tasks/T-a0rt.md is not in the head
FAIL: T-a0rt: runs/T-a0rt/evidence.md is not in the head
FAIL: T-a0rt: docs/tasks/completed.md differs from the base, and it has no line of T-vu2j
FAIL: docs/tasks/T-vu2j.md: the task file is not in the head
FAIL: runs/T-vu2j/evidence.md: the evidence file is not in the head
tree-equal: FAIL (findings: 6)
exit 1
```

## 2. The copy

```
# port.sh (sha256 23123d1723f2f252b3d9bcaf2061efb183b75c991cd598488a3e0f2c7117fe2c); 2026-10-06T09:03:14Z
$ sh port.sh CLONE T-vu2j 7d7b3878606c536073bea15a8fbd39ca9d4196c0 e2b402b9e01804ac3c337148be8701034580c8ab cec749a92cc31a07d67cbf7bc74b07dcd85e84ee
port: step 1 of 6: fetch main and layup-setup-2 from origin (09:03:14Z)
port: step 2 of 6: check the commit IDs (09:03:14Z)
port: step 3 of 6: check that the second run did not change a path of T-a0rt (09:03:14Z)
port: step 4 of 6: make the worktree /Users/farzam/layup-pilot/t7/chat-orchestrator/.worktree/T-vu2j on the branch T-vu2j, off origin/main (09:03:15Z)
port: step 5 of 6: install the hooks of the target, and check them (09:03:15Z)
install.sh: core.hooksPath set to '.githooks' — the hooks in .githooks/ now run on commit.
port: step 6 of 6: read the tree of the second setup head, and take the four paths of T-a0rt from the base (09:03:15Z)
port: the change is staged in /Users/farzam/layup-pilot/t7/chat-orchestrator/.worktree/T-vu2j; the paths that differ from the base:
M	.githooks/README.md
M	docs/adr/0009-pin-the-baseline.md
M	docs/ci/README.md
M	docs/engineering-discipline.md
M	docs/facts/F-0001-setup-answers.md
M	docs/facts/F-0002-marker-answers.md
M	docs/facts/README.md
M	docs/issue-workflow.md
M	docs/setup/armature.pin
M	docs/setup/facts.sha256
M	docs/setup/open-gaps.tsv
M	docs/tasks/backlog.md
M	docs/tests/scaling-checklist.md
M	docs/tests/security-checklist.md
M	docs/tests/test-levels.md
M	tests/README.md
port: done; 16 paths differ from the base
exit 0

# the commit of the copy, with the hooks of the target; 2026-10-06T09:03:22Z
adr-lint: OK
prd-lint: OK

run-discipline-tests: 81 passed, 0 failed
link-lint: OK  727 links resolved
[T-vu2j ced82d1] chore: T-vu2j copy the tree of the second setup run, with the change of T-a0rt (port.sh)
 16 files changed, 155 insertions(+), 145 deletions(-)
exit 0
```

The binary of the second setup run (all its steps; evidence 110 to 113 of the pilot): `layup5`, built by go1.27.1 from `006fbeeb4972d3e94da5a3f4600bb946b72a6986` of pharzam/layup (branch `T-evad`), `vcs.modified=true`, SHA-256 `3286c72da748411c10e10cb0ae0b4f447a4deac23c55e623d0a25aec43f5ef60`. Its worktree held one untracked file, and one untracked file sets `vcs.modified=true` (evidence 141 of the pilot). No Go file differs between `006fbee` and the head of `T-evad`. A change of a tracked file at the time of the build is not ruled out.

## 3. The clause-by-clause pass of the 16 copied paths

Each changed clause of the copy, against its source: the baseline text at `a959655`, the answers on [#1](https://github.com/pharzam/chat-orchestrator/issues/1) (comments 5995217834 and 6010563347), and the prose of the second run that the idea owner approved (pharzam/layup#97, comment 6010634567).

| Path | What changes | Source | Holds |
| --- | --- | --- | --- |
| `.githooks/README.md` | the lint step is named `format check and go vet` | `M-2e44ba0f`, 6010563347 | yes |
| `docs/ci/README.md` | the marker &lsaquo;security scanner&rsaquo; is back, as a gap | `M-028e8571`, `M-1f5c33ee`, 6010563347 | yes |
| `docs/engineering-discipline.md` | a paragraph of the values that have no file; the markers of the two model tiers, of the test commands and of the harness are back, as gaps; "fill" becomes "serve" | the approved prose; `M-7bbbccd9`, `M-8e4a74ae`, `M-b259db85`, `M-d0cfb752`, `M-bcb0a256`, `M-65928152` | yes |
| `docs/issue-workflow.md` | the task-ID scheme is filled two times; the "required" cells of the rows R1 and pr-link are filled | `M-c7a6dcec`, `M-538d3dcd`, `M-0690d23a` | yes |
| `docs/tasks/backlog.md` | the marker over four lines is replaced whole (V-040) | `M-512dcd69`, 6010563347 | yes |
| `docs/tests/scaling-checklist.md`, `security-checklist.md` | the markers &lsaquo;test timeout&rsaquo;, &lsaquo;security scanner&rsaquo; and &lsaquo;security test command&rsaquo; are back, as gaps | the approved prose; the gap rows | yes |
| `docs/tests/test-levels.md`, `tests/README.md` | the test directory is filled as `tests` | `M-6f558ed8`, `M-b0381356`, 6010563347 | yes |
| `docs/setup/open-gaps.tsv` | the rows of the gaps follow the markers above | the record of S10 and S11 on `layup-records-2` | yes |
| `docs/facts/F-0001-*.md`, `F-0002-*.md`, `docs/adr/0009-*.md`, `docs/facts/README.md`, `docs/setup/facts.sha256`, `docs/setup/armature.pin` | the records and the dates of the second run: 14 answers in, 6 out, the facts numbered again | the exception of O-148, as O-151 scoped it and O-154 extended it | yes |

The history, the index of facts and the pin, against the real history:
- **The pin.** `armature.pin` gives the commit `a959655`, the tree `8ffb250` and the date of the second run. The root commit of `main` is `242a205` (2026-10-05, the first run), with the same tree `8ffb250`. The version agrees, and the dates differ by O-151.
- **The index of facts.** It gives 2026-10-06 for the three records. The brief keeps its own date (2026-10-04) and its hash (line 2 of `facts.sha256` does not change).
- **The branches of the setup.** `docs/engineering-discipline.md:20` and `README.md:62` name the branches `layup-setup` and `layup-records`. After the copy, the record of `main` is on `layup-records-2`. By O-152 (pharzam/layup#97, comment 6013939366), the branches follow the text: after the merge, `t7-3.sh` makes `layup-records-1` at `2a339bb`, moves `layup-records` to `8bc105c` and makes `layup-setup` at `e2b402b`. The text does not change.

Notes, not material:
- `tests/README.md` calls the filled value `tests` "the placeholder".
- `docs/engineering-discipline.md:22` names the steps of the hook, and the steps of the hook are comments that do not run.
- The Status cell of the row R1 of `docs/issue-workflow.md` is stale (#3), and this task does not change it.
