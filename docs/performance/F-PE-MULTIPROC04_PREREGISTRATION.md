# F-PE-MULTIPROC04 — persistent-process steady-state decomposition

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent:
`F-PE-MULTIPROC03 / PR #673`

Parent head:
`00e239f35c79d06c362e3e800905b7742ecfba32`

Branch:
`work/f-pe-multiproc04-persistent-process`

## Trigger

MULTIPROC01/02 found large end-to-end process-partitioning gains at large N, but those measurements started their wall-clock before each subprocess initialized its application context and warm-up path.

MULTIPROC03 then showed that the repeated steady-state 1x4 trial at N=40,000 costs about 1.54 s, far below the ~7.38 s end-to-end subprocess wall time measured earlier.

Compact worker dispatch did not explain the deficit.

## Purpose

Separate:
1. process/application-context initialization cost;
2. one-time warm-up;
3. persistent repeated trial throughput.

The primary question is whether process partitioning remains beneficial after all processes are already initialized and ready.

## Frozen configurations

At equal total N:

- 1x4: one persistent process with N columns and 4 workers;
- 2x2: two persistent processes with N/2 columns and 2 workers each;
- 4x1: four persistent processes with N/4 columns and 1 worker each.

Primary populations:
- N=10,000;
- N=40,000.

Each subprocess:
- initializes once;
- captures accepted origin once;
- performs one unmeasured warm-up;
- signals READY;
- remains alive for all measured rounds.

## Measurements

For each configuration:
- record wall-clock from process launch until all subprocesses report READY;
- then execute 5 synchronized persistent RUN rounds;
- for each round, start the clock only after all processes are ready and immediately before RUN commands are issued;
- stop when every process reports completion;
- report median steady-state round time;
- report total columns/s;
- report q/tangent aggregate checksums.

Process teardown is excluded from steady-state timing.

## Semantic gate

Aggregate q and tangent checksums must match 1x4 within strict floating-point aggregation tolerance.

Each persistent subprocess must remain deterministic across repeated rounds.

## Interpretation

Relative to persistent 1x4:

- `PERSISTENT_PROCESS_WIN`: >=5% throughput gain;
- `PERSISTENT_EQUIVALENT`: within +/-5%;
- `PERSISTENT_THREAD_WIN`: process-partitioned configuration >=5% slower.

Initialization gain is reported separately and must not be confused with steady-state gain.

## Decision

If process partitioning remains >=5% faster at N=40,000:
- retain a process-partitioning architecture candidate;
- proceed to attribution of remaining steady-state cause and production integration constraints.

If persistent configurations are equivalent:
- classify prior large gain primarily as initialization/context-construction parallelism;
- optimize large-N setup only if production lifecycle makes that cost material.

If 1x4 is faster:
- close process partitioning as a steady-state route.

## Production boundary

Research only.
No production `src/**` changes.
No change to physics, tolerances, temporal policy, tangent mathematics, transaction semantics, aggregation or MODFLOW equations.
