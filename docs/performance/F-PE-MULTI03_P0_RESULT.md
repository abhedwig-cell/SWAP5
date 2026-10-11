# F-PE-MULTI03 P0 result — pure cost-aware deterministic scheduling

Date: 2026-09-27

Status: `REJECT_PRIMARY_COST_AWARE_NO_REGRESSION_GATE`

PR:
`#664 — F-PE-MULTI03: deterministic load-balanced worker-local groundwater scheduling`

Authority:
- head: `c3bb32b4dff91a4f3236206de8f153cd6ceb554b`;
- workflow run: `36310787335`;
- job: `p0-cost-aware-scheduling`.

## Candidate

Deterministic descending-cost list scheduling using predecessor-history scale as immutable pre-trial cost proxy.

For each tile:

- history scale is known before trial execution;
- tiles are sorted by descending predicted cost;
- each tile is assigned to the currently least-loaded worker;
- worker ties are resolved by lowest worker id;
- results remain in canonical tile slots and are aggregated in canonical order.

No production source is changed.

## Semantics

PASS.

Across both frozen N=1,000 orderings and 1/2/4 workers:

- max q difference = 0;
- max tangent difference = 0.

## Ordering 0: already well balanced

Static 4-worker:
- runtime: `12.842084 ms`;
- speedup: `2.366433x`;
- predicted load ratio: `1.004800`.

Pure cost-aware 4-worker:
- runtime: `13.189082 ms`;
- speedup: `2.304173x`;
- predicted load ratio: `1.000094`.

The cost-aware assignment is about `2.70%` slower than static.

Frozen no-regression gate:
- cost-aware runtime may not be >2% slower than static.

Decision:
- FAIL.

## Ordering 1: adverse static assignment

Static 4-worker:
- runtime: `14.221869 ms`;
- speedup: `2.161327x`;
- predicted load ratio: `3.011765`.

Pure cost-aware 4-worker:
- runtime: `13.351960 ms`;
- speedup: `2.302142x`;
- predicted load ratio: `1.000094`.

Frozen speed gate:
- 4-worker speedup >=2.2x.

Decision:
- PASS.

The candidate removes the adverse-ordering miss without numerical drift.

## Interpretation

Pure cost-aware assignment solves the imbalance case but imposes a small regression when static assignment is already sufficiently balanced.

The frozen 2% no-regression gate is not relaxed.

This does not reject deterministic load balancing in general. It rejects always-on least-loaded-bin scheduling as the primary MULTI03 candidate.

## Next candidate

Preregister one bounded hybrid scheduler:

- compute the predicted static-assignment load ratio before execution;
- if predicted ratio <=1.20, retain deterministic static assignment;
- if predicted ratio >1.20, use the already qualified deterministic least-loaded-bin assignment.

The decision uses only immutable pre-trial information.

No runtime feedback, nondeterministic work stealing, physics change, tolerance change or post-trial information is allowed.
