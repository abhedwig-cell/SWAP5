# F-GC45 — Real MultiSWAP N:1 + live MODFLOW6 application qualification

## Purpose

F-GC45 qualifies the first real N:1 runtime composition built from already-admitted groundwater capabilities. Two independently transactional real FMR/SWAP columns contribute to one live MODFLOW6 6.8.0 groundwater cell.

This is **runtime/composition qualification**. It is not scientific evidence that heterogeneous unsaturated-zone columns may be replaced by an equivalent column.

## Reused authority

F-GC45 changes no production source. It reuses:

- F-GC30 real accepted-trajectory SWAP predictor response;
- F-GC40 deterministic N:1 affine cell-response reduction;
- F-GC44 real FMR prescribed-head participant;
- F-GC38/F-GC41 live MODFLOW prepared-solve and timestep publication semantics;
- F-GC41 publication rule that all reversible participant readiness is proven before MODFLOW `finalize_time_step`.

## Qualified topology

The first envelope is deliberately small:

- two real FMR/SWAP columns;
- one live MODFLOW groundwater cell;
- area fractions 0.35 and 0.65;
- distinct positive SWAP lineages and distinct tile-ledger identities;
- one common groundwater lineage and coupling window;
- the short near-equilibrium F-GC44/F-GC30 numerical route;
- drainage, root extraction, macropore flow, snow and soil temperature disabled.

The two columns intentionally use the same physical parameterization in this first runtime qualification. That isolates the N:1 transaction and coupling composition from the separate scientific question of heterogeneous spatial aggregation.

## Coupling loop

Each tile produces an admitted real predictor response. F-GC40 reconciles the two responses to one common reference head and produces the single affine MODFLOW cell response.

For each live prepared-solve iteration:

1. publish the aggregate affine response to the MODFLOW API package;
2. advance the same prepared MODFLOW solve, preserving accepted `XOLD`;
3. run both real SWAP correctors from their own immutable accepted checkpoints at the common MODFLOW cell head;
4. compute `q_cell = 0.35*q_1 + 0.65*q_2`;
5. compare `q_cell` with the realized MODFLOW boundary flux;
6. discard both SWAP candidates when the coupled criterion is not yet satisfied;
7. keep the aggregate slope fixed and re-anchor only the affine intercept.

Convergence remains conjunctive: MODFLOW must report convergence and the area-weighted interface-flux residual must satisfy the F-GC45 tolerance.

## Publication boundary

After coupled convergence:

1. finalize the prepared MODFLOW solve;
2. non-mutating preflight of **both** retained SWAP candidates;
3. stage and prepare **both** area-weighted tile ledgers;
4. verify both prepared-ledger credentials;
5. verify MODFLOW timestep readiness;
6. cross the publication point with MODFLOW `finalize_time_step` exactly once;
7. commit both preflighted SWAP candidates in canonical tile order;
8. commit both prepared tile ledgers.

As in F-GC25 and F-GC41, failure after the irreversible publication point is a durability/invariant failure, not a rollback-safe scientific retry.

## Evidence boundary

F-GC45 does not qualify:

- equivalence of heterogeneous land-surface units;
- parameter or forcing upscaling;
- more than one live MODFLOW cell;
- active drainage, root uptake, macropores, snow or soil temperature;
- Ribasim or irrigation;
- runtime finite-difference tangent fallback;
- arbitrary large prescribed-head changes.

Those are separate scientific or capability workunits.
