# F-TB07 — Groundwater Application-Accuracy Contract Testbank Adoption

## Purpose

F-TB07 permanently adopts the already qualified and canonically admitted groundwater application-accuracy contract into the SWAP5 testbank. It does not choose an application accuracy requirement and does not admit production SWAP–MODFLOW coupling.

The source authority remains current canonical `c7379b6b5b5f529ff96de3087379712bd665276a`. F-TB07 changes only testbank support.

## Qualified contract semantics

The admitted runtime/coupler contract supports two quantities of interest:

- groundwater head;
- groundwater drawdown.

For externally qualified, provenance-bound inputs it composes

`H_temporal_budget_cm = H_app_cm * A_temporal`

with finite positive `H_app_cm` and `0 < A_temporal <= 1`.

F-TB07 preserves rather than invents that policy. Missing qualification, missing provenance, invalid values or unsupported QOI fail closed. Each materialization attempt clears any stale model-owned budget before deciding whether a new budget is available.

## Current-canonical model binding

The generic canonical numerical-config carrier deliberately has no universal physical interpretation. The selected reference Richards model owns the native interpretation. Current canonical copies the application budget into its native temporal head budget and normalizes the native head indicator by that budget before publishing the dimensionless temporal certificate.

F-TB07 therefore separates two evidence classes:

1. the exact immutable F-CI44 contract matrix is compiled and executed against current canonical source;
2. current consumer/normalization binding is checked directly on the current post-F-CI45 backend and Richards temporal-indicator source.

The historical F-CI44 admission runner is not replayed literally because its backend blob lock correctly describes its historical postimage and became stale after the later soil-temperature runtime admission. F-TB07 does not rewrite that history.

## Permanent cases

Eight stable cases are registered: head composition, drawdown composition, external qualification/provenance fail-closed behavior, scalar validation, stale-budget clearing, current consumer/normalization binding, repeat/O0-O2 determinism and preservation of the F-GC10 nonclaims.

Profile counts are FAST 3, CANONICAL 7, RELEASE 8 and DEEP 8.

## Hard nonclaims

F-TB07 does not establish a universal head or drawdown accuracy requirement. It does not set numeric `H_app`, numeric `A_temporal`, an application-class accuracy target, a complete coupled-system error budget or production SWAP–MODFLOW admission. Mass conservation remains absolute and cannot be traded against application accuracy.

## Architecture

No production source, reference source, physics, solver, persistent state, coupling window, transaction semantics or mass policy changes. All 30 SWAP architecture invariants are audited in `integration/f-tb/F-TB07_INVARIANT_AUDIT.json`.
