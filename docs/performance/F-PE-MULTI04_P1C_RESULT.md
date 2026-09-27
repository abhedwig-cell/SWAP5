# F-PE-MULTI04 P1C result — production TEMPORAL08 application-context scaling

Date: 2026-09-27

Status: `PASS_PRODUCTION_APPLICATION_CONTEXT_SCALING`

PR:
`#666 — F-PE-MULTI04: production application-context worker-local groundwater parallel admission`

Authority:
- exercised head: `ceb6db94aff289a72757f38b1ffa0747b4b2d858`;
- workflow run: `36316574740`;
- job: `p1c-application-context-scaling`.

## Authority shape

P1C measures the actual production application-context path, not the research worker-pool harness.

The scaling fixture is derived from the admitted TEMPORAL08 production fixture and therefore uses:
- `fmr_production_application_bootstrap_t`;
- real application-plan and application-context materialization;
- bottom mode 5;
- `RICHARDS_TEMPORAL_HISTORY`;
- seeded predecessor right-derivative history;
- production history-aware temporal policy with c=0.65 and floor 1e-5 cm;
- production participant registry;
- production worker-local backend storage;
- production C application-context trial/tangent/discard API.

Initialization and plan materialization are outside the timed region.

Timed operation:
`trial_cell_heads`.

Population:
`N=1000`, one production-shaped SWAP tile per groundwater cell.

## Results

Median trial runtime over five measured repetitions:

- 1 worker: `0.097694413 s`;
- 2 workers: `0.049966367 s`;
- 4 workers: `0.036203590 s`.

Speedup relative to 1 worker:

- 2 workers: `1.955203x`;
- 4 workers: `2.698473x`.

Frozen gates:

- 2-worker speedup >=1.5x: PASS;
- 4-worker speedup >=2.2x: PASS.

## Numerical identity

Exact aggregate checksums were identical across 1/2/4 worker variants:

- q checksum: `2.63219253438378203e-05`;
- tangent checksum: `-1.46925912412419323e-02`.

Repeated trials within each variant also required identical q/tangent checksums before the timing result was accepted.

Qualification marker:

`FPE_MULTI04_P1C_APPLICATION_CONTEXT_SCALING=PASS`

## Interpretation

The production application-context plumbing does not erase the scaling established in MULTI02/MULTI03.

The static worker-local production route therefore clears the frozen homogeneous speed gates with substantial margin.

The remaining scheduling task is the already preregistered heterogeneous-load case. No new scheduler search is authorized here.

## Decision

P1C closes:

`ADVANCE_TO_BOUNDED_HYBRID_PRODUCTION_SCHEDULING`

Next:
- production-implement the MULTI03 bounded hybrid rule;
- use immutable captured predecessor-history scale only;
- retain static assignment when predicted static max/mean load <=1.20;
- switch to deterministic descending-cost least-loaded-bin assignment only when the ratio is >1.20;
- preserve canonical result/aggregation order;
- replay both frozen mixed-cost orderings and frozen speed/load gates.
