# F-PE-NLGLOB14Z36 preregistration — compact holdout and timing qualification

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z35: `QUALIFIED_Z35_MANAGER_PHYSICAL_BINDING_SMOKE`;
- Z34: manager seam qualified;
- Z31R/Z33: long-horizon O05 reduced manager physically viable with about 20% deterministic work reduction;
- Z32: no material same-origin local equation defect.

## Purpose

Test whether the reduced moving-interface solve remains physically acceptable outside the single O05 smoke and whether the expected structural work reduction survives a deliberately small heterogeneous holdout.

This is not a BOFEK-wide campaign.

## Frozen holdout set

Use exactly four synthetic, production-shaped 16-node states generated from repository-backed hydraulic archetypes.

All use:

- dz = 10 cm;
- qbot = 0;
- dry surface-flux top semantics;
- dt = 6.25e-5 d;
- contiguous hydrostatic saturated lower tail;
- guard node retained as active nonlinear node;
- same full/reduced equations as Z29/Z31R/Z35.

Cases:

1. `O05_T13`
   - material O05;
   - tail 13:16;
   - active n=13.

2. `O05_T12`
   - material O05;
   - tail 12:16;
   - active n=12.

3. `O14_T13`
   - material O14;
   - tail 13:16;
   - active n=13.

4. `B12_T13`
   - material B12;
   - tail 13:16;
   - active n=13.

For each case construct a hydrostatic lower tail and an unsaturated upper profile by setting the guard/tail geometry consistently and keeping at least one node immediately above the guard unsaturated.

No case may be modified after result exposure.

## Frozen physical gates

For each case, from an identical origin compare one full and one reduced candidate.

Require:

- both converge;
- finite states;
- resulting tail identity equal;
- max |h reduced-full| <= 5e-6 cm;
- max |theta reduced-full| <= 5e-9;
- top-flux difference <= 5e-9 cm/d;
- ledger difference <= 5e-8 cm;
- provider route identical;
- reduced active dimension < 16;
- no ownership jump >1 face.

## Frozen work metric

Per case:

`W_ratio = reduced_iterations * active_nodes / (full_iterations * 16)`.

Compact holdout work qualification requires:

- mean W_ratio <= 0.90;
- no case W_ratio > 1.00.

## Local timing protocol

Timing is secondary and exploratory-but-frozen.

For each case execute, in one local Python process:

- 200 repeated full solves from the exact same origin;
- 200 repeated reduced solves from the exact same origin;
- discard first 20 repetitions as warm-up;
- report median per-solve wall time for the remaining 180;
- report reduced/full timing ratio.

Do not use timing as a hard scientific gate because this Python dense-Jacobian harness is not production Fortran.

The timing result is used only to determine whether Fortran timing work is worth opening.

## Fallback / applicability reporting

For every frozen case report:

- tail eligibility;
- active dimension;
- solve convergence;
- physical gate result;
- fallback would be required: yes/no;
- reason if ineligible or failed.

No silent fallback is allowed in the evidence.

## Frozen classifications

### `QUALIFIED_Z36_COMPACT_HOLDOUT_READY_FOR_FORTRAN_TIMING`

Require:

- 4/4 physical gates pass;
- zero fallback-required cases;
- mean deterministic W_ratio <=0.90;
- no W_ratio >1.0.

### `Z36_HOLDOUT_PHYSICAL_MISMATCH`

Any full/reduced physical comparison gate fails.

### `Z36_HOLDOUT_SOLVE_OR_APPLICABILITY_FAILURE`

Any case is ineligible or fails to solve.

### `Z36_WORK_REDUCTION_NOT_PRESERVED`

All physical gates pass but work criteria fail.

## Consequence

A positive Z36 result authorizes one focused production-Fortran timing/integration workunit on the already-qualified manager seam.

A negative result must be localized before broader testing.

## Stop rules

Do not:

- broaden the holdout inside Z36;
- change dt or gates after exposure;
- tune case geometry after exposure;
- change production defaults;
- infer production wall-clock gain from Python timing;
- launch broad GitHub Actions runs.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z36

BASELINE: `9bf43a6e5e5ffae61410f0f7667ac5295be2d263`

BRANCH: `research/f-pe-nlglob14z36-compact-holdout-timing`

NEXT SAFE STEP: execute the frozen four-case holdout locally; use GitHub only to persist evidence.

## Production boundary

Research holdout only.

`LEGACY_NUMERICS` remains production default.
