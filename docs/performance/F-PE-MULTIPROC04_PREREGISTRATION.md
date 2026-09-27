# F-PE-MULTIPROC04 — persistent-process steady-state decomposition

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent:
`F-PE-MULTIPROC03 / PR #673`

Parent head:
`00e239f35c79d06c362e3e800905b7742ecfba32`

Branch:
`work/f-pe-multiproc04-persistent-steady-state`

## Trigger

MULTIPROC01/02 found large process-partitioning gains when each measured round launched fresh processes.

MULTIPROC03 then showed that pure repeated 1x4 trial time is much smaller than the fresh-process outer wall:
- N=40,000 fresh-process 1x4 wall: ~7.384 s;
- N=40,000 persistent repeated 1x4 trial: ~1.538 s.

Therefore the earlier process gain may be dominated by parallel initialization/application-context construction rather than by persistent trial execution.

## Purpose

Separate:
1. one-time process/application-context setup and warm-up;
2. persistent repeated trial execution.

Compare the same total logical population as:
- 1x4;
- 2x2;
- 4x1.

## Persistent protocol

For each configuration:
- launch the required processes once;
- each process initializes its application context once;
- capture origin once;
- execute one unmeasured warm-up trial;
- signal READY;
- retain the process and application context;
- execute 7 measured persistent rounds;
- in each round all processes receive RUN concurrently;
- measure parent wall-clock from RUN dispatch until all processes report completion;
- each child also reports its own trial-only elapsed time;
- discard candidates after each trial while retaining the accepted origin;
- terminate only after all rounds complete.

Process launch, initialization and warm-up are excluded from steady-state timing and reported separately as SETUP.

## N ladder

Run:
- N=1,000;
- N=10,000;
- N=40,000.

N is total population across all processes and must be divisible by 4.

## Semantic authority

For every N and configuration:
- aggregate q checksum must match 1x4;
- aggregate tangent checksum must match 1x4;
- repeated output must be deterministic;
- all child processes must complete all rounds.

## Interpretation

Use median persistent parent wall-clock.

Relative to persistent 1x4:

- `PERSISTENT_PROCESS_WIN`: >=10% faster at N=10,000 or >=20% faster at N=40,000;
- `PERSISTENT_EQUIVALENT`: within +/-5% at N=10,000 and N=40,000;
- `MIXED`: anything between those envelopes.

Setup is interpreted separately. A setup-only process advantage is not sufficient to justify a long-lived multi-process production architecture.

## Decision rule

If persistent process partitioning still wins materially:
- continue toward a bounded production architecture comparison.

If persistent configurations are equivalent:
- classify the earlier gain as setup/context-construction parallelism and move optimization effort to setup / memory initialization.

If persistent 1x4 wins:
- close process partitioning as a steady-state runtime route and optimize setup independently.

## Production boundary

Research only.

No production `src/**` change.
No physics, tolerance, temporal, tangent, transaction, aggregation or MODFLOW semantic change.
