# SWAP5 review guide

## Purpose

This page is the starting point for scientific, numerical and software review of the SWAP5 rebuild.

The primary review claim is deliberately bounded:

> SWAP5 preserves the admitted scientific behaviour of the SWAP reference baseline while replacing the legacy execution structure with an explicit, testable and transactional architecture.

Reviewers should not have to reconstruct that claim from branch history. This guide provides a route from model theory and scientific contracts to implementation, independent qualification, canonical admission and permanent preservation evidence.

## Frozen review baseline

The first colleague review uses the admitted Status-A scientific boundary:

- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- pinned scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- pinned scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`

See [Frozen review baseline](REVIEW_BASELINE.md) and [Scientific-documentation authority reconciliation](AUTHORITY_RECONCILIATION.md).

The documentation portal may be assembled from a later documentation/governance snapshot, but post-Status-A feature development is not silently added to this scientific review denominator.

## Choose a review route

### Scientific reviewer

Recommended sequence:

1. [Scientific model](../science/index.md)
2. [Conceptual system and boundaries](../science/conceptual-model.md)
3. [Vertical soil-water flow](../science/soil-water-flow.md)
4. [Surface evaporation](../science/surface-evaporation.md)
5. [Current Status-A scope](../status-a/CURRENT_STATUS.md)
6. [Theory, code and evidence traceability](../status-a/TRACEABILITY.md)
7. [SWAP 4.3.1 and SWAP5 equivalence evidence](SWAP431_EQUIVALENCE.md)
8. [Mass-accounting contract](../verification/mass-accounting-contract.md)

Focus on equations, physical assumptions, signs and units, boundary conditions, conservation, process coupling and whether the evidence supports the stated preservation or admitted-evolution claim.

### Numerical / software reviewer

Recommended sequence:

1. [Numerical formulation](../numerics/index.md)
2. [Richards discretisation and nonlinear solve](../numerics/richards-solver.md)
3. [Transactional time stepping and acceptance](../numerics/transactional-time-stepping.md)
4. [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md)
5. [Core invariants](../architecture/invariants.md)
6. [Data ownership](../architecture/data-ownership.md)
7. [Verification principles](../verification/principles.md)
8. [Theory, code and evidence traceability](../status-a/TRACEABILITY.md)

Focus on committed/candidate state separation, retry and rollback, exactly-once commit, restart completeness, MultiSWAP isolation, solver ownership, deterministic execution and numerical preservation.

### Model user

Start with:

1. [Getting started: build, run, input and output](../getting-started.md)
2. [Current Status-A scope](../status-a/CURRENT_STATUS.md)
3. [Scientific model](../science/index.md)
4. [Legacy SWAP 4.3.1 baseline](../legacy/swap-4.3.1-baseline.md)
5. [SWAP 4.3.1 and SWAP5 equivalence evidence](SWAP431_EQUIVALENCE.md)
6. [Current architecture](../status-a/CURRENT_ARCHITECTURE.md)
7. [Deliberate future scope](../status-a/FUTURE_SCOPE.md)

The getting-started page is deliberately bounded: it documents the supported documentation build and admitted practical repository entry points, while recording where no broad stable end-user SWAP5 CLI/API or replacement input/output grammar is yet claimed.

### Full technical review

Use the complete sequence:

`scientific model -> numerical formulation -> architecture -> implementation -> qualification -> admission -> preservation -> legacy equivalence`

The purpose of this route is that a reviewer can move from a scientific statement all the way to the evidence protecting it without needing prior knowledge of workunit names.

## How to read authority

SWAP5 uses distributed evidence rather than one document that is allowed to overrule all others. For an admitted scientific capability, the intended chain is:

```text
scientific theory / contract
        |
        v
production implementation
        |
        v
owner qualification
        |
        v
independent qualification where required
        |
        v
canonical admission
        |
        v
permanent preservation / regression authority
```

Historical design and F-DOC documents remain useful evidence of theory, intent and migration history, but they are not current implementation/status authority when a later canonical admission or Status-A record supersedes them.

## The equivalence claim reviewers should test

The rebuild has strong capability-level reference-preservation evidence. The direct whole-application SWAP 4.3.1/Hupsel campaign has also qualified the legacy long trajectory, but the complete SWAP5 application mapping for that long case is not yet established.

Read [SWAP 4.3.1 and SWAP5 — what equivalence is established?](SWAP431_EQUIVALENCE.md) before using the phrase “same results”. The documentation deliberately distinguishes what is already proven from the stronger whole-application comparison still to be completed.

## What is not a review defect by itself

The Status-A review must not classify deliberate future scope as a defect merely because it is absent. Use [Deliberate future scope](../status-a/FUTURE_SCOPE.md) to distinguish an actual gap from work that was intentionally outside the Status-A denominator.

Post-Status-A experimental or developing capabilities are reviewed separately unless explicitly promoted into a later frozen review baseline.

## Suggested reviewer output

For each material finding, record:

- page / scientific contract;
- code or module involved where applicable;
- finding type: scientific, numerical, architectural, evidence, documentation or usability;
- severity;
- whether the finding contradicts the frozen baseline or concerns future scope;
- supporting evidence;
- recommended next investigation.

Review findings should be actionable and traceable. A statement that something is merely surprising is not yet a defect.

## Review acceptance principle

The review package is ready for colleagues only when:

1. the review baseline is frozen and named;
2. scientific-model and numerical-formulation navigation is complete enough to understand the core model without starting from source code;
3. theory-to-code-to-evidence links exist for the admitted Status-A capabilities;
4. the static site passes the repository documentation checks and `mkdocs build --strict`;
5. the publication source is explicit and cannot silently serve stale `main` as current authority;
6. the published site is externally reachable and passes the repository publication verifier;
7. ongoing post-Status-A development is visibly separated from the frozen review baseline.
