# D3b component ownership map

**Date:** 2026-09-04

> **Historical target-design record, not current Status-A ownership authority.** This file remains valid evidence of the 2026-09-04 target component-map publication. For actual ownership and execution boundaries admitted at the 2026-09-16 Status-A boundary, use `docs/status-a/CURRENT_ARCHITECTURE.md`. The target design below is preserved because it may still inform future migration work, but unadmitted target components or modes must not be presented as current functionality.

## Goal

Define normative SWAP5 target component boundaries so that responsibilities, physical state, shared parameters, worker scratch, execution policy and coupling composition could not drift back into implicit legacy ownership during migration.

## Result

Status: `PUBLISHED_VERIFIED`

D3b added `docs/architecture/component-map.md` and made it part of the Architecture navigation and live publication acceptance gate for the target architecture.

The target map distinguishes these responsibilities:

- Public API;
- legacy/external adapters;
- runtime/execution manager;
- coupler;
- kernel interval executor;
- surface/atmospheric physics;
- crop/ET/root-uptake physics;
- drainage/irrigation/optional process physics;
- soil-water solver interface;
- soil-water solver implementation;
- results/diagnostics assembly;
- optional deep-vadose transfer component.

It also defines cross-cutting ownership domains for shared immutable parameters, committed column state, forcing, numerical configuration and worker scratch.

## Key architectural decisions captured

1. The kernel interval executor owns trial computation, not authoritative committed state.
2. Runtime owns execution policy, batching, templates, retry/fallback routing and worker resources, but must not silently alter physics.
3. Solver implementations own numerical algorithms and transient scratch, not committed column state.
4. Other physics modules consume hydraulic information through a solver-independent contract rather than `HeadCalc` internals.
5. The coupler owns MODFLOW relationships, coupling windows, tile fractions, interface residuals and conservative aggregation outside the kernel.
6. Deep-vadose transfer remains an optional external target component with its own explicit minimal state.
7. Optional functionality incurs persistent state and compute only when active in the target design.

These statements describe the target design recorded by D3b. Whether a boundary is implemented/admitted now is answered by the current Status-A architecture and capability evidence, not by D3b alone.

## Verification

The D3b acceptance gate passed in GitHub Actions run `33884693511` for documentation commit `edc94b901505b19c535268af1e2bd0369f677a6e`.

Verified successfully:

1. repository documentation source checks;
2. `mkdocs build --strict`;
3. GitHub Pages deployment;
4. live verification of `architecture/component-map/` including expected ownership and transaction-boundary text.

## Follow-on in historical context

At the time, the next migration-oriented step was to map legacy SWAP 4.3.1 modules and active refactoring units onto these target components without assuming one-to-one correspondence.

Later Status-A work admitted a bounded current architecture that must be documented from its canonical evidence rather than inferred from every element of this broader target map.