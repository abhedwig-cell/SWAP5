# F-PE-MULTI02 closeout — worker-local production groundwater parallel research

Date: 2026-09-27

Status: `CLOSED_LOAD_BALANCE_SUCCESSOR`

PR:
`#662 — F-PE-MULTI02: worker-local production groundwater parallelization`

Parent authority:
`F-PE-MULTI01 / PR #661`

Canonical base:
`integration/f-ci-canonical@41c24441b22ae55f9f9a691a1d166bd905210739`

Current qualification authority:
- exercised code head: `11538d93aa25fe63cf133babe9269fba85ecff26`;
- workflow run: `36310006585`.

## Question

Can production-shaped independent groundwater participant trials be executed concurrently by giving each worker independent mutable Reference backend/workspace ownership, while preserving serialized numerical semantics and the frozen speed gates?

Answer:

Yes for ownership, numerical semantics and homogeneous large-N performance.

Not yet robustly enough for direct production admission under heterogeneous tile cost.

## P0 — worker-local ownership

PASS.

Research-only production-bootstrap and registry variants demonstrate that mutable backend ownership can be separated without changing serialized physical response.

Observed:

- q difference = 0;
- tangent difference = 0;
- discarded candidates do not mutate committed revisions;
- worker-local serialized runtime stays in the same band as the shared-backend serialized authority.

No production source is changed.

## P0 — parallel scaling

PASS.

Real concurrent physical solves occur with independent worker-local backends.

Current evidence repeatedly clears the frozen homogeneous speed gates.

On current-head replicated N=1,000 authority:

- 2 workers median speedup: `1.913394x`;
- 4 workers median speedup: `2.373764x`.

Frozen gates:

- 2 workers >= 1.5x: PASS;
- 4 workers >= 2.2x: PASS.

## P1 — discrete and exact trajectory semantics

PASS.

Worker counts 1, 2 and 4 preserve:

- per-tile q;
- accepted-trajectory tangent;
- transaction calls;
- accepted substeps;
- attempts;
- retries;
- solver rejections;
- temporal rejections;
- temporal acceptance source;
- internal retries;
- nonlinear iterations;
- HeadCalc calls;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- accepted-origin/candidate lifecycle after discard.

The worker-local candidate is therefore not using a different numerical route to obtain the speedup.

## P2 — heterogeneous workload

A simple mixed-head fixture was rejected as load-balance authority because it did not create a material cost contrast: attempts/nonlinear/backtracking work remained evenly distributed.

The stronger history-cost authority does create deterministic heterogeneous work.

Two deterministic orderings were tested.

Ordering 0:
- 2 workers: `1.888744x`;
- 4 workers: `2.347606x`;
- work ratio: `1.000000`.

Ordering 1:
- 2 workers: `1.900888x`;
- 4 workers: `2.153196x`;
- work ratio: `1.142857`;
- q/tangent identity: PASS.

The preregistered mixed-cost direct-advance rule requires both:

- 4-worker speedup >= 2.2x;
- work ratio <= 1.20.

Ordering 1 therefore has:

- load-ratio gate: PASS;
- speed gate: FAIL.

No threshold is relaxed after observation.

## Main finding

The current production-groundwater serialization is not physically necessary.

Worker-local mutable backend ownership is a valid and substantial performance direction.

The remaining limitation is deterministic scheduling under heterogeneous tile cost.

Static assignment is ordering-sensitive. It can clear the 4-worker gate for one ordering and miss it for another, despite identical numerical results and a moderate work-count imbalance.

This is now a scheduling/load-distribution problem, not a Richards-kernel or temporal-policy problem.

## Decision

MULTI02 closes:

`CLOSED_LOAD_BALANCE_SUCCESSOR`

Do not directly production-admit the current static worker-local candidate.

Open one successor focused on deterministic load balancing/scheduling while preserving the qualified worker-local ownership model.

Suggested successor:

`F-PE-MULTI03 — deterministic load-balanced worker-local groundwater scheduling`

MULTI03 must not change:

- Richards equations;
- c=0.65;
- temporal floor;
- BALTOL02;
- retry scale;
- nonlinear tolerances;
- tangent mathematics;
- MODFLOW equations;
- participant state ownership;
- worker-local mutable backend isolation;
- canonical aggregation/publication order.

The successor should change only work assignment/scheduling.

## Production boundary

MULTI02 remains research-only.

A later application-context/production-admission phase is still required after scheduling qualification, including:

- production application-context integration;
- thread-safety/sanitizer qualification;
- deterministic publication-order preservation;
- live MODFLOW6 coupling;
- state/candidate/ledger leak checks.

## Final status

`F-PE-MULTI02 = CLOSED_LOAD_BALANCE_SUCCESSOR`
