# F-PE-NLGLOB14Z38 preregistration — zero-waste persistent manager fast path

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z37: `Z37_FORTRAN_TIMING_REGRESSION`;
- geometric-mean compiled timing ratio ~1.3017;
- mean structural work ratio 0.796875;
- timing loss attributed to per-operation orchestration/allocation overhead.

## Purpose

Remove avoidable allocation/copy overhead from the manager path without changing any reduced physics, manager semantics, benchmark cases, compiler flags or timing protocol.

## Frozen optimization scope

Allowed changes:

1. add an in-place reduced-request preparation API;
2. allocate reduced parameter/state buffers only when active dimension changes;
3. reuse reduced workspace across repeated same-shape solves;
4. add in-place full-candidate materialization;
5. reuse caller-owned tail scratch;
6. avoid redundant whole-derived-type assignments where equivalent field copies suffice.

Not allowed:

- changing numerical coefficients;
- changing active dimensions;
- changing benchmark repetitions;
- changing optimization flags;
- dropping fallback/bypass diagnostics;
- changing physical-state authority;
- changing production defaults.

## Frozen benchmark

Replay the exact Z37 cases:

- O05_T13, n=13;
- O05_T12, n=12;
- O14_T13, n=13;
- B12_T13, n=13.

Replay exactly:

- warm-up 5,000 operations per route;
- 10 measured blocks;
- 10,000 operations per block;
- `-O3`;
- full/reduced measured in alternating blocks;
- checksum anti-optimization.

The full path remains unchanged from Z37.

The reduced path may differ only by using persistent/in-place manager APIs and preallocated reusable workspace/scratch.

## Correctness gates

Require:

- all checksums finite;
- same reduced active dimensions as Z37;
- manager selected route remains reduced;
- published candidate remains full-shaped;
- persistent request/state shapes remain correct;
- no fallback/bypass semantics are removed.

## Frozen performance classifications

### `QUALIFIED_Z38_PERSISTENT_MANAGER_TIMING_GAIN`

Require:

- reduced/full timing ratio <0.95 in at least 3/4 cases;
- geometric mean <0.95;
- no case >1.05;
- mean structural work ratio <=0.90.

### `Z38_PERSISTENT_MANAGER_TIMING_NEUTRAL`

Geometric mean 0.95–1.05 and no case >1.10.

### `Z38_PERSISTENT_MANAGER_TIMING_REGRESSION`

Geometric mean >1.05 or any case >1.10.

### `Z38_PERSISTENT_MANAGER_EXECUTION_INVALID`

Correctness/timer/build invalid.

## Attribution diagnostics

Additionally report:

- reduced request buffer reallocations;
- reduced workspace shape reallocations;
- full candidate buffer reallocations.

For same-shape repeated blocks, expected steady-state reallocation count is zero.

## Consequence

A timing gain authorizes the first end-to-end SWAP manager benchmark.

Neutral/regression requires profiling the remaining manager overhead before end-to-end rollout.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z38

BASELINE: `eb78962a11912feaa191c78c32882a809a24a61a`

BRANCH: `research/f-pe-nlglob14z38-persistent-manager-fast-path`

NEXT SAFE STEP: add in-place manager APIs, replay exact Z37 compiled benchmark.

## Production boundary

Research optimization only.

`LEGACY_NUMERICS` remains production default.
