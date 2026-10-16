# F-PE-MULTI06 — GENERATED ELAS mode-7 in-process worker-pool result

Date: 2026-09-30

Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE

Branch:
`work/f-pe-multi06-mode7-generated-worker-pool`

Qualified postimage:
`02eae81c707c60b777e0f26ca387da17e0a313c6`

Canonical baseline:
`integration/f-ci-canonical@68fcf6d384608c11ab5a34cf2eab9924f9788ecd`

Workflow run:
`36754571171`

Job:
`110021423315`

Conclusion:
SUCCESS.

## Production delta

Exactly one production source file changed:

`src/runtime/mod_fmr_parallel_worker_pool.f90`.

The worker executor, scheduler, transaction execution loop, output collection
and commit logic are unchanged.

The patch only broadens the existing fail-closed multiworker admission gate to
the already-qualified combination:

- bottom_mode = 7;
- swkimpl = 0;
- fixed-flux top boundary;
- GENERATED elastic storage;
- prepared default MvG hydraulics;
- exact prepared specific elastic storage ownership;
- RICHARDS_TEMPORAL_HISTORY;
- no KSATEXM;
- no direct retention;
- no tabulated hydraulics;
- no hysteresis;
- no root uptake;
- no snow;
- no macropores;
- no frost.

Temporal history without elastic storage remains fail-closed in this workunit.

## Qualification fixture

Exact BOFEK/BRO profile 8016:

- soil unit EZg21;
- exact variable 16-node geometry;
- exact Staringreeks retention;
- GENERATED ELAS application preparation;
- explicit caller-owned mode-7 head budget = 0.20 cm.

Population:
`256` independent logical columns.

The population cycles deterministically over:

- h0 = -75, -20, +2, +10 cm;
- top-flux perturbation = -0.05, -0.035, +0.035, +0.05 cm/day.

All runs start from fresh committed state.

## Worker-count result

| workers | completed | committed | retries | mass failures | max simultaneous physical solves |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 256 | 256 | 368 | 0 | 1 |
| 2 | 256 | 256 | 368 | 0 | 2 |
| 4 | 256 | 256 | 368 | 0 | 3 |

Aggregate mass residual in every run:

`2.8773684823679702e-11`

and aggregate mass publication is complete.

Per-column outputs after removing only the worker-count label are byte-identical
between worker counts 1, 2 and 4 for:

- column id;
- completed/committed status;
- retries/attempts;
- initial and final revision;
- mass-complete status;
- mass residual.

## Transaction semantics

Every column:

- completes;
- commits exactly once;
- advances committed revision by exactly one;
- publishes committed time exactly at the requested interval end;
- publishes complete mass accounting.

The multiworker runs do not change retry count, accepted state semantics or
mass publication.

## Concurrency

The qualification observes real overlapping physical work:

- worker_count=2: max simultaneous physical solves = 2;
- worker_count=4: max simultaneous physical solves = 3.

Thus the result is not merely a serial execution hidden behind a multiworker
API.

## Geometry boundary

The admission does not solve heterogeneous geometry ownership.

The legacy Richards closure still compiles against one MOD_grid geometry per
executable. Therefore this admission applies to in-process populations sharing
one compiled geometry.

Different BOFEK geometries remain separate profile batches.

## Decision

Classification:

`PRODUCTION_ADMISSION_CANDIDATE_GENERATED_MODE7_INPROCESS_WORKER_POOL`.

The existing generic worker pool can safely admit the bounded GENERATED ELAS +
mode-7 + temporal-history profile without adding a new executor.

## Follow-up

After canonical admission, rerun the frozen ELASTIC71 source-weighted
1024-column population as four profile-specific in-process batches and compare
1, 2 and 4 worker throughput.

That follow-up is performance characterization only. It must preserve the
heterogeneous-geometry boundary.
