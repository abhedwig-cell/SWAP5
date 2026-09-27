# F-PE-MULTIPROC04 P0 result — persistent-process steady-state decomposition

Date: 2026-09-27

Status: `P0_PERSISTENT_EQUIVALENT_SETUP_DOMINANT`

PR:
`#675 — F-PE-MULTIPROC04: persistent-process steady-state decomposition`

Measured head:
`f493b6bd5860ce8ea4c8f34fb50ac01611495aa6`

Workflow run:
`36349978093`

## Persistent protocol

Each configuration:
- initialized processes once;
- built application context once;
- captured origin once;
- warmed once;
- then executed seven persistent measured RUN rounds;
- reported setup separately from persistent wall-clock.

Frozen configurations:
- 1x4;
- 2x2;
- 4x1.

Aggregate q and tangent checksums matched at every N.

## Results

### N=1,000

Setup:
- 1x4: 0.088991107 s;
- 2x2: 0.069766115 s;
- 4x1: 0.080974254 s.

Persistent wall:
- 1x4: 0.037241453 s;
- 2x2: 0.036682986 s, 1.015224x versus 1x4;
- 4x1: 0.039848568 s, 0.934574x.

### N=10,000

Setup:
- 1x4: 0.701733411 s;
- 2x2: 0.488101316 s;
- 4x1: 0.480393284 s.

Persistent wall:
- 1x4: 0.375527812 s;
- 2x2: 0.367946769 s, 1.020604x;
- 4x1: 0.389516951 s, 0.964086x.

### N=40,000

Setup:
- 1x4: 3.987025355 s;
- 2x2: 1.640667212 s;
- 4x1: 1.263587834 s.

Persistent wall:
- 1x4: 0.891663530 s;
- 2x2: 0.893549718 s, 0.997889x;
- 4x1: 0.871318006 s, 1.023350x.

## Interpretation

Persistent physical-trial throughput is effectively equivalent across 1x4, 2x2 and 4x1 at production-relevant N.

The large process-partitioning gains observed in MULTIPROC01/02 were therefore not a fundamental steady-state runtime advantage.

The dominant effect is setup/application-context construction.

At N=40,000:
- setup 1x4: 3.99 s;
- setup 2x2: 1.64 s;
- setup 4x1: 1.26 s.

The setup phase is therefore the next measurable large-N performance target.

## Decision

Close multi-process partitioning as a steady-state performance architecture route.

Do not add production process partitioning solely for repeated SWAP trial speed.

Select:
`F-PE-SETUP01 — large-N production application-context setup decomposition`

The successor must decompose at least:
- fixture/application-plan materialization;
- participant/backend initialization;
- application-context bind;
- origin capture;
- first warm trial;
- any N-sized validation/copy/allocation work.

The target is the one-process 1x4 production architecture at N=10,000 and N=40,000.

