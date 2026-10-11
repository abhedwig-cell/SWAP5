# F-PE-MULTI04 P3/P4 result — live worker-4 MODFLOW6 production qualification

Date: 2026-09-27

Status: `PASS_LIVE_WORKER4_MODFLOW6`

PR:
`#666 — F-PE-MULTI04: production application-context worker-local groundwater parallel admission`

Authority:
- exercised code head: `26353c45d5eee6388264bc1aeecd0be35578ec13`;
- workflow run: `36318282587`;
- job: `p3p4-live-worker4`;
- job id: `108617039453`;
- harness: `tests/fpe/run_fpe_multi04_p3p4_live_worker4.sh`.

## Authority route

The harness reuses the admitted TEMPORAL08 live-production authority and executes the same live path with groundwater worker counts 1 and 4:

`production bootstrap -> c=0.65 history-aware participant -> F-GC49D application context -> live MODFLOW6 6.8.0`.

The harness requires, for both worker variants:

- `FPE_TEMPORAL08_LIVE_PRODUCTION_BOOTSTRAP=PASS`;
- `FPE_TEMPORAL08_EXACTLY_ONCE_PUBLICATION=PASS`;
- `FGC49D_LIVE_MODFLOW6_6_8_0=PASS`;
- `FGC49D_LIVE_MODFLOW_SWAP_LEDGER_PUBLICATION=PASS`.

It also requires exact worker-1/worker-4 identity for:

- `FGC49D_LIVE_ITERATIONS`;
- `FGC49D_LIVE_MAX_CELL_RESIDUAL_M_PER_S`.

## Qualification result

PASS.

The completed live job therefore establishes:

- production bootstrap remains valid with worker count 4;
- live MODFLOW6 6.8.0 coupling completes;
- SWAP publication remains exactly once;
- groundwater ledger publication remains exactly once;
- worker-4 does not change the live coupling iteration count;
- worker-4 does not change the reported maximum cell residual;
- the worker-local backend execution path is compatible with the live coupling lifecycle.

The harness emits the closing markers:

- `FPE_MULTI04_P3_WORKER4_EXACTLY_ONCE_PUBLICATION=PASS`;
- `FPE_MULTI04_P3_WORKER4_LEDGER_COMMIT=PASS`;
- `FPE_MULTI04_P4_LIVE_MODFLOW6_WORKER4=PASS`;
- `FPE_MULTI04_P4_WORKER1_WORKER4_COUPLING_IDENTITY=PASS`.

## State and transaction interpretation

This gate is specifically stronger than an isolated trial benchmark.

It exercises the live publication path after the parallel trial phase. Because both worker=1 and worker=4 must pass the existing TEMPORAL08 exactly-once and F-GC49D ledger-publication assertions, the parallel path does not gain permission to duplicate or bypass:

- candidate commit;
- SWAP publication;
- ledger publication;
- accepted-origin ownership.

Failure to satisfy any of those assertions would fail the job.

## Decision

P3/P4 close:

`PASS_LIVE_WORKER4_MODFLOW6`

No live MODFLOW6 coupling defect, worker-local backend/thread-safety defect, commit/ledger defect or numerical identity drift is present on the exercised head.
