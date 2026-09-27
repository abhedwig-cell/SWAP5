# F-PE-MULTIPROC04 P0 result — persistent-process steady-state decomposition

Date: 2026-09-27

Status: `P0_PERSISTENT_THREAD_ROUTE_RETained`

PR:
`#674 — F-PE-MULTIPROC04: persistent-process steady-state decomposition`

Measured head:
`3c98988650058feffa188fc4e7f2fd01ded54fa0`

Workflow run:
`36349942870`

## Purpose

Separate one-time process/application-context initialization from persistent repeated trial execution.

Frozen configurations:
- 1x4: one persistent process, four workers;
- 2x2: two persistent processes, two workers each;
- 4x1: four persistent processes, one worker each.

All subprocesses initialized once, captured accepted origin, performed one unmeasured warm-up and reported READY before steady-state timing began.

## N=10,000

### Initialization to READY

- 1x4: 0.760394295 s;
- 2x2: 0.504499747 s;
- 4x1: 0.502921389 s.

### Persistent steady-state

- 1x4: 0.391169822 s, 25,564.344 columns/s;
- 2x2: 0.411778486 s, 24,284.902 columns/s, 0.949952x versus 1x4;
- 4x1: 0.409866832 s, 24,398.168 columns/s, 0.954383x versus 1x4.

## N=40,000

### Initialization to READY

- 1x4: 6.756313578 s;
- 2x2: 2.672315600 s;
- 4x1: 2.302332629 s.

### Persistent steady-state

- 1x4: 1.562413453 s, 25,601.418 columns/s;
- 2x2: 1.640192594 s, 24,387.380 columns/s, 0.952579x versus 1x4;
- 4x1: 1.636249913 s, 24,446.143 columns/s, 0.954875x versus 1x4.

Aggregate q and tangent checksums were identical for every configuration.

## Interpretation

Process partitioning does not improve persistent steady-state physical trial throughput on this host.

At both N=10,000 and N=40,000, one 4-worker process is about 4.5-5% faster than persistent 2x2 or 4x1.

The previously observed large end-to-end process-partitioning advantage is therefore primarily an initialization/application-context construction effect.

The setup effect is strongly size dependent:
- at N=10,000, partitioning reduces launch-to-READY from about 0.76 s to about 0.50 s;
- at N=40,000, partitioning reduces launch-to-READY from about 6.76 s to about 2.30-2.67 s.

This is a large setup cost, but it is not evidence for a superior steady-state multi-process runtime architecture.

## Decision

Retain the simpler one-process worker-local production architecture for steady-state execution.

Do not production-admit process partitioning as the primary runtime architecture from MULTIPROC01-04.

Open a separate setup-lifecycle question only if production materializes large groundwater application contexts often enough for the N-dependent setup cost to matter end-to-end.

Recommended successor:
`F-PE-SETUP01 — large-N groundwater context materialization decomposition`

SETUP01 must first establish real production lifecycle frequency before optimizing setup.

