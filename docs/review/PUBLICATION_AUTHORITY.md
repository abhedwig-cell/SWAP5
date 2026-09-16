# Frozen review publication authority

Date: 2026-09-16

This page defines how the first SWAP5 colleague-review portal may be published without confusing a moving repository branch with the frozen scientific review denominator.

## Two authorities, two purposes

The published review site must always distinguish:

1. **Scientific review authority** — what scientific/runtime baseline colleagues are reviewing.
2. **Documentation publication authority** — the exact documentation revision that was built and deployed to explain that baseline.

For the first review package, the frozen scientific authority is:

- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`

The documentation may be newer than those scientific commits because documentation reconciliation itself does not change the frozen scientific postimage.

## Publication source

The first review site is published only from the dedicated branch:

```text
publication/status-a-review-20260916
```

This branch is a **publication surface**, not a development workstream. Feature/scientific work must not be performed there.

The exact documentation revision for a deployment is the `GITHUB_SHA` of the successful `Documentation` workflow run on this publication branch. F-DOC20 closeout records that SHA and the successful external verification run. A later repository head does not silently become the published review authority.

## Materialization record

This revision was created specifically to materialize the first frozen Status-A colleague-review publication surface. The materialization commit itself is the candidate documentation publication postimage; it is accepted only after its own build, Pages deployment and external verification succeed.

The page intentionally does not contain its own Git SHA. That exact SHA is taken from the immutable workflow execution context and persisted in F-DOC20 closeout evidence, avoiding a self-referential documentation commit.

## Why `main` is not the authority

`main` is not the current SWAP5 scientific/review authority. Deploying Pages automatically from `main` would therefore allow a stale or unrelated branch to be presented as the current review portal.

The documentation workflow consequently validates pull requests but deploys only when the dedicated review-publication branch is updated.

## Publication admission

A publication revision is accepted only when all of the following hold:

1. repository documentation checks pass on the exact publication revision;
2. `mkdocs build --strict` passes on that revision;
3. the GitHub Pages deployment succeeds from `publication/status-a-review-20260916`;
4. the external publication verifier succeeds against the reported Pages URL;
5. F-DOC20 records the publication commit, workflow run and verification result;
6. the published site still identifies the frozen scientific Status-A and production authorities above.

Failure of any item blocks publication admission. It does not authorize a documentation workaround that broadens scientific claims or changes production semantics.

## Change policy

If the review documentation needs correction after publication, make and qualify the correction on the documentation workstream first. Updating the publication branch is then an explicit publication decision and creates a new exact documentation authority.

Scientific scope changes require a new scientific acceptance/review decision; they are not smuggled into the existing frozen review package by editing documentation.

## Relationship to later development

Post-Status-A code and capability development can continue independently. The first review portal remains a view onto its frozen scientific denominator until a later review baseline is explicitly declared.