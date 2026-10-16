# F-PE-MULTI02 — worker-local production groundwater backend parallelization

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent authority:
`F-PE-MULTI01 / PR #661`

Canonical base:
`integration/f-ci-canonical@fc900fa34ff7b99846c21680d999260a3514d417`

Branch:
`work/f-pe-multi02-worker-local-groundwater`

## Trigger

MULTI01 established two facts on current authority.

1. The existing generic physical worker pool can execute independent SWAP columns concurrently and gives useful speedup when work is batched.
2. The current production groundwater application-context route remains serial because all groundwater participants share one mutable serialized Reference backend.

Production-groundwater repeated trial cost scales approximately linearly:

- N=10: about 26.07 us/tile;
- N=100: about 26.37 us/tile;
- N=1,000: about 27.11 us/tile.

At N=1,000, tangent aggregation and discard are tiny relative to the approximately 27.11 ms serial trial phase.

The performance target is therefore not another single-column kernel. It is safe concurrent execution of independent production groundwater participants.

## Primary question

Can the current production mode-5 groundwater participant route use worker-local mutable backend/workspace state to execute independent tile trials concurrently while preserving the serialized authority exactly enough for production qualification?

## Hard safety boundary

The existing production-shared `fmr_serialized_reference_backend_t` must never be called concurrently.

P0/P1 research candidates must allocate or bind independent mutable backend/workspace ownership per active worker.

Read-only/prepared hydraulic authority may be shared only where the existing ownership contract already permits immutable concurrent reads.

No accepted participant state, transaction candidate, temporal-history state, workspace scratch or ledger candidate may be shared between concurrent workers.

## Frozen production semantics

Retain exactly:

- bottom mode 5;
- Reference Richards;
- Richards temporal-history continuation;
- model-certificate temporal acceptance;
- production history-aware c=0.65 budget and 1e-5 cm floor;
- BALTOL02;
- current retry scale and retry limit;
- current tangent mathematics and cache policy;
- current groundwater topology and aggregation semantics;
- deterministic canonical result/publication order.

No physics, tolerance or coupling-equation change is allowed.

## P0 architecture proof

Construct a research-only worker-local execution path.

Required proof:

- each worker owns independent mutable serialized backend and solver workspace;
- participant accepted-origin ownership remains per tile;
- trial candidates remain per tile;
- no concurrent mutation of the current shared production backend occurs;
- result collection is reordered to canonical tile/cell order before aggregation;
- one-worker candidate is semantically equivalent to serialized production authority.

P0 may use generated/test copies and research support code. No production `src/**` admission is authorized.

## P1 semantic matrix

For N at minimum:

- 10;
- 100;
- 1,000.

Compare serialized authority against worker-local candidate at 1, 2 and 4 workers.

Require:

- identical completion status;
- per-tile q difference at roundoff scale;
- per-tile tangent difference at roundoff scale where requested;
- identical temporal rejection count;
- identical retry count;
- identical solver rejection count;
- identical accepted substep count;
- discard returns every participant to the accepted origin;
- committed revision and ledger counts unchanged during discarded trials;
- deterministic aggregate cell q and tangent checksums across repeated runs.

## P2 performance gates

Frozen from MULTI01 before candidate timing:

For sufficiently large N:

- 2-worker speedup >= 1.5x versus candidate worker=1;
- 4-worker speedup >= 2.2x versus candidate worker=1.

Also report:

- parallel efficiency;
- max simultaneous real physical solves;
- per-worker work counts;
- scheduling/batching overhead;
- aggregate trial wall clock;
- ns/tile;
- setup cost separately.

Use batches large enough to permit concurrency. Batch=1 is a serialized scheduling control, not the primary performance arm.

## Load-balance discriminator

Include at least one mixed-cost population if a repository-backed difficult/easy tile mix can be formed without changing physical semantics.

If homogeneous scaling passes but mixed-cost scaling loses materially, do not rewrite physics. Classify the successor as load-balancing/scheduling.

## Admission boundary

Production source may only be changed in a later explicitly preregistered admission phase after:

- worker-local ownership proof passes;
- semantic matrix passes;
- frozen speed gates pass;
- sanitizer/poison/thread-safety checks pass;
- live MODFLOW6 coupling qualification confirms no publication or endpoint regression.

## Closure outcomes

MULTI02 closes with one of:

- `CLOSED_PARALLEL_CANDIDATE_QUALIFIED`;
- `CLOSED_REJECTED_SPEED`;
- `CLOSED_REJECTED_SEMANTICS`;
- `CLOSED_LOAD_BALANCE_SUCCESSOR`;
- a real ownership/thread-safety blocker.

No production parallelism is implied by preregistration.
