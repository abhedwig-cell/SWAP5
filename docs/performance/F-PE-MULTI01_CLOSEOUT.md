# F-PE-MULTI01 closeout — current-canonical MultiSWAP scaling rebaseline

Date: 2026-09-27

Status: `CLOSED_WORKER_LOCAL_GROUNDWATER_PARALLEL_SUCCESSOR_SELECTED`

PR:
`#661 — F-PE-MULTI01: current-canonical MultiSWAP scaling rebaseline`

Canonical authority:
`integration/f-ci-canonical@fc900fa34ff7b99846c21680d999260a3514d417`

Current qualification authority:
- exercised branch head: `0cb0811fc4118c4acafe36bc182c65051cc1943b`;
- workflow run: `36307581257`;
- P0 generic worker-pool scaling: PASS;
- P1 production-groundwater serial scaling: PASS.

## P0 generic worker-pool result

The admitted generic physical worker pool demonstrates real concurrent solves when batches contain multiple columns.

At N=10,000:

- batch 1: no physical concurrency, extra workers slow execution;
- batch 64:
  - 2-worker speedup `1.44x`;
  - 4-worker speedup `1.59x`;
- batch 1,024:
  - 2-worker speedup `1.45x`;
  - 4-worker speedup `1.61x`.

Thus batching is required for useful parallel execution.

The scheduler is functional, but large-N 4-worker efficiency is only about 0.40. This generic result does not meet the frozen 2.2x 4-worker successor performance gate.

## P1 production groundwater result

The actual production mode-5 groundwater application context remains serial because all participants share one mutable serialized Reference backend.

Repeated trial scaling is nearly linear:

- 10 tiles: `15.98 us/tile`;
- 100 tiles: `16.30 us/tile`;
- 1,000 tiles: `16.62 us/tile`.

At N=1,000:

- trial phase: `16.62 ms`;
- tangent query: about `0.012 ms`;
- discard: about `0.078 ms`.

Therefore the large-N production bottleneck is independent per-tile participant/physical work executed through a shared mutable backend.

## Decision

The immediate successor is:

`F-PE-MULTI02 — worker-local production groundwater backend parallelization`.

MULTI02 is justified because:

1. the production trial cost scales approximately linearly with tile count;
2. the generic worker pool already demonstrates concurrent physical solves;
3. participant state/origin ownership is independent per tile;
4. the current production blocker is mutable backend/workspace ownership, not a physical coupling dependency.

## Frozen successor gates

For sufficiently large N:

- 2-worker speedup >= `1.5x`;
- 4-worker speedup >= `2.2x`;
- per-tile q and tangent preservation within roundoff;
- identical retry and temporal-acceptance decisions;
- deterministic canonical aggregate/publication order;
- no accepted-state, candidate or ledger leakage.

No production source change was made by MULTI01.

The weaker generic large-N 4-worker scaling is retained as a warning: MULTI02 must demonstrate its gain on the actual production-groundwater workload, not infer it from scheduler capability alone.

## Closure

`CLOSED_WORKER_LOCAL_GROUNDWATER_PARALLEL_SUCCESSOR_SELECTED`
