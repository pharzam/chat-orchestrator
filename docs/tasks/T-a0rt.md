# T-a0rt: state that the ruleset of `main` is applied

Issue [#2](https://github.com/pharzam/chat-orchestrator/issues/2). The section "Which checks run" of
`docs/onboarding-for-engineers.md` names the ruleset 24509051 of `main`, applied on 2026-10-05 and read back.
The evidence is [`runs/T-a0rt/evidence.md`](../../runs/T-a0rt/evidence.md).

## Verdict

`nothing material in scope`: review round 2 (cycle 1) on `8b8f897`. Round 1 (cycle 0) on `7f59d87` found one
material defect: the assertion tested words, not the claimed state. The fix is `8b8f897`. Each round applied
four lenses (semantic agreement, one reading, the acceptance criteria, an adversarial hunt), by the decision
note O-143 on issue #2; the written rule asks for more than one round on a frozen head (issue #4). Found off
the path of this task: issue #3 (the Status cell of the R1 row) and issue #4.

## Resource record (ADR-0007: recorded, not budgeted)

| Part | Expected tier | Model | Effort | Tokens | Elapsed |
| ---- | ------------- | ----- | ------ | ------ | ------- |
| the plan and its review | reasoning | Claude Opus 5.5 (plan); GPT-6 Sol, Devin CLI (review) | max; xhigh | not reported | about 5 min; 4 min 44 s |
| the decay review rounds | reasoning | GPT-6 Sol, Devin CLI | xhigh | not reported | 3 min 57 s (round 1); 4 min 40 s (round 2); 12 s (a first try of round 1: a harness error, no record) |
| writing the tests and the code | execution | Claude Opus 5.5 | max | not reported | about 5 min (cycle 0 and the fix of cycle 1) |
| isolate, guardrails, docs, close-out | `—` | Claude Opus 5.5 | max | not reported | about 8 min |
| **Total** | | | | not reported | about 32 min |
