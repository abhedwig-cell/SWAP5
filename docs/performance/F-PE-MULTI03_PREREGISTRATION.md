# F-PE-MULTI03 — deterministic load-balanced worker-local groundwater scheduling

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent authority:
`F-PE-MULTI02 / PR #662`

Canonical base:
`integration/f-ci-canonical@3a6ecd223b7187d5a6913f9ca47f8596c6de2bf3`

Branch:
`work/f-pe-multi03-deterministic-load-balanced-groundwater`

## Trigger

MULTI02 qualified worker-local mutable Reference backend ownership:

- exact q and tangent identity;
- exact per-trial numerical route;
- homogeneous N=1,000 median speedup:
  - 2 workers: 1.913394x;
  - 4 workers: 2.373764x.

The strong mixed history-cost authority then showed deterministic ordering sensitivity.

For the adverse ordering:

- 2 workers: 1.900888x;
- 4 workers: 2.153196x;
- max/mean nonlinear-work ratio: 1.142857.

The preregistered 4-worker direct-advance gate was 2.2x. It failed.

Therefore MULTI02 closed `CLOSED_LOAD_BALANCE_SUCCESSOR`.

## Primary question

Can deterministic cost-aware work assignment remove the ordering sensitivity of the qualified worker-local groundwater candidate while preserving exact numerical semantics and canonical output order?

## Hard scope

MULTI03 changes only scheduling/work assignment in research copies.

It may not change:

- Richards equations;
- hydraulic constitutive functions;
- c=0.65;
- temporal floor = 1e-5 cm;
- BALTOL02;
- retry scale or retry limit;
- nonlinear tolerances;
- tangent mathematics or cache policy;
- MODFLOW equations;
- participant accepted-origin ownership;
- worker-local mutable backend isolation;
- canonical result/aggregation/publication order.

No production `src/**` modification is authorized.

## Frozen workload authority

Use the strong MULTI02 history-cost mixed workload at N=1,000.

Four deterministic predecessor-history cost classes are retained.

Evaluate at least the two MULTI02 orderings:

1. grouped/adverse;
2. interleaved/balanced.

The serial authority remains identical for each ordering.

## Candidate scheduling rule

The first candidate is deterministic static cost-aware assignment.

Allowed scheduling information must be known before the trial execution begins and must not use future trial outcomes.

The candidate may use the captured predecessor-history scale already available at accepted-origin capture as a deterministic cost proxy.

Primary candidate:

- compute one immutable cost key per tile from predecessor-history scale;
- sort or partition work deterministically by descending predicted cost;
- assign tiles to workers using deterministic least-loaded-bin/list scheduling;
- execute each worker's assigned tiles with that worker's private mutable backend/workspace;
- write results to per-tile result slots;
- aggregate/publish strictly in canonical tile order after the parallel phase.

No dynamic nondeterministic work stealing is allowed in this workunit.

## Baselines

Compare:

1. serialized authority;
2. MULTI02 static index/round-robin worker assignment;
3. MULTI03 deterministic cost-aware assignment.

## Semantic gates

For every tile and worker count require:

- q identity within roundoff;
- tangent identity within roundoff;
- identical temporal acceptance source;
- identical transaction calls;
- identical accepted substeps;
- identical attempts;
- identical retries;
- identical solver rejections;
- identical temporal rejections;
- identical internal retries;
- identical nonlinear iterations;
- identical HeadCalc calls;
- identical Jacobian builds;
- identical linear solves;
- identical backtracking attempts;
- no committed revision mutation before commit;
- no live candidate after discard;
- accepted origin remains valid.

Aggregate output must be deterministic and independent of execution completion order.

## Load-balance evidence

For each worker report:

- assigned tile count;
- predicted cost sum;
- attempts;
- nonlinear iterations;
- backtracking attempts.

Report:

- max/mean predicted cost;
- max/mean nonlinear work;
- makespan.

## Frozen performance gates

Primary authority: N=1,000 adverse ordering.

Relative to the 1-worker worker-local candidate:

- 2-worker speedup >= 1.5x;
- 4-worker speedup >= 2.2x.

Load balance:

- max/mean nonlinear work <= 1.20;
- cost-aware 4-worker runtime must not be slower than static round-robin by more than 2%.

A direct production-shaped successor is selected only if all semantic gates pass and the 4-worker speed gate passes for both frozen orderings.

## Decision outcomes

MULTI03 closes with one of:

- `CLOSED_SCHEDULING_CANDIDATE_QUALIFIED`;
- `CLOSED_NO_SCHEDULING_GAIN`;
- `CLOSED_REJECTED_SEMANTICS`;
- a real scheduling/ownership blocker.

If qualified, the next workunit is production application-context integration and live MODFLOW6 admission.

If not qualified, retain worker-local ownership evidence but do not production-admit parallel groundwater execution.
