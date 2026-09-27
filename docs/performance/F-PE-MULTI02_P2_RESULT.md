# F-PE-MULTI02 P2 result — performance replication and mixed-cost load balance

Date: 2026-09-27

Status: `PASS_SEMANTICS_SELECT_LOAD_BALANCING`

PR:
`#662 — F-PE-MULTI02: worker-local production groundwater parallelization`

Current-head authority:
- branch head exercised: `11538d93aa25fe63cf133babe9269fba85ecff26`;
- workflow run: `36310006585`.

## Homogeneous replicated performance

Job:
`p2-performance-replication`

Three N=1,000 replicates:

2 workers:
- 1.897730x;
- 1.913394x;
- 1.915544x;
- median: `1.913394x`.

4 workers:
- 2.388661x;
- 2.354547x;
- 2.373764x;
- median: `2.373764x`.

Frozen homogeneous speed gates:

- 2 workers >= 1.5x: PASS;
- 4 workers >= 2.2x: PASS.

## Exact trajectory authority

Job:
`p1-trajectory-identity`

PASS.

The direct per-trial serial versus worker-local comparison preserves:

- q;
- accepted-trajectory tangent;
- temporal acceptance source;
- transaction calls;
- accepted substeps;
- attempts;
- retries;
- solver rejections;
- temporal rejections;
- internal retries;
- nonlinear iterations;
- HeadCalc calls;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- origin/candidate lifecycle after discard.

The previous failing delta-based diagnostics comparison was a harness error. Kernel diagnostics are per-trial values, not cumulative counters. The current authority compares the diagnostics objects for the same serial and parallel trial directly.

## Supplemental mixed-head discriminator

Job:
`p2-mixed-load`

The mixed-head workload preserves q/tangent semantics and still shows good speed:

- adverse-style 4-worker speedup about `2.56x`;
- balanced-style 4-worker speedup about `2.51x`.

However both orderings produce:

- identical attempts;
- identical nonlinear iterations;
- identical backtracking counts;
- work ratio = `1.0`.

Therefore this workload does not create a material cost contrast and is not valid load-balance authority.

The job intentionally reports:

`mixed-cost contrast insufficient`.

This is retained as negative discriminator evidence, not as rejection of worker-local parallelism.

## Strong history-cost mixed-load authority

Job:
`p2-mixed-cost-authority`

This test varies predecessor-history scale across four deterministic cost classes and evaluates two deterministic tile orderings.

Semantic preservation:

- maximum q difference = 0;
- maximum tangent difference = 0.

Ordering 0:

- 2 workers: `1.888744x`;
- 4 workers: `2.347606x`;
- 4-worker work ratio: `1.000000`.

Ordering 1:

- 2 workers: `1.900888x`;
- 4 workers: `2.153196x`;
- 4-worker work ratio: `1.142857`;
- worker nonlinear totals: `3000, 3000, 2250, 2250`.

## Frozen P2 decision

Preregistered direct-advance gate for the mixed-cost workload:

- 4-worker speedup >= 2.2x;
- max/mean worker-work ratio <= 1.20;
- semantic identity mandatory.

For ordering 1:

- semantic identity: PASS;
- work-ratio gate: PASS, `1.142857 <= 1.20`;
- 4-worker speed gate: FAIL, `2.153196 < 2.2`.

Decision:

`SELECT_LOAD_BALANCING`

The miss is small but the gate was frozen before measurement and is not relaxed post hoc.

## Interpretation

Worker-local mutable backend ownership is valid and materially faster.

The remaining problem is no longer physics or numerical equivalence. It is scheduling sensitivity under heterogeneous tile cost.

Static deterministic round-robin assignment can meet the gate for one ordering and miss it for another.

Therefore MULTI02 does not advance directly to production application-context admission.

The immediate successor is a bounded deterministic load-balancing/scheduling workunit that retains:

- worker-local backend ownership;
- exact per-tile semantics;
- canonical aggregation/publication order;
- c=0.65;
- BALTOL02;
- retry and temporal-acceptance policy;
- all current physics.

No production source change is admitted by P2.
