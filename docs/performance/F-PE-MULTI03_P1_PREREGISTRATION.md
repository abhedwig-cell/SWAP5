# F-PE-MULTI03 P1 preregistration — bounded hybrid deterministic scheduling

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent:
`F-PE-MULTI03 P0`

## Trigger

P0 showed:

- pure cost-aware scheduling fixes the adverse ordering;
- q/tangent semantics remain exact;
- adverse-ordering 4-worker speed improves from `2.161327x` to `2.302142x`;
- but pure cost-aware scheduling is `2.70%` slower than static on the already balanced ordering, exceeding the frozen 2% no-regression gate.

## Candidate

Use deterministic static assignment unless a pre-trial cost proxy predicts material static imbalance.

Algorithm:

1. compute immutable predecessor-history cost proxy per tile;
2. compute the deterministic static modulo assignment and its predicted worker-load sums;
3. compute `static_ratio = max(load) / mean(load)`;
4. if `static_ratio <= 1.20`, use the static assignment unchanged;
5. if `static_ratio > 1.20`, use deterministic descending-cost least-loaded-bin assignment;
6. bind each tile to its assigned worker-local mutable backend;
7. execute worker-owned tiles only;
8. store outputs by canonical tile index;
9. aggregate/publish in canonical tile order.

The threshold `1.20` is frozen before P1 execution and is inherited from the MULTI02/MULTI03 load-balance gate. It is not fitted to P0 runtime results.

## Frozen workloads

N=1,000.

Both history-cost orderings:

- ordering 0, naturally balanced under static modulo assignment;
- ordering 1, adverse under static modulo assignment.

## Semantic gates

Require:

- max q difference = 0 within current test authority;
- max tangent difference = 0;
- exact discrete-route identity in follow-on semantics qualification;
- deterministic assignment for repeated identical input;
- canonical result order unchanged.

## Performance gates

For both orderings:

- 2-worker speedup >=1.5x;
- 4-worker speedup >=2.2x;
- selected scheduler runtime <=1.02 * static runtime;
- selected predicted max/mean load <=1.20.

Additionally:

- ordering 0 must select STATIC;
- ordering 1 must select COST_AWARE.

No post-hoc threshold change is allowed.

## Scope

Research-only.

No change to:

- Richards equations;
- c=0.65;
- temporal floor;
- BALTOL02;
- retry policy;
- nonlinear tolerances;
- tangent mathematics;
- MODFLOW equations;
- participant ownership;
- worker-local backend isolation;
- canonical publication order.
