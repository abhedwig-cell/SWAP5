# F-PE-TEMPORAL08 P3 result

Date: 2026-09-27

Status: `PASS_LIVE_PRODUCTION_COUPLING`

Current-head authority:

- production-code head exercised: `d97b607ec36457e9b9ebaf9b798b7fe672421a98`;
- workflow run: `36300393644`.

## Existing live route preservation

Job:

`p3-live-preservation`

Conclusion:

PASS.

Live MODFLOW6 6.8.0 preservation result:

- coupled iterations = `5`;
- maximum cell residual = `1.0983254090277951e-20 m/s`;
- production FMR ABI: PASS;
- mixed topology: PASS;
- one prepared solve: PASS;
- per-cell conjunctive convergence: PASS;
- MODFLOW -> SWAP -> ledger publication: PASS;
- three real SWAP and ledger commits: PASS.

The preservation harness required only compile-lineage repairs for repository modules added after the historical fixture was first written:

- `mod_drainage_extended_exchange`;
- `mod_b110_direct_retention_core`;
- `mod_b110_direct_retention_provider`.

No preservation physics, tolerances or expected numerical results were changed.

## Live c=0.65 production-bootstrap route

Job:

`p3-live-c065-production`

Conclusion:

PASS.

Route:

`production bootstrap -> bounded c=0.65 participant policy -> F-GC49D application context -> live MODFLOW6 6.8.0`

Result:

- coupled iterations = `8`;
- maximum cell residual = `5.9811775732484325e-20 m/s`;
- MODFLOW6 6.8.0: PASS;
- production FMR ABI: PASS;
- mixed topology: PASS;
- exactly one prepared solve: PASS;
- per-cell conjunctive convergence: PASS;
- MODFLOW -> SWAP -> ledger publication: PASS;
- three real SWAP and ledger commits: PASS;
- exactly-once publication: PASS.

The live fixture also explicitly verifies:

`MISSING_HISTORY_SEED_FAIL_CLOSED = PASS`

Thus the admitted policy cannot silently degrade to a fixed-budget fallback when predecessor history is absent.

## Independent endpoint authority

ENDPOINT01 remains the independent physical endpoint authority for dynamic origins.

That evidence already established for c=0.65:

- direct q-space physical residual <= `1e-15 m/s`;
- production/direct endpoint-head error <= `5e-10 m`;
- historical canonical closeout preservation.

TEMPORAL08 changes neither gate.

## Decision

P3 passes.

The frozen c=0.65 history-aware temporal policy is live-production compatible within the bounded fixed-interface groundwater profile.
