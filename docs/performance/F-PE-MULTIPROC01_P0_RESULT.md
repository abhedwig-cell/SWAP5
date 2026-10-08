# F-PE-MULTIPROC01 P0 result — process versus thread parallelism

Date: 2026-09-27

Status: `P0_PROCESS_PARTITIONING_WINS`

PR:
`#671 — F-PE-MULTIPROC01: process versus thread parallelism`

Measured head:
`0192ce2049a2592627f82bcfb731937325b3439b`

Workflow run:
`36349168272`

## Host

GitHub Actions host:
- AMD EPYC 9V74;
- 2 physical cores;
- 4 logical CPUs via SMT2;
- one socket;
- one NUMA node.

## Workload

Production-shaped TEMPORAL08 application-context workload:
- total N=10,000 columns;
- 5 replicated measured rounds;
- compilation and fixture setup excluded from the measured interval;
- identical total logical column work for every configuration;
- exact aggregate q and tangent checksums required.

Configurations:
- 1x4: one process, four workers;
- 2x2: two concurrent processes, two workers each;
- 4x1: four concurrent processes, one worker each.

## Results

| Configuration | Median seconds | Relative throughput vs 1x4 | Throughput columns/s | Classification |
|---|---:|---:|---:|---|
| 1x4 | 0.861060493 | 1.000000x | 11,613.586 | BASELINE |
| 2x2 | 0.692112698 | 1.244104x | 14,448.514 | PROCESS_WIN |
| 4x1 | 0.696793944 | 1.235746x | 14,351.445 | PROCESS_WIN |

Best configuration:
`2x2`

Improvement versus 1x4:
- wall-clock reduction: about 19.6%;
- throughput increase: about 24.4%.

4x1 is nearly as fast:
- throughput increase: about 23.6%.

## Semantic identity

Aggregate checksums matched the 1x4 authority:
- q sum: `2.63219253438378223e-04`;
- tangent sum: `-1.46925912412419313e-01`.

All configurations completed successfully.

No production source or physical semantics changed.

## Interpretation

This is a material result.

The same four visible logical CPUs perform substantially more total SWAP work when the workload is split across two or four independent OS processes than when one application context drives four OpenMP workers.

The experiment does not yet identify the cause.

Plausible classes that remain open:
- OpenMP runtime/scheduling overhead;
- SMT placement or affinity effects;
- cache locality;
- allocator/runtime isolation;
- per-process working-set effects;
- synchronization inside the one-process worker path.

The result is too large to treat as timing noise or micro-optimization.

## Decision

Advance a dedicated decomposition workunit:

`F-PE-MULTIPROC02 — process-partitioning gain attribution`

The successor must preserve the frozen 1x4 / 2x2 / 4x1 workload and discriminate at least:
- CPU affinity / SMT placement;
- OpenMP binding policy;
- process launch cost versus steady-state execution;
- repeated persistent-process execution;
- if practical, worker scheduling overhead.

Do not production-admit multi-process partitioning from MULTIPROC01 alone.

