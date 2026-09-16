# SWAP5 technical documentation

This site documents the SWAP5 rebuild: its scientific/reference foundations, admitted Status-A baseline, current software architecture, verification evidence, and the historical material needed to understand how the model reached that state.

## Start here

If you want a practical repository entry point first, use [Getting started: build, run, input and output](getting-started.md). It documents the supported documentation build, the admitted minimal application-host exercise, and—equally important—where the repository does **not yet** claim a broad stable end-user CLI or replacement input/output grammar.

## Reviewing SWAP5

If you are reviewing the rebuild, start with the [SWAP5 review guide](review/REVIEW_GUIDE.md). It provides separate reading routes for scientific reviewers, numerical/software reviewers, model users and a full technical review.

The first colleague-review package uses a **frozen scientific denominator** rather than a moving development head. See the [frozen review baseline](review/REVIEW_BASELINE.md) for the exact Status-A and production authorities and for the separation between the review object and ongoing post-Status-A development.

The review is intended to make the following chain inspectable:

```text
scientific theory / contract
        |
        v
production implementation
        |
        v
qualification evidence
        |
        v
canonical admission
        |
        v
permanent preservation
```

## Current Status-A authority

For present-state questions about the admitted Status-A baseline, start here:

- [SWAP5 Status-A current status](status-a/CURRENT_STATUS.md)
- [Current Status-A architecture](status-a/CURRENT_ARCHITECTURE.md)
- [Theory, code and evidence traceability](status-a/TRACEABILITY.md)
- [Status-A capability review pages](capabilities/index.md)
- [Deliberate future scope](status-a/FUTURE_SCOPE.md)
- [Documentation reconciliation matrix](status-a/DOCUMENTATION_RECONCILIATION_MATRIX.md)

The frozen first-review scientific authority is Status-A commit `992a5c657bfe10a10100f92e0cb77c4825ae65b6`. The pinned scientific production baseline is `50346642bd565f79134ea17d5462e544b354998c` with production tree `3b085d7dea3d3f3fce42ad9d8f259a8350205846`.

!!! warning "Frozen review baseline versus ongoing development"
    SWAP5 development continues after Status-A. The review portal therefore distinguishes the frozen scientific review denominator from later canonical development. A later documentation snapshot may explain the frozen baseline, but post-Status-A capability work is not silently added to the scientific review claim.

!!! warning "Current status versus historical target material"
    Several architecture and migration pages were written before the 2026-09-16 Status-A closure. They remain useful design and migration evidence, but older `TARGET`, `PARTIAL`, `IN_PROGRESS` or similar labels must not be used to override the current Status-A acceptance authority. Pages that are target-design or historical snapshots are marked as such.

## Documentation layers

The review portal is being organized around the following layers:

1. **Getting started** records only build/run/input/output paths that are actually supported by repository authority, and records gaps instead of inventing a public interface.
2. **Review baseline** identifies exactly what colleagues are being asked to review and gives role-specific reading routes.
3. **Scientific model** explains the conceptual model, physical assumptions, state variables, process equations, boundaries and balances. This narrative layer is being expanded in F-DOC20 from existing theory/code/evidence authorities.
4. **Status-A capability pages** explain the admitted boundaries of Restart, serialized MultiSWAP, Drainage, WOFOST runtime, restricted Snow and Groundwater Coupling v1.
5. **Numerical formulation** explains discretisation, nonlinear solution, timestep control, retry/rollback and numerical acceptance. This narrative layer is being expanded in F-DOC20 without changing numerical semantics.
6. **Current Status-A** records the admitted capability boundary, actual ownership model, distributed authority map and deliberate future scope.
7. **Architecture** contains current ownership/invariant material plus explicitly identified historical target-design material.
8. **Verification** records correctness, conservation, numerical, restart, MultiSWAP and preservation evidence.
9. **Legacy** describes SWAP 4.3.1, its reference role, file-oriented interfaces and migration constraints.
10. **Development** explains repository workflow, qualification discipline and documentation publication.

Architecture Decision Records preserve the rationale for important choices. Qualification, integration and testbank records preserve the evidence for bounded capability decisions. No single historical page should be treated as a substitute for the complete authority chain.

## Status-A at a glance

The admitted architecture separates process/solver calculation from transactional acceptance. Committed state is authoritative; candidate trial state is tentative until accepted; scratch/workspace is non-persistent. Restart v1, serialized MultiSWAP v1, bounded WOFOST runtime, restricted one-call-daily Snow, Groundwater Coupling v1 and the admitted external groundwater gateway are documented according to their bounded scope, not according to broader future design intent.

The [current status page](status-a/CURRENT_STATUS.md) lists the documentation-level Status-A boundary and the [traceability map](status-a/TRACEABILITY.md) explains how to reach capability-specific scientific, implementation, qualification, canonical-admission and preservation evidence.

## Historical and target architecture

The repository retains target architecture and migration documents because they explain design intent and past decisions. They are not deleted merely because implementation advanced. Use the [target architecture overview](architecture/overview.md), [target component ownership map](architecture/component-map.md) and historical [2026-09-04 implementation-status snapshot](architecture/implementation-status.md) in that context.

The normative rules that remain relevant across current and target material are recorded in the [core architecture invariants](architecture/invariants.md). Accepted design choices are recorded as [Architecture Decision Records](decisions/index.md).

## Documentation maintenance

Documentation is version controlled with the source. Material changes to scientific contracts, state ownership, runtime, restart, MultiSWAP, coupling, module boundaries or qualification authority should update the relevant current documentation and evidence links.

Documentation changes are checked through the repository documentation workflow. See [Documentation workflow](development/documentation.md) and [GitHub Pages publication](development/publication.md).
