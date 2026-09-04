# D3d migration slices and qualification gates

**Date:** 2026-09-04

## Goal

Convert the D3c legacy-to-target map into bounded migration slices with explicit dependency and evidence gates, so implementation can proceed incrementally without broad source rewrites or premature retirement of legacy behaviour.

## Result

Status: `COMPLETE_PENDING_PUBLICATION_GATE`

D3d adds `docs/architecture/migration-slices.md` and makes it part of the Architecture navigation and live publication acceptance gate.

The migration program defines nine slices:

- **M0 Reference shield**;
- **M1 Typed external boundary**;
- **M2 Data ownership split**;
- **M3 Transactional interval execution**;
- **M4 Soil-water solver boundary**;
- **M5 Process-contract extraction**;
- **M6 Coupling kernel contract**;
- **M7 MultiSWAP runtime and scalable storage**;
- **M8 Legacy retirement**.

## Key decisions captured

1. Slices are architectural seams and qualification gates, not releases or one-to-one module rewrites.
2. M1 and M2 may overlap; M3 and M4 may also advance in parallel, but M4 cannot claim end-to-end qualification until the M3 transaction seam is stable.
3. Coupling requirements constrain M3 and M4 from the beginning. M6 qualifies the combined external coupling contract rather than adding coupling late.
4. M5 is explicitly family-by-family so surface, drainage, crop/ET, macropore, thermal/frost and transport physics are not forced into one broad rewrite.
5. M7 introduces MultiSWAP batching/layout only after ownership and component contracts are stable, so layout optimisation cannot silently change physics.
6. M8 removes legacy globals/control paths only after all retained behaviour passes the relevant reference, mass-balance and invariant gates.
7. Every exit gate requires evidence containing baseline, affected invariants, cases, state/flux tolerances, water balance, solver route, coupling/sensitivity evidence where relevant, cost and known limitations.

## Alignment with active work

The current project work maps as follows without changing the broader implementation-status claims:

- transaction controller, attempt status, retry policy and extraction from `swap.f90` -> **M3**;
- state classification and removal of redundant persistent copies -> **M2 + M3**;
- systematic `headcalc` global-state/hydraulic dependency extraction -> **M2 + M4**;
- existing API/coupler testbanks -> evidence input for **M6**, not yet an M6 exit;
- qualified solver/audit baselines -> evidence input for **M0/M4**, not automatic capability qualification.

## Publication gate

D3d becomes `PUBLISHED_VERIFIED` only when the Documentation workflow passes:

1. repository source/link/navigation checks;
2. `mkdocs build --strict`;
3. GitHub Pages deployment;
4. live verification of `architecture/migration-slices/` including M3, M4 and the gate-evidence record.

## Follow-on

The next step should operate on one migration slice rather than add another broad architecture layer. The most direct candidate is to formalise the current transactional work as an **M3 gate evidence record** and use it to decide exactly which remaining cut is required before M3 can exit.
