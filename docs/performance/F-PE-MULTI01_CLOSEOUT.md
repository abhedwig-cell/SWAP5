# F-PE-MULTI01 closeout — current-canonical MultiSWAP scaling rebaseline

Date: 2026-09-27

Status: `CLOSED_WORKER_LOCAL_GROUNDWATER_PARALLEL_SUCCESSOR_SELECTED`

PR:
`#661 — F-PE-MULTI01: current-canonical MultiSWAP scaling rebaseline`

Canonical base:
`integration/f-ci-canonical@c79ea4d7efb580eeb55b61a4e93b4bc6f01bfc96`

## P0 generic worker-pool result

The admitted generic physical worker pool demonstrates real concurrent solves when batches contain multiple columns.

At N=10,000:

- batch 1: no physical concurrency, extra workers slow execution;
- batch 64:
  - 2-worker speedup 1.42x;
  - 4-worker speedup 1.58x;
- batch 1,024:
  - 2-worker speedup 1.46x;
  - 4-worker speedup 1.64x.

Thus batching is required for useful parallel execution.

The scheduler is functional but 4-worker efficiency falls materially at large N.

## P1 production groundwater result

The actual production mode-5 groundwater application context remains serial because all participants share one mutable serialized Reference backend.

Repeated trial scaling is nearly linear:

- 10 tiles: 26.07 us/tile;
- 100 tiles: 26.37 us/tile;
- 1,000 tiles: 27.11 us/tile.

At N=1,000, tangent-query and discard costs are tiny relative to the 27.11 ms serial trial phase.

Therefore the large-N production bottleneck is independent per-tile participant/physical work executed through a shared mutable backend.

## Decision

The immediate successor is:

`F-PE-MULTI02 — worker-local production groundwater backend parallelization`.

MULTI02 is justified because:

1. the production trial cost scales approximately linearly with tile count;
2. the generic worker pool already demonstrates concurrent physical solves;
3. participant state/origin ownership is independent per tile;
4. the current blocker is mutable backend/workspace ownership, not a physical coupling dependency.

## Frozen successor gates

For sufficiently large N:

- 2-worker speedup >= 1.5x;
- 4-worker speedup >= 2.2x;
- per-tile q and tangent preservation within roundoff;
- identical retry and temporal-acceptance decisions;
- deterministic canonical aggregate/publication order;
- no accepted-state, candidate or ledger leakage.

No production source change was made by MULTI01.

## Closure

`CLOSED_WORKER_LOCAL_GROUNDWATER_PARALLEL_SUCCESSOR_SELECTED`
