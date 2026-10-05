# 0009. Pin the baseline

Date: 2026-10-05

## Status

Accepted

## Context

This repository started as a copy of a baseline, the repository at
`https://github.com/pharzam/armature`. A copy that names no version of its source cannot be compared
with that source later, and a later change of the source would change what
"the baseline" means.

## Decision

We will pin the baseline at the commit `a95965534b14b0bf14ad74da0c9a45b5f4aedf88`, whose tree is
`8ffb250afd584da8b418bc220fb6d72e802924ce`: the latest commit of its default branch when this repository was
set up. The pin file `docs/setup/armature.pin` holds the source, the commit, the tree,
the method and the date. The root commit of the default branch is the unchanged
copy, and its tree is the pinned tree.

We reject a copy with no recorded version, which no one can compare with its
source.

## Consequences

- A later version of the baseline comes into this repository only by a change
  that names the new commit.
- The pin file and the root commit show the version that this repository
  started from.
