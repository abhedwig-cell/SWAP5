# F-PE-SCALE02 — post-SETUP04 production-scale throughput characterization

Date: 2026-09-27

Status: `PREREGISTERED_OBSERVATION_ONLY`

Canonical parent:
`integration/f-ci-canonical@933ea3824c9fbfe74c551d6d6fe8144f39b6c378`

Branch:
`work/f-pe-scale02-production-scale-throughput`

## Purpose

Measure whether the admitted production-groundwater MultiSWAP path maintains per-column throughput as population increases into a genuinely large-N regime after SETUP04 removed the bootstrap pathology.

## Matrix

Use the admitted MULTI04 production-shaped application-context scaling fixture.

Population:
- N=10,000;
- N=40,000;
- N=100,000.

Workers:
- 1;
- 2;
- 4.

Five timing repetitions after warm-up.

## Measurements

Report:
- wall-clock trial time;
- columns/s;
- 2-worker speedup;
- 4-worker speedup;
- throughput retention relative to N=10,000 at the same worker count;
- exact q/tangent checksums.

## Interpretation

For worker=4, define throughput retention:

`throughput(N) / throughput(10,000)`

Classify N=100,000 as:

- `STABLE_SCALE`: retention >=0.85;
- `MILD_DEGRADATION`: retention >=0.70 and <0.85;
- `MATERIAL_LARGE_N_DEGRADATION`: retention <0.70.

If material degradation appears, open a memory/cache/data-layout decomposition.

If retention is >=0.85 and semantic identity holds, close the current 4-logical-CPU large-N scaling line and retain high-core scaling as the only unresolved hardware-dependent question.

## Production boundary

Observation-only.
No `src/**` change.
No physics, solver, temporal, tangent, scheduler, coupling, transaction or publication change.
