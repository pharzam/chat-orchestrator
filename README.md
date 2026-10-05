# The records of this repository

This branch, `layup-records`, holds the records that LAYUP keeps for this
repository. It is an orphan branch: it shares no commit with the default
branch.

Only `layup run` writes this branch from Start on. Its first commit holds the
records of the setup.

Each file is a table of tab-separated values with a header row, or Markdown,
so a person reads it with no tool. A plain `git clone` carries the branch as
`origin/layup-records`.

- `setup/record.tsv`: each value of the setup, with its source, and one done
  row per step.
- `setup/verify.tsv`: the table of `layup setup verify` before the records
  commit.
- `rule-paths.tsv`: the rule-path register: the paths whose change is a change
  of the rules.
