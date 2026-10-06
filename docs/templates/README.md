# Forge templates (inert)

Issue and pull/merge-request templates that embody the [issue-first
workflow](../issue-workflow.md) — single-goal scope (R11), the duplicate check
(R2), solution selection (R3), and the action/why/tradeoff comment (R7).

**These are inert here on purpose.** An issue or PR template changes the live forge
interface the moment it lands, so the baseline does not activate one — it stays
forge-free. A project opts in by copying the set its forge uses into the place it
expects. Each marker in these files is a field of a new issue or pull/merge request.

## Activate

**GitHub:**

```bash
mkdir -p .github/ISSUE_TEMPLATE
cp docs/templates/github/ISSUE_TEMPLATE/task.md   .github/ISSUE_TEMPLATE/
cp docs/templates/github/PULL_REQUEST_TEMPLATE.md .github/
```

**GitLab:**

```bash
mkdir -p .gitlab/issue_templates .gitlab/merge_request_templates
cp docs/templates/gitlab/issue_templates/Task.md            .gitlab/issue_templates/
cp docs/templates/gitlab/merge_request_templates/Default.md .gitlab/merge_request_templates/
```

The GitHub issue template carries a small metadata header (`name`, `about`,
`labels`) the forge reads; the GitLab files are plain Markdown. Delete a template
the project does not use.

> Not to be confused with this repository's per-record templates — [`adr/template.md`](../adr/template.md),
> [`facts/template.md`](../facts/template.md), [`prd/template.md`](../prd/template.md) —
> which are copied *inside* their own directories, not into a forge path.
