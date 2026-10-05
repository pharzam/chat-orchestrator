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

Run from the root of the repository:

```sh
f=docs/onboarding-for-engineers.md; ok=1
grep -F '| Gate jobs `static` and `test` |' "$f" | grep -Fq 'ruleset 24509051' || { echo "A1 FAIL: the row of static and test does not name the ruleset 24509051"; ok=0; }
grep -F '| Gate jobs `layout`, `boundary` and `contract` |' "$f" | grep -Fq 'ruleset 24509051' || { echo "A2 FAIL: the row of layout, boundary and contract does not name the ruleset 24509051"; ok=0; }
p=$(sed -n '/^The ruleset of the setup makes the five gate jobs/,/^$/p' "$f")
for w in 24509051 2026-10-05 read-back; do printf '%s' "$p" | grep -Fq "$w" || { echo "A3 FAIL: the paragraph after the table does not name: $w"; ok=0; }; done
grep -Fq 'Only after the ruleset is applied' "$f" && { echo "A4 FAIL: a cell still says: Only after the ruleset is applied"; ok=0; }
grep -Fq 'Until then, no' "$f" && { echo "A5 FAIL: the paragraph still says: Until then, no check blocks a merge"; ok=0; }
[ "$ok" = 1 ] && echo "assertion: PASS" || { echo "assertion: FAIL"; exit 1; }
```

Red, on the base `cec749a92cc31a07d67cbf7bc74b07dcd85e84ee` (2026-10-05T14:53:08Z), before the change:

```
A1 FAIL: the row of static and test does not name the ruleset 24509051
A2 FAIL: the row of layout, boundary and contract does not name the ruleset 24509051
A3 FAIL: the paragraph after the table does not name: 24509051
A3 FAIL: the paragraph after the table does not name: 2026-10-05
A4 FAIL: a cell still says: Only after the ruleset is applied
A5 FAIL: the paragraph still says: Until then, no check blocks a merge
assertion: FAIL
exit 1
```

Green, on the change (2026-10-05T14:53:25Z):

```
assertion: PASS
exit 0
```

## The local checks

The hooks were installed with `sh .githooks/install.sh` (`core.hooksPath` = `.githooks`, resolved per
working tree). `sh .githooks/pre-commit`, run by hand on the change, exit 0:

```
adr-lint: OK
prd-lint: OK
run-discipline-tests: 81 passed, 0 failed
link-lint: OK  724 links resolved
```

`git diff --check`: no finding.
