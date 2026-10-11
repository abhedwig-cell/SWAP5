# F-PE-MULTI03 P1 result — bounded hybrid deterministic scheduling

Date: 2026-09-27

Status: `PASS_SCHEDULING_CANDIDATE_QUALIFIED`

PR:
`#664 — F-PE-MULTI03: deterministic load-balanced worker-local groundwater scheduling`

Authority:
- head: `869bdba0d48953f8b11ead632fa8f5fa16ba0ca5`;
- workflow run: `36311612572`;
- job: `p1-hybrid-scheduling`.

## Candidate

Deterministic bounded hybrid scheduling using only immutable pre-trial predecessor-history cost information.

Rule:

1. build the ordinary static modulo assignment;
2. compute its predicted max/mean worker-load ratio;
3. if the ratio is <=1.20, retain static assignment;
4. if the ratio is >1.20, use deterministic descending-cost least-loaded-bin assignment;
5. execute tiles only on their assigned worker-local mutable backend;
6. store results by canonical tile index and preserve canonical aggregation/publication order.

The 1.20 threshold was preregistered before P1 execution and inherited from the MULTI02/MULTI03 load-balance gate.

## Exact numerical semantics

PASS.

The qualified P1 harness exposes participant kernel diagnostics in research-only copies and compares the serial and selected-scheduler trial route per tile.

Across both frozen N=1,000 orderings and 1/2/4 workers, the selected hybrid path preserves:

- q exactly under the current authority;
- tangent exactly;
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
- accepted-origin presence after discard;
- absence of a live candidate after discard;
- committed revision remaining unchanged before commit.

Therefore the scheduling choice does not obtain its speedup by changing the discrete solver route.

## Ordering 0 — naturally balanced

Predicted static 4-worker load ratio:
`1.004800`

Hybrid selection:
`STATIC`

Measured speedup relative to the 1-worker static authority:
- 2 workers: `1.854475x`;
- 4 workers: `2.388483x`.

Hybrid/static 4-worker runtime ratio:
- static: `12.952288 ms`;
- selected hybrid: `12.918685 ms`;
- hybrid vs static speed ratio: `1.002601x`.

Frozen gates:
- 2-worker >=1.5x: PASS;
- 4-worker >=2.2x: PASS;
- selected runtime <=1.02 * static runtime: PASS;
- selected predicted max/mean load <=1.20: PASS;
- required selection STATIC: PASS.

## Ordering 1 — adverse static assignment

Predicted static 4-worker load ratio:
`3.011765`

Hybrid selection:
`COST_AWARE`

Predicted selected 4-worker load ratio:
`1.000094`

Measured speedup relative to the 1-worker static authority:
- 2 workers: `1.873259x`;
- 4 workers: `2.317263x`.

4-worker runtimes:
- static: `14.344886 ms`;
- selected hybrid: `13.303294 ms`;
- hybrid vs static speed ratio: `1.078296x`.

Frozen gates:
- 2-worker >=1.5x: PASS;
- 4-worker >=2.2x: PASS;
- selected runtime <=1.02 * static runtime: PASS;
- selected predicted max/mean load <=1.20: PASS;
- required selection COST_AWARE: PASS.

## P0 negative evidence retained

Always-on cost-aware scheduling remains rejected.

It fixed the adverse ordering but could regress the already balanced ordering beyond the frozen 2% no-regression allowance. That result is retained in `F-PE-MULTI03_P0_RESULT.md` and is not reinterpreted after P1.

The P0 CI job remains as non-blocking negative evidence. It is not an admission gate for the P1 candidate.

## Decision

The bounded hybrid deterministic scheduler satisfies the frozen MULTI03 semantics, load-balance and performance gates.

P1 decision:

`QUALIFY_SCHEDULING_CANDIDATE`

No production `src/**` change is admitted by this result.
