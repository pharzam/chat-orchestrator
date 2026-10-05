# tests/

The home for this project's **product tests** — the tests of your code. It ships
empty on purpose: the baseline is domain-free with no product, so it has no
product tests of its own. The project's unit, integration, and
end-to-end tests go here (or in whatever layout the project's stack expects — this
directory is the default `tests`).

## In plain terms

> Put the tests of your actual code in this folder. It is empty now because the
> template has no code yet. The rules for what to write and how live one folder
> over, in `docs/tests/`.

## Where the conventions live

This directory holds the tests; the **conventions** for writing them live in
[`docs/tests/`](../docs/tests/):

- [`docs/tests/test-levels.md`](../docs/tests/test-levels.md) — the test levels and
  the command placeholders.
- [`docs/tests/template-unit.md`](../docs/tests/template-unit.md),
  [`template-integration.md`](../docs/tests/template-integration.md),
  [`template-e2e.md`](../docs/tests/template-e2e.md) — a pattern to copy per level.
- [`docs/tests/traceability-template.md`](../docs/tests/traceability-template.md) —
  the row that ties each test back to the requirement it proves.

The [discipline tests](../docs/tests/test-levels.md) — the ADR, PRD,
link, PR-link and review-record linters — are not product tests and do
**not** live here; they stay beside the conventions they enforce, under
[`docs/`](../docs/).

> **How to change this directory.** Add the project's product tests here, mirror the
> source layout if that is the convention of the project's stack, and change the `test
> directory›` placeholder in [`docs/tests/test-levels.md`](../docs/tests/test-levels.md)
> and the [hook](../.githooks/pre-commit)/[CI](../docs/ci/) steps to point at it.
> The `.gitkeep` file only exists to keep this empty directory in git — delete it
> once you add a real test.
