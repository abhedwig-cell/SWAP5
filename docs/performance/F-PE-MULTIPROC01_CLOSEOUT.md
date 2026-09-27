# F-PE-MULTIPROC01 closeout — process versus thread parallelism

Date: 2026-09-27

Status: `CLOSED_PROCESS_PARTITIONING_CANDIDATE_SELECTED`

PR:
`#671 — F-PE-MULTIPROC01: process versus thread parallelism`

## Outcome

On the same 4-logical-CPU GitHub host and the same total N=10,000 production-shaped workload:
- 1x4 delivered 11,613.586 columns/s;
- 2x2 delivered 14,448.514 columns/s;
- 4x1 delivered 14,351.445 columns/s.

Relative to 1x4:
- 2x2 throughput was 1.244104x;
- 4x1 throughput was 1.235746x.

Aggregate q and tangent checksums were identical across configurations.

## Decision

The gain is material and exceeds the frozen 5% advancement threshold by a wide margin.

Select:
`F-PE-MULTIPROC02 — process-partitioning gain attribution`

MULTIPROC01 does not yet authorize a production architecture change.

## Required successor discrimination

MULTIPROC02 must distinguish:
- OpenMP/runtime overhead;
- SMT/core placement and thread affinity;
- process launch overhead versus persistent steady-state work;
- cache/working-set effects where measurable;
- scheduling/synchronization overhead in the one-process worker path.

The 1x4 / 2x2 / 4x1 comparison must remain frozen while causes are isolated.

## Production boundary

No `src/**` change.
No physics, tolerance, temporal, tangent, transaction, aggregation or MODFLOW semantic change.

## Closure

`CLOSED_PROCESS_PARTITIONING_CANDIDATE_SELECTED`
