# F-PE-MULTI08 — research harness specification

Date: 2026-10-01

Status: RESEARCH_HARNESS_SPECIFIED

## Implementation choice

The scalable research harness is materialized at test time from the canonical
production worker-pool source. The only research mutation is the worker-count
admission predicate:

production:
`worker_count /= 2 .and. worker_count /= 4`

research characterization:
`worker_count < 2` is irrelevant because worker 1 retains serialized
delegation; every requested count >=2 is permitted subject to the existing
OpenMP thread-limit and profile-admission guards.

No scheduler, executor, transaction, backend, collection, mass, geometry or
physics statement is changed.

This provides a direct counterfactual: what the current executor would do at
larger worker counts if the production admission envelope were widened.

## Qualification sequence

1. Materialize research pool from exact canonical source.
2. Compile the existing profile-8016 GENERATED-ELAS fixture against both the
   production pool and research pool.
3. Require byte-equivalent per-column semantic records and equal aggregate
   mass/retry results for workers 1, 2 and 4.
4. Only after step 3, run research counts >4.
5. Record host topology and actual OpenMP team size.
6. Refuse a timing claim for any requested team the host cannot form.

## Population scaling

The fixture shall expose NCOL as a generated test parameter rather than modify
production source. Replication remains deterministic over the same 16
origin/forcing combinations and each logical column owns independent committed
state.

Target populations: 256, 1024, 4096 and, if runtime permits, 16384.

## Timing

For each population/worker pair:

- one warm-up;
- five measured fresh-state runs when practical;
- median wall time is primary;
- min/max retained as noise indicators;
- exact completion/retry/mass checks retained.

## Interpretation

A larger worker count is interesting only if it improves median throughput
enough to move the conservative near-best decision (within 5% of best).
