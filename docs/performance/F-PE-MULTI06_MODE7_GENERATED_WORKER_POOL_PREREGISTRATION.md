# F-PE-MULTI06 — GENERATED ELAS mode-7 in-process worker-pool admission

Date: 2026-09-30

Status: PREREGISTERED_ADMISSION

Baseline:
`integration/f-ci-canonical@68fcf6d384608c11ab5a34cf2eab9924f9788ecd`

Parent evidence:
- F-PE-ELASTIC69 application policy admission;
- F-PE-ELASTIC70 production transaction confirmation;
- F-PE-ELASTIC71 source-weighted population performance confirmation.

## Purpose

Extend the existing generic in-process physical MultiSWAP worker pool to the
already qualified mode-7 GENERATED-ELAS temporal profile without creating a new
executor.

The worker-pool execution loop, scheduler and worker-local backend ownership
remain unchanged.

This workunit changes only the multiworker admission envelope and associated
qualification coverage.

## Existing runtime seam

The canonical runtime already owns:

- `fmr_run_parallel_physical_multiswap`;
- worker-local `fmr_serialized_reference_backend_t` instances;
- worker-local transaction controls;
- deterministic parallel scheduling;
- canonical output collection;
- single-worker exact delegation to the serialized runtime.

The existing multiworker admission gate already requires bottom_mode=7 and
swkimpl=0 but currently rejects:

- `RICHARDS_TEMPORAL_HISTORY`;
- `elasticity_active`.

## Bounded admission extension

Allow multiworker execution only for the additional combination:

- bottom_mode = 7;
- swkimpl = 0;
- swsophy = 0;
- fixed-flux top boundary;
- numerical continuation =
  `FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY`;
- `elasticity_active = true`;
- prepared default MvG hydraulics available;
- prepared elastic storage active;
- finite nonnegative specific elastic storage with exact active-node shape;
- prepared specific elastic storage exactly equals `cofgen(24,:)`;
- no KSATEXM extension;
- no direct retention;
- no tabulated hydraulics;
- no hysteresis;
- no root extraction;
- no snow;
- no macropores;
- no frost.

The pre-existing non-elastic/no-history parallel profile remains admitted
unchanged.

Do not admit temporal history without elastic storage in this workunit.

## Geometry boundary

The current legacy Richards closure still has compile-time/global MOD_grid
ownership.

Therefore one worker-pool invocation may contain multiple parameter/state
instances only when they share the same compiled node geometry.

Heterogeneous BOFEK profile geometry remains separate profile-batch ownership
and is not admitted as one mixed in-process registry by MULTI06.

## Qualification

Use the exact difficult GENERATED profile 8016 production-shaped fixture from
ELASTIC70 and construct 256 independent logical columns on the same exact
profile geometry.

Cycle over the same sixteen origin/forcing combinations:

- h0 = -75, -20, +2, +10 cm;
- forcing delta = -0.05, -0.035, +0.035, +0.05 cm/day.

Policy:
- explicit caller-owned head budget = 0.20 cm.

Compare worker_count 1, 2 and 4.

Required gates:

1. 1/2/4 worker runs all dispatch successfully;
2. every column commits exactly once;
3. aggregate completed/committed counts are identical;
4. per-column committed mass publications are complete;
5. aggregate hard mass is complete;
6. deterministic result semantics and retry counts are identical across worker counts;
7. worker_count >1 has observed real physical concurrency >=2;
8. source scope is limited to the worker-pool admission gate plus tests/docs;
9. existing pre-MULTI06 parallel profile remains preserved.

Timing is descriptive, not an admission criterion.

## Population follow-up

After admission, repeat the exact ELASTIC71 1024-column source-weighted
population as four profile-specific in-process batches using the same 1/2/4
worker counts.

This follow-up may establish end-to-end population throughput for the new
runtime seam but must not claim heterogeneous-geometry single-registry support.

## Stop conditions

Stop and do not broaden the gate if:

- worker-count semantics differ;
- hard mass differs;
- committed-state publication differs;
- GENERATED prepared parameter identity is not stable;
- multiworker execution requires mutation of shared immutable parameters;
- a production change beyond the existing admission gate is required.
