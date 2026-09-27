# F-PE-MULTIPROC04 closeout — persistent-process steady-state decomposition

Date: 2026-09-27

Status: `CLOSED_PROCESS_PARTITIONING_NOT_STEADY_STATE_WIN`

PR:
`#674 — F-PE-MULTIPROC04: persistent-process steady-state decomposition`

## Decision

Persistent process partitioning is not a steady-state throughput win on the current 4-logical-CPU host.

At N=40,000:
- 1x4: 25,601 columns/s;
- 2x2: 24,387 columns/s;
- 4x1: 24,446 columns/s.

The one-process 4-worker route remains the fastest persistent configuration.

The large MULTIPROC01/02 gain is attributed primarily to parallelized initialization/application-context construction.

## New performance question

Large-N initialization is expensive:
- 1x4 launch-to-READY at N=40,000: about 6.76 s;
- 4x1: about 2.30 s.

This may be worth optimizing only if context construction is repeated materially in the real production lifecycle.

Select:
`F-PE-SETUP01 — large-N groundwater context materialization decomposition`

SETUP01 begins observation-only and must first establish lifecycle frequency and setup share in a production-shaped run.

## Production boundary

No production `src/**` change.
No physics, tolerance, temporal, tangent, transaction, aggregation or MODFLOW semantic change.

## Closure

`CLOSED_PROCESS_PARTITIONING_NOT_STEADY_STATE_WIN`
