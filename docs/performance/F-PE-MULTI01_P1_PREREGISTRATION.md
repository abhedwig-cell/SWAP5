# F-PE-MULTI01 P1 preregistration — production groundwater application-context scaling

Date: 2026-09-27

Status: `PREREGISTERED_OBSERVATION_ONLY`

Parent:
`F-PE-MULTI01 P0`

Canonical authority:
`integration/f-ci-canonical@c79ea4d7efb580eeb55b61a4e93b4bc6f01bfc96`

## Why P1 is required

MULTI01 P0 measures the already admitted generic parallel worker-pool. That is useful scheduler evidence, but it is not the current production groundwater profile.

The admitted generic multiworker envelope is restricted and does not cover the current groundwater application route with:

- bottom mode 5;
- Richards temporal-history continuation;
- model-certificate temporal acceptance;
- production c=0.65 history-aware temporal budget;
- groundwater participant registry and application context.

Current production bootstrap also binds all groundwater participant slots to one shared mutable `fmr_serialized_reference_backend_t`. The current application-context `trial_cell_heads` route therefore executes participant trials serially.

P1 measures that actual route before any ownership or scheduling change.

## Primary question

How does the current production mode-5 groundwater participant/application-context route scale with tile count when executed serially, and how much of its repeated wall clock is independent per-tile physical work versus context aggregation/orchestration?

## Frozen production semantics

Use the current production bootstrap and participant registry with:

- bottom mode 5;
- `FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY`;
- `TX_TEMPORAL_MODEL_CERTIFICATE`;
- production temporal budget policy c=0.65 and floor 1e-5 cm as bound by the bootstrap;
- immutable prepared hydraulic parameters where production uses them;
- no physics/tolerance/policy changes for timing.

No `src/**` modification is allowed in P1.

## Scaling population

Use a production-bootstrap-derived fixture with independent groundwater tiles.

Measure at minimum:

- N=10;
- N=100;
- N=1,000.

If N=10,000 is practical within the observation runner, include it as a separate large-N point. Do not extrapolate it from smaller N.

Prefer one tile per groundwater cell for the primary scaling axis so each tile receives an independent cell-head entry and aggregation does not hide tile execution cost. A separate many-tiles-per-cell measurement may be added later if needed.

## Timed phases

Separate:

1. bootstrap / context construction;
2. accepted-origin capture;
3. `trial_cell_heads`;
4. tangent aggregation/query;
5. discard of live candidates;
6. non-physical context/aggregation overhead where separable.

Repeated execution claims must exclude one-time setup.

## Required counters and invariants

For each N retain:

- tile count and cell count;
- trial completion;
- participant candidate count;
- aggregate q checksum;
- response-tangent checksum where requested;
- attempts;
- retries;
- temporal rejections;
- solver rejections;
- nonlinear iterations where observable;
- discard returns the context to quiescent state;
- committed revisions and ledger counts remain unchanged by discarded trials.

## Ownership observation

P1 must explicitly record that current production bootstrap owns one shared mutable Reference backend across the participant registry.

This is not itself a performance defect. It is a concurrency-safety boundary.

P1 may not parallelize calls through that shared backend.

## Advancement to P2

A production-groundwater parallel research candidate may be opened only if:

1. repeated serial `trial_cell_heads` runtime scales approximately with tile count and is materially dominated by participant trial work rather than aggregation;
2. independent participant state/origin ownership is preserved;
3. a concrete worker-local backend ownership design exists;
4. deterministic aggregation/publication can remain in canonical order.

P2 must use worker-local mutable backend/workspace state. Sharing the current production backend concurrently is explicitly forbidden.

## P2 performance gates, frozen in advance

For sufficiently large N:

- 2-worker speedup >= 1.5x;
- 4-worker speedup >= 2.2x;
- identical per-tile q and tangent results to the serialized authority within roundoff;
- identical retry/acceptance decisions;
- no candidate/state/ledger leakage;
- deterministic aggregate result and publication order.

Failure does not authorize loosening numerical policy or changing physics.

## Scope boundary

P1 is observation-only.

It does not alter:

- Richards equations;
- c=0.65;
- temporal floor;
- A2C;
- tangent mathematics;
- MODFLOW equations;
- commit/publication order;
- mass authority.

