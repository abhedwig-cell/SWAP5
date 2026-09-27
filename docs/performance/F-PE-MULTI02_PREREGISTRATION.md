# F-PE-MULTI02 — worker-local production groundwater backend parallelization

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent:
`F-PE-MULTI01 / PR #661`

Parent head:
`82e82edcef0ad66360db79391e0e5b7f8a2d82be`

Branch:
`work/f-pe-multi02-worker-local-groundwater-v2`

## Trigger

MULTI01 established two separate facts.

Generic physical worker-pool:
- real concurrent SWAP solves are already supported when batch size exposes enough work;
- at N=10,000, batch 1,024:
  - 2 workers: about 1.46x speedup;
  - 4 workers: about 1.64x speedup.

Production groundwater application context:
- mode 5;
- Richards temporal-history continuation;
- model-certificate temporal acceptance;
- c=0.65 production history-aware temporal policy;
- one tile per groundwater cell;
- current participant registry shares one mutable serialized Reference backend.

Measured production repeated trial scaling:
- N=10: 26.07 us/tile;
- N=100: 26.37 us/tile;
- N=1,000: 27.11 us/tile.

At N=1,000, trial execution is about 27.11 ms while tangent query and discard are below 0.20 ms combined.

Therefore the production large-N bottleneck is independent per-tile physical trial work executed serially because mutable backend/workspace state is shared.

## Research question

Can the production groundwater participant workload be executed in parallel by assigning each worker its own mutable serialized Reference backend/workspace while preserving participant origin/state authority and deterministic canonical aggregation?

## Hard safety boundary

MULTI02 must never execute concurrent calls through one shared mutable `fmr_serialized_reference_backend_t`.

Worker-local mutable state is mandatory.

Shared immutable inputs are allowed only when already safe by construction, for example:
- immutable hydraulic parameters;
- immutable templates;
- read-only forcing descriptors;
- frozen configuration.

Per-participant transaction/origin/candidate state remains independently owned.

## P0 architecture candidate

Research-only implementation may use generated/test copies.

Candidate design:

1. retain one canonical application-context plan and canonical tile ordering;
2. partition independent participant trials into deterministic batches;
3. allocate one mutable Reference backend/workspace per worker;
4. bind each worker to immutable shared model inputs and worker-local mutable solver state;
5. execute tile trials in parallel;
6. write results into preassigned per-tile result slots only;
7. perform cell aggregation after the parallel region in canonical cell/tile order;
8. leave tangent publication, ledger preparation, commit and publication ordering unchanged.

No production source admission in P0.

## Frozen population

Use the production-shaped MULTI01 P1 profile:

- bottom mode 5;
- temporal-history continuation;
- model-certificate temporal acceptance;
- c=0.65 production policy;
- TEMPORAL08-compatible history seed;
- accepted-origin head;
- one tile per groundwater cell.

Scaling:
- N=100;
- N=1,000;
- N=10,000 where runner cost is practical.

Workers:
- 1;
- 2;
- 4.

Use a batch size that exposes sufficient independent work; include at least one moderate and one large batch.

## Semantic gates

Relative to the serialized production authority, require:

- per-tile q identical within roundoff;
- per-tile response tangent identical within roundoff where requested;
- identical transaction attempts;
- identical retries;
- identical temporal-rejection decisions;
- identical solver-rejection decisions;
- identical nonlinear iteration counts where observable;
- no accepted-state mutation before commit;
- discard restores quiescent participant state;
- committed revision and ledger counters unchanged by discarded trials;
- deterministic aggregate q/tangent independent of worker count;
- canonical publication order unchanged.

Any shared mutable backend race is an immediate failure.

## Performance gates

For sufficiently large N:

- 2-worker speedup >= 1.5x;
- 4-worker speedup >= 2.2x.

Also report:
- ns/tile;
- worker efficiency;
- max simultaneous real physical solves;
- batch count;
- worker work distribution;
- aggregation overhead;
- setup cost separately from repeated execution.

Do not count setup gain as repeated runtime gain.

## P1 extension gate

If P0 passes semantic and performance gates, proceed to a production-shaped application-context research integration.

That stage must prove:
- same C API behavior;
- deterministic cell aggregation;
- tangent-query preservation;
- discard/commit preservation;
- no ownership leak across workers;
- current serialized route retained as fallback/default until admission.

## Non-targets

MULTI02 does not:
- change Richards equations;
- change c=0.65 or its floor;
- change BALTOL02;
- change A2C;
- change tangent mathematics;
- approximate discarded trials;
- change MODFLOW equations;
- introduce GPU execution;
- change canonical publication order.

## Decision outcomes

MULTI02 closes with one of:

- `CLOSED_RESEARCH_QUALIFIED_WORKER_LOCAL_PARALLEL`;
- `CLOSED_REJECTED_PARALLEL_OVERHEAD`;
- `CLOSED_REJECTED_OWNERSHIP_OR_SEMANTIC_DRIFT`;
- a real implementation blocker.

No production admission is implied by research qualification.
