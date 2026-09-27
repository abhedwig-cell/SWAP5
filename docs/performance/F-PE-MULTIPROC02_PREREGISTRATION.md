# F-PE-MULTIPROC02 — process-partitioning gain attribution

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent:
`F-PE-MULTIPROC01 / PR #671`

Parent head:
`87c52b4df4f75a3ee7ac2f83beba87ffa0ee1b3e`

Branch:
`work/f-pe-multiproc02-gain-attribution`

## Trigger

MULTIPROC01 found, at equal total N=10,000 on one 4-logical-CPU host:
- 1x4: 11,613.586 columns/s;
- 2x2: 14,448.514 columns/s;
- 4x1: 14,351.445 columns/s.

2x2 and 4x1 are about 24% faster than 1x4 with identical aggregate q and tangent checksums.

## Purpose

Attribute the process-partitioning gain before selecting any production architecture change.

## P0 population-size discriminator

Repeat the frozen 1x4 / 2x2 / 4x1 comparison at:
- N=1,000;
- N=40,000.

Retain the existing N=10,000 MULTIPROC01 result as the middle point.

Same host class and same measurement method are required.

### Interpretation

If process advantage increases materially with N:
- prioritize cache/working-set/data-layout and memory-locality hypotheses.

If process advantage is approximately stable across N:
- prioritize OpenMP/runtime/scheduling overhead.

If process advantage shrinks toward zero at larger N:
- classify the MULTIPROC01 result as small-N/runtime overhead rather than a production-scale architecture advantage.

"Materially" means a change in relative process advantage of at least 5 percentage points across the N ladder.

## P1 runtime/binding discriminator

If P0 does not close the attribution, compare the 1x4 configuration under:
- default OpenMP placement;
- `OMP_PROC_BIND=spread, OMP_PLACES=threads`;
- `OMP_PROC_BIND=close, OMP_PLACES=cores`;
- `OMP_WAIT_POLICY=ACTIVE` where supported.

Also record:
- CPU/core topology using `lscpu -e=CPU,CORE,SOCKET,NODE`.

P1 must not tune application physics or worker scheduling policy.

## Production boundary

Research only.

No production `src/**` changes.
No change to physics, tolerances, temporal policy, tangent mathematics, transaction semantics or publication order.

## Successor rule

Select exactly one:
- cache/data-layout decomposition;
- OpenMP/runtime decomposition;
- process-partitioning production architecture qualification;
- close if the gain does not survive population scaling.
