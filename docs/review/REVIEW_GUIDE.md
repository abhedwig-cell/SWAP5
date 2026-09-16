# SWAP5 review guide

## Purpose

This page is the starting point for scientific, numerical and software review of the SWAP5 rebuild.

The primary review claim is deliberately bounded:

> SWAP5 preserves the admitted scientific behaviour of the SWAP reference baseline while replacing the legacy execution structure with an explicit, testable and transactional architecture.

Reviewers should not have to reconstruct that claim from branch history. This guide provides a route from model theory and scientific contracts to implementation, independent qualification, canonical admission and permanent preservation evidence.

## Frozen review baseline

The scientific review baseline is the admitted Status-A boundary:

- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- pinned scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- pinned scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`

The documentation portal may be built from a later documentation/governance snapshot, but later post-Status-A feature development is not silently added to the scientific review denominator. Any later capability included in a future review baseline must be identified explicitly.

## Choose a review route

### Scientific reviewer

Start with:

1. [Current Status-A scope](../status-a/CURRENT_STATUS.md)
2. the scientific-model section of this portal as it is populated;
3. [Theory, code and evidence traceability](../status-a/TRACEABILITY.md)
4. [Reference baselines](../verification/reference-baselines.md)
5. [Mass-accounting contract](../verification/mass-accounting-contract.md)
6. capability-specific qualification evidence.

Focus on equations, physical assumptions, signs and units, boundary conditions, conservation, process coupling and whether the evidence supports the stated equivalence or admitted-evolution claim.

### Numerical / software reviewer

Start with:

1. [Current architecture](../status-a/CURRENT_ARCHITECTURE.md)
2. [Core invariants](../architecture/invariants.md)
3. [Data ownership](../architecture/data-ownership.md)
4. [Transactional time stepping](../decisions/ADR-0002-transactional-time-stepping.md)
5. [Worker-owned scratch](../decisions/ADR-0003-worker-owned-scratch.md)
6. [Verification principles](../verification/principles.md)
7. [Theory, code and evidence traceability](../status-a/TRACEABILITY.md)

Focus on committed/candidate state separation, retry and rollback, exactly-once commit, restart completeness, MultiSWAP isolation, solver ownership, deterministic execution and numerical preservation.

### Model user

Start with:

1. [Current Status-A scope](../status-a/CURRENT_STATUS.md)
2. [Legacy SWAP 4.3.1 baseline](../legacy/swap-4.3.1-baseline.md)
3. [Current architecture](../status-a/CURRENT_ARCHITECTURE.md)
4. [Deliberate future scope](../status-a/FUTURE_SCOPE.md)

The user-facing guide will be expanded during this documentation workstream with explicit build/run, input/output, restart and supported-capability guidance.

### Full technical review

Use the complete sequence:

`scientific model -> numerical formulation -> architecture -> implementation -> qualification -> admission -> preservation -> legacy equivalence`

The final review package will make this sequence navigable without requiring knowledge of historical workunit names.

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

Historical design documents remain useful evidence of intent and migration history, but they are not current authority when a later canonical admission or Status-A record supersedes them.

## What is not a review defect by itself

The Status-A review must not classify deliberate future scope as a defect merely because it is absent. In particular, use [Deliberate future scope](../status-a/FUTURE_SCOPE.md) to distinguish an actual gap from work that was intentionally outside the Status-A denominator.

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
2. the scientific-model and numerical-formulation navigation is complete enough to understand SWAP without starting from source code;
3. theory-to-code-to-evidence links exist for the admitted Status-A capabilities;
4. the public/static site builds with `mkdocs build --strict`;
5. the published site is externally reachable and passes the repository publication verifier;
6. ongoing post-Status-A development is visibly separated from the frozen review baseline.
