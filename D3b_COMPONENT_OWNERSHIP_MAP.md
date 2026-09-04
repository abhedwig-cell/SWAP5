# D3b component ownership map

**Date:** 2026-09-04

## Goal

Define normative SWAP5 component boundaries so that responsibilities, physical state, shared parameters, worker scratch, execution policy and coupling composition cannot drift back into implicit legacy ownership.

## Result

Status: `COMPLETE_PENDING_PUBLICATION_GATE`

D3b adds `docs/architecture/component-map.md` and makes it part of the Architecture navigation and live publication acceptance gate.

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
6. Deep-vadose transfer remains an optional external component with its own explicit minimal state.
7. Optional functionality incurs persistent state and compute only when active.

## Verification

D3b becomes `PUBLISHED_VERIFIED` when the documentation workflow succeeds through:

1. repository source checks;
2. `mkdocs build --strict`;
3. GitHub Pages deployment;
4. live verification of `architecture/component-map/` including the expected ownership and transaction-boundary text.

## Follow-on

The next migration-oriented step should map legacy SWAP 4.3.1 modules and active refactoring units onto these target components without assuming one-to-one correspondence.
