# T-a0rt: evidence

Task `T-a0rt` (issue #2). The change says, in the section "Which checks run" of
`docs/onboarding-for-engineers.md`, that the ruleset of `main` is applied.

## The source: the read-back of the rules of `main`

Read on 2026-10-05 at 14:53:25Z, without a login:

- `GET /repos/pharzam/chat-orchestrator/rulesets`: one ruleset, id 24509051, `layup: the default branch`, `active`.
- `GET /repos/pharzam/chat-orchestrator/rules/branches/main`: `pull_request` (0 approvals, conversation
  resolution required); `required_status_checks`, strict: `boundary`, `contract`, `layout`, `static`, `test`;
  `non_fast_forward`; `deletion`.

## The assertion (test first)

It compares the cells "Blocks a merge" of the two rows of the gate jobs, and the whole paragraph after the
table, with the expected text. So a text that says the opposite fails. Run it from the root of the
repository; set `f` to test another copy of the file:

```sh
f=${f:-docs/onboarding-for-engineers.md}; ok=1
cell() { grep -F "| Gate jobs $1 |" "$f" | awk -F'|' '{ c = $(NF-1); gsub(/^ +| +$/, "", c); print c }'; }
want_cell='Yes, by the ruleset 24509051 (below)'
[ "$(cell '`static` and `test`')" = "$want_cell" ] || { echo "A1 FAIL: the cell 'Blocks a merge' of static and test is not: $want_cell"; ok=0; }
[ "$(cell '`layout`, `boundary` and `contract`')" = "$want_cell" ] || { echo "A2 FAIL: the cell 'Blocks a merge' of layout, boundary and contract is not: $want_cell"; ok=0; }
want_p='The ruleset of the setup makes the five gate jobs the required checks of `main`, and no other check. It is prepared in `docs/setup/branch-protection.json`, and the setup hands its application on GitHub to the Operator (step S13). The five gate jobs block a merge only after the ruleset is applied on GitHub and a read-back of the ruleset confirms it. The Operator applied it on 2026-10-05 as the ruleset `layup: the default branch` (id 24509051), and a read-back of the rules of `main`, without a login, showed the five required checks. Since then, the five gate jobs block a merge.'
got_p=$(sed -n '/^The ruleset of the setup makes the five gate jobs/,/^$/p' "$f" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
[ "$got_p" = "$want_p" ] || { echo "A3 FAIL: the paragraph after the table is not the expected text"; ok=0; }
[ "$ok" = 1 ] && echo "assertion: PASS" || { echo "assertion: FAIL"; exit 1; }
```

| Run | Text | Result |
| --- | --- | --- |
| red | the base `cec749a`, before the change | A1, A2 and A3 fail; exit 1 |
| green | the change | `assertion: PASS`; exit 0 |
| red | the counterexample of review round 1: the cells say "No; ruleset 24509051", and the paragraph says that the ruleset was not applied and that the jobs do not block a merge | A1, A2 and A3 fail; exit 1 |

Review round 1 (on `7f59d87`) found that the first form of the assertion tested words, not the claimed
state: it passed on that counterexample. This form replaces it (cycle 1).

## The local checks

The hooks were installed with `sh .githooks/install.sh` (`core.hooksPath` = `.githooks`, resolved per
working tree). `sh .githooks/pre-commit` on the change, exit 0: adr-lint: OK; prd-lint: OK; run-discipline-tests: 81 passed, 0 failed; link-lint: OK  724 links resolved. `git diff --check`: no finding.
