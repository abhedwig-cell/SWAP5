# F-PE-MULTIPROC02 closeout — process-partitioning gain attribution

Date: 2026-09-27

Status: `CLOSED_COMPACT_DISPATCH_SUCCESSOR_SELECTED`

PR:
`#672 — F-PE-MULTIPROC02: process-partitioning gain attribution`

## Result

The process advantage is strongly N-dependent and increases rather than disappears at production-relevant population sizes.

The frozen N ladder shows:
- N=1,000: 2x2 = 1.063x versus 1x4;
- N=10,000: 2x2 = 1.244x;
- N=40,000: 2x2 = 1.727x.

4x1 reaches 1.863x versus 1x4 at N=40,000.

## Selected mechanism

A concrete large-N mechanism exists in the one-process parallel path:
each worker scans the full tile population and filters on `owner(idx)`.

This creates avoidable repeated dispatch work proportional to worker-count times population.

## Decision

Select:
`F-PE-MULTIPROC03 — compact worker dispatch qualification`

Do not yet select a multi-process production architecture.

First determine whether the one-process deficit can be removed while preserving the current worker-local ownership and deterministic scheduling semantics.

## Production boundary

No production `src/**` change in MULTIPROC02.
No physics, tolerance, temporal, tangent, transaction or MODFLOW semantic change.

## Closure

`CLOSED_COMPACT_DISPATCH_SUCCESSOR_SELECTED`
