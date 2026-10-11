# SWAP5 frozen review baseline

## Review object

The first colleague review package is based on the admitted SWAP5 Status-A scientific baseline rather than on a moving development head.

### Scientific authority

- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`

### Documentation assembly source

The F-DOC20 review-portal workstream starts from current canonical:

- canonical branch: `integration/f-ci-canonical`
- start head: `6531dae99e5f1cc0cd6d4fadc5c633f0ccece404`
- start tree: `49fb62d3a28a2a06837f56d636e5ff751b86816d`

The later canonical head is used to assemble and publish current documentation, but it does not broaden the frozen scientific Status-A review denominator automatically.

## Why freeze the scientific review denominator

SWAP5 development continues after Status-A. A moving canonical branch is therefore a poor object for a long-form colleague review: reviewers could otherwise read different scientific states on different days.

The review portal separates:

1. the frozen scientific baseline being reviewed;
2. current documentation and governance that explain that baseline;
3. post-Status-A work that is informative but outside the first frozen review denominator.

## Primary review claims

The package will support review of the following bounded claims:

- the rebuild has an explicit scientific/reference preservation chain;
- admitted Status-A processes and numerical behaviour are backed by capability-specific qualification evidence;
- transactional state ownership separates committed, candidate and scratch/workspace state;
- restart and serialized MultiSWAP behaviour are explicitly qualified in their admitted scope;
- admitted groundwater, Snow, WOFOST, drainage and surface-evaporation capabilities are documented according to their bounded authorities;
- future scope is not silently represented as already admitted;
- the repository provides a traceable route from scientific contract to implementation to qualification to admission to preservation.

The review package must not overclaim whole-model equivalence beyond the evidence actually available.

## Publication model

The intended publication model is:

```text
frozen scientific authority
        +
version-controlled documentation
        |
        v
strict documentation qualification
        |
        v
static MkDocs Material site
        |
        v
GitHub Pages review portal
```

The existing repository publication workflow currently deploys only from `main`. F-DOC20 must reconcile this with the actual current-canonical / frozen-review authority before publication. The review site must not silently publish stale `main` documentation as current SWAP5 authority.

## Review-version naming

The first published colleague-review snapshot should receive a stable review identifier such as:

`SWAP5 Status-A Review Baseline 2026-09`

The exact release/tag mechanism is an F-DOC20 publication decision. Once frozen, the identifier, git authority and publication URL must be shown together on the review portal.

## Out of scope for the first frozen review denominator

Unless later explicitly added before freeze, ongoing post-Status-A development is not part of the first scientific review denominator. This separation is intended to let colleagues perform a stable review while new capabilities continue to develop.
