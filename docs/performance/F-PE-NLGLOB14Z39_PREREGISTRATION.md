# F-PE-NLGLOB14Z39 preregistration — compiled Richards solve-service manager-overhead amortization

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z38: `Z38_PERSISTENT_MANAGER_TIMING_REGRESSION`;
- persistent manager path reduced Z37 geomean regression from ~1.302 to ~1.116;
- remaining fixed reduced-path overhead is approximately 0.01–0.02 microseconds per frozen operation;
- Z38 full microkernel itself is only approximately 0.14 microseconds per operation.

## Purpose

Measure the real compiled Heritage Richards solve-service cost scale and determine whether the remaining persistent-manager fixed overhead is material once amortized over an actual nonlinear solve.

Z39 does not yet benchmark a reduced Heritage HeadCalc solve. It quantifies whether the remaining manager seam overhead is large enough to justify more seam micro-optimization before implementing that binding.

## Frozen fixtures

Use one repeated single-step reference Richards solve for each BOFEK01 representative material:

- B01;
- B12;
- O05;
- O14.

Common fixture:

- 16 nodes;
- dz = 10 cm;
- initial pressure head = -100 cm;
- fixed top flux = -0.01 cm/d;
- prescribed qbot = 0;
- dt = 0.00125 d;
- K implicit mode = 0;
- conductivity mean method = 1;
- max iterations = 8;
- identical accepted origin for every repetition.

No trajectory advancement occurs during timing.

## Timing protocol

Compile the existing Heritage/reference solve service with `-O3`.

For each material:

- setup providers/request/workspace once;
- 50 warm-up solve calls;
- 5 measured blocks;
- 200 solve calls per block;
- each call starts from the same immutable request/base state;
- reuse the same workspace;
- consume candidate output in a checksum;
- report median and mean seconds per solve;
- require every solve to converge.

## Frozen amortization metric

Use the Z38 measured persistent-manager excess time as frozen reference overhead:

- n=13 representative excess:
  approximately `0.018 microseconds/op`;
- n=12 representative excess:
  approximately `0.009 microseconds/op`.

For each material compute:

`overhead_fraction_13 = 0.018 us / median_full_richards_solve_time`

and

`overhead_fraction_12 = 0.009 us / median_full_richards_solve_time`.

## Frozen classifications

### `QUALIFIED_Z39_MANAGER_OVERHEAD_AMORTIZED`

Require:

- 4/4 materials converge;
- median solve time finite and positive;
- manager-overhead fraction <5% for n=13 on all 4 materials;
- manager-overhead fraction <5% for n=12 on all 4 materials.

### `Z39_MANAGER_OVERHEAD_MATERIAL`

All solves valid, but either frozen overhead fraction is >=5% in any material.

### `Z39_RICHARDS_TIMING_EXECUTION_INVALID`

Build, convergence, timer or checksum failure.

## Interpretation boundary

A positive Z39 result does **not** prove end-to-end reduced-manager speedup.

It proves only that the remaining Z38 fixed manager overhead is too small relative to an actual Richards solve to justify further sub-microsecond seam optimization before implementing the real reduced solve-service binding.

## Consequence

If overhead is amortized, stop manager micro-optimization and move to the actual reduced Heritage solve-service binding / end-to-end focused benchmark.

If overhead remains material, profile only the remaining manager refresh/materialization operations.

## Stop rules

Do not:

- change the Z38 timing evidence;
- infer reduced Richards speedup from full solve timing alone;
- broaden to long trajectories;
- change production default;
- alter physics.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z39

BASELINE: `ad99ea79286fe7b9f92ea6a142b72c4478543b59`

BRANCH: `research/f-pe-nlglob14z39-richards-amortization`

NEXT SAFE STEP: one compiled single-step Richards timing executable across the four frozen materials.

## Production boundary

Research timing only.

`LEGACY_NUMERICS` remains production default.
