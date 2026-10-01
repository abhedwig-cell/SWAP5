# F-PE-MIQUAL14 preregistration — serialized manager scale-crossover benchmark

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@7db09b56deb99decf32f47d2deed72710a04e8b5`

Parent authority:

- MIQUAL13: `MIQUAL13_OVERHEAD_REDUCED_BUT_NOT_RECOVERED`.

## Purpose

Determine whether the residual fixed serialized-manager composition cost becomes smaller than the solver saving at larger, representative column dimensions.

This workunit changes geometry only. Physics, runtime path, manager semantics and numerical settings remain frozen.

## Frozen geometries

Use exactly:

- N16 / tail start 13;
- N32 / tail start 25;
- N64 / tail start 49.

These saturated-tail shapes already occur in the qualified manager research/qualification bank.

## Frozen workload

For every geometry:

- equilibrium hydrostatic initial state;
- top flux = 0;
- qbot = 0;
- B110 default MvG hydraulics;
- no optional physics;
- zero sources/sinks;
- SWKIMPL=0;
- conductivity mean method=1;
- explicit moving-interface profile only for MANAGER;
- checkpoint -> serialized trial -> candidate -> kernel commit every interval;
- dt = 0.00125 d;
- exactly 20,000 committed intervals per measurement.

The 20,000-interval length is frozen before timing exposure and is chosen to make each process timing long enough for paired comparison while keeping the single Action bounded.

## Variants

- LEGACY: manager disabled.
- MANAGER: MIQUAL13 fused persistent fast path enabled.

## Preflight

Each geometry and variant must complete once before timing.

Require:

- 20,000/20,000 committed intervals;
- zero retries;
- hard mass <=1e-8 cm;
- LEGACY/MANAGER final pressure head difference <=1e-12;
- final theta difference <=1e-12;
- storage difference <=1e-12;
- identical final tail;
- manager reduced fraction =100%;
- zero fallback/bypass.

## Paired timing protocol

Per geometry:

- one untimed warmup per variant;
- exactly 7 paired repetitions;
- odd pairs LEGACY -> MANAGER;
- even pairs MANAGER -> LEGACY;
- no outlier deletion or substitution.

Report per geometry:

- all wall ratios;
- median wall ratio;
- geometric-mean wall ratio;
- median CPU ratio;
- deterministic work ratio.

## Frozen classification

`QUALIFIED_MIQUAL14_SERIALIZED_SCALE_CROSSOVER` requires:

- all physical/route gates pass;
- N64 median wall ratio <0.99;
- N64 median CPU ratio <0.99;
- N64 deterministic work ratio <0.85.

N32 is reported and may strengthen the result but is not required to cross below 1.00.

If N64 remains >=1.00:

`MIQUAL14_NO_SCALE_CROSSOVER_TO_N64`.

Other classes:

- `MIQUAL14_PHYSICAL_MISMATCH`
- `MIQUAL14_MANAGER_ROUTE_FAILURE`
- `MIQUAL14_EXECUTION_INVALID`.

## Interpretation boundary

A positive result establishes a scale crossover only for the frozen equilibrium/basic-Richards serialized runtime. It does not establish dynamic or MultiSWAP speedup.

A positive N64 result would justify moving toward a bounded production-admission candidate for sufficiently large eligible columns, rather than further N16 micro-optimization.

## Production boundary

`LEGACY_NUMERICS` remains production default.
