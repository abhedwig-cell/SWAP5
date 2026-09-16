# SWAP technical documentation

This site documents the current SWAP5 Status-A baseline, its scientific/reference foundations, its admitted runtime architecture, and the historical/target material that explains how the project reached that baseline.

## Current Status-A authority

For present-state questions, start here:

- [SWAP5 Status-A current status](status-a/CURRENT_STATUS.md)
- [Current Status-A architecture](status-a/CURRENT_ARCHITECTURE.md)
- [Theory, code and evidence traceability](status-a/TRACEABILITY.md)
- [Deliberate future scope](status-a/FUTURE_SCOPE.md)
- [Documentation reconciliation matrix](status-a/DOCUMENTATION_RECONCILIATION_MATRIX.md)

The current Status-A authority is canonical commit `992a5c657bfe10a10100f92e0cb77c4825ae65b6`. The pinned scientific production baseline is `50346642bd565f79134ea17d5462e544b354998c` with production tree `3b085d7dea3d3f3fce42ad9d8f259a8350205846`.

!!! warning "Current status versus historical target material"
    Several architecture and migration pages were written before the 2026-09-16 Status-A closure. They remain useful design and migration evidence, but older `TARGET`, `PARTIAL`, `IN_PROGRESS` or similar labels must not be used to override the current Status-A acceptance authority. Pages that are target-design or historical snapshots are marked as such.

## Documentation layers

The documentation separates the following subjects:

1. **Current Status-A** records the admitted capability boundary, actual ownership model, distributed authority map and deliberate future scope.
2. **Physics/reference material** describes model behaviour and preserved scientific contracts independently of a specific solver or file format.
3. **Architecture** contains both current ownership/invariant material and explicitly identified historical target-design material.
4. **Numerics** describes solver algorithms and numerical policy independently of physical options.
5. **Verification** records correctness, mass conservation, accuracy, performance and preservation evidence.
6. **Legacy** describes SWAP 4.3.1, its reference role, file-oriented interfaces and migration constraints.

Architecture Decision Records preserve the rationale for important choices. Qualification, integration and testbank records preserve the evidence for bounded capability decisions. No single historical page should be treated as a substitute for this authority chain.

## Status-A at a glance

The current admitted architecture separates process/solver calculation from transactional acceptance. Committed state is authoritative; candidate trial state is tentative until accepted; scratch/workspace is non-persistent. Restart v1, serialized MultiSWAP v1, bounded WOFOST runtime, restricted one-call-daily Snow, Groundwater Coupling v1 and the current external groundwater gateway are all described according to their admitted scope, not according to broader future design intent.

The [current status page](status-a/CURRENT_STATUS.md) lists the complete documentation-level Status-A boundary and the [traceability map](status-a/TRACEABILITY.md) explains how to reach capability-specific scientific, implementation, qualification, canonical-admission and preservation evidence.

## Historical and target architecture

The repository also retains target architecture and migration documents because they explain design intent and past decisions. They are not deleted merely because implementation advanced. Use the [target architecture overview](architecture/overview.md), [target component ownership map](architecture/component-map.md) and historical [2026-09-04 implementation-status snapshot](architecture/implementation-status.md) in that context.

The normative rules that remain relevant across current and target material are recorded in the [core architecture invariants](architecture/invariants.md). Accepted design choices are recorded as [Architecture Decision Records](decisions/index.md).

## Documentation maintenance

Documentation is version controlled with the source. Material changes to scientific contracts, state ownership, runtime, restart, MultiSWAP, coupling, module boundaries or qualification authority should update the relevant current documentation and evidence links.

Documentation changes are checked through the repository documentation workflow. See [Documentation workflow](development/documentation.md) and [GitHub Pages publication](development/publication.md).