# F-PE-NLGLOB14Z37 preregistration — compiled Fortran manager timing qualification

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z36: `QUALIFIED_Z36_COMPACT_HOLDOUT_READY_FOR_FORTRAN_TIMING`;
- four-case physical holdout passes 4/4;
- mean deterministic work ratio = 0.796875;
- Python timing is explicitly non-production and not useful for performance claims;
- Z34/Z35 manager seam and physical binding are qualified.

## Purpose

Determine whether the reduced moving-interface path provides measurable wall-clock benefit in compiled Fortran when manager/view/materialization overhead is included.

Z37 is a focused timing qualification, not a long trajectory campaign.

## Frozen case set

Use the same structural geometries as Z36:

1. O05 tail 13:16, active n=13;
2. O05 tail 12:16, active n=12;
3. O14 tail 13:16, active n=13;
4. B12 tail 13:16, active n=13.

The benchmark may materialize deterministic coefficient/state fixtures corresponding to those geometries, but may not tune them after timing exposure.

## Frozen compiled benchmark shape

Run full and reduced paths inside one Fortran executable and one process.

Each measured operation must include:

### Full path
- full 16-node workspace preparation;
- full-dimension linear/nonlinear work surrogate owned by production solver primitives;
- full candidate materialization.

### Reduced manager path
- manager active-view derivation;
- reduced request/view preparation;
- reduced workspace preparation at n=12 or n=13;
- reduced-dimension production linear-solver work;
- analytic tail materialization back to full 16-node shape;
- manager route selection.

Use existing production primitives:
- `reference_richards_workspace_t`;
- `reference_tridag` or the same production linear-solver primitive;
- `mod_moving_interface_manager`.

Do not introduce a separate optimized benchmark-only solver kernel.

## Timing protocol

For every frozen case:

- warm-up: 5,000 operations per route;
- measured: 100,000 operations per route;
- full and reduced route measured in alternating blocks to limit clock drift;
- use a monotonic/process CPU timer available in standard Fortran;
- report total and per-operation times.

To reduce timer noise, perform at least 10 measured blocks of 10,000 operations per route.

Report:
- median block time per operation;
- mean block time per operation;
- reduced/full timing ratio;
- deterministic structural work ratio;
- manager overhead fraction where measurable.

## Anti-optimization requirement

Each repeated solve must feed its output into a checksum consumed after the timed loop.

Compiler optimization may not eliminate the numerical operations.

## Frozen performance classifications

### `QUALIFIED_Z37_FORTRAN_TIMING_GAIN`

Require:
- all 4 cases execute correctly;
- reduced/full timing ratio < 0.95 in at least 3/4 cases;
- geometric mean timing ratio < 0.95;
- no case timing ratio > 1.05;
- checksums finite;
- structural work ratio remains <=0.90 mean.

### `Z37_FORTRAN_TIMING_NEUTRAL`

Use if geometric mean ratio is 0.95–1.05 and no correctness failure occurs.

### `Z37_FORTRAN_TIMING_REGRESSION`

Use if geometric mean ratio >1.05 or any case ratio >1.10.

### `Z37_TIMING_EXECUTION_INVALID`

Use for timer/optimization/build problems that invalidate measurement.

## Claim boundary

Z37 timing qualifies only the compiled production-shaped manager/solver seam.

It is not yet whole-SWAP end-to-end runtime.

A positive result authorizes an end-to-end application benchmark; neutral/negative result requires profiling before broader rollout.

## Stop rules

Do not:
- change the frozen repetitions after seeing timing;
- drop slow cases;
- change optimization flags between routes;
- infer whole-model speedup from this benchmark;
- change production defaults.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z37

BASELINE: `ddc5712533e0bdbd1b0979df680a084251382794`

BRANCH: `research/f-pe-nlglob14z37-fortran-manager-timing`

NEXT SAFE STEP: implement one compiled benchmark executable using production workspace/linear-solver/manager primitives.

## Production boundary

Research timing only.

`LEGACY_NUMERICS` remains production default.
