# F-PE-AFFINITY01 — OpenMP placement qualification

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Canonical parent:
`integration/f-ci-canonical@4cf38c8a3ea67cfc0281bc76357590ccb67d40e5`

Branch:
`work/f-pe-affinity01-openmp-placement`

## Purpose

Determine whether explicit OpenMP thread placement improves the already-admitted worker-local MultiSWAP runtime on SMT hardware.

No SWAP source changes are involved.

## Host requirement

Record:
- CPU model;
- logical CPUs;
- cores;
- threads per core;
- NUMA topology.

Interpret results only for the measured host topology.

## Variants

Use the production-shaped MULTI04 scaling fixture at N=10,000, five repetitions.

Compare worker=4 wall time under:

1. `DEFAULT`
   - no explicit OMP_PROC_BIND / OMP_PLACES;

2. `SPREAD_THREADS`
   - OMP_PROC_BIND=spread;
   - OMP_PLACES=threads;

3. `CLOSE_THREADS`
   - OMP_PROC_BIND=close;
   - OMP_PLACES=threads;

4. `SPREAD_CORES`
   - OMP_PROC_BIND=spread;
   - OMP_PLACES=cores;

5. `CLOSE_CORES`
   - OMP_PROC_BIND=close;
   - OMP_PLACES=cores.

All variants use the exact same source and compiler flags.

## Semantics

Exact q/tangent checksums must match DEFAULT.

## Selection rule

Advance a placement policy only if:
- worker=4 speedup >=5% versus DEFAULT;
- worker=1 is not more than 2% slower;
- semantics are exact.

If a candidate passes at N=10,000, confirm it at N=40,000 before any production recommendation.

If no candidate reaches 5%, close affinity tuning as low return.

## Production boundary

Research-only runtime-environment qualification.
No source, physics, solver, temporal, tangent, scheduling algorithm, coupling, transaction or publication change.
