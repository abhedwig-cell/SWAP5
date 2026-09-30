# F-PE-NLGLOB14Z43D preregistration — reference-only heterogeneous holdout replacement selection

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z43C: `Z43C_REFERENCE_PROFILE_NOT_VIABLE`;
- under the frozen explicit MAXIT16 test profile, H1 O05/N64, H3 B12/N64 and H4 O05/N32 complete 4,000 intervals;
- H2 O14/N64 still fails at interval 286;
- no further MAXIT tuning is authorized.

## Purpose

Select one reference-solvable heterogeneous replacement fixture for O14 before any new adaptive-manager timing/admission evidence is observed.

Z43D is reference-only.

## Frozen explicit numerical test profile

Reuse exactly Z43C:

- max_iterations = 16;
- max_backtracking = 8;
- conductivity implicit mode = 0;
- conductivity mean = 1;
- min step duration = 1e-6 d;
- compartment and total balance tolerance = 1e-12;
- head absolute and relative tolerance = 1e-9;
- ponding tolerance = 1e-10.

This remains a non-default test profile.

## Frozen candidate family and order

Use B01 only, because B01 is already present in the pre-admission Richards timing family and is independent of the failed O14 fixture.

Evaluate exactly in this deterministic order:

1. `B01_N64_T49`;
2. `B01_N32_T25`.

Common forcing:

- dz = 10 cm;
- dt = 0.00125 d;
- fixed top flux = -0.01 cm/d;
- qbot = 0;
- zero sources/sinks;
- 4,000 nominal intervals;
- full Heritage/reference route only.

Stop candidate search at the first fixture that completes all 4,000 intervals.

Do not execute adaptive-manager timing in Z43D.

## Frozen diagnostics

Per attempted candidate report:

- first-step status;
- completion status;
- first failing interval if any;
- retry_advised;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- internal retries;
- diagnostics route;
- max accepted per-interval physical ledger;
- origin and final/last accepted tail.

## Frozen classifications

### `QUALIFIED_Z43D_REFERENCE_REPLACEMENT_SELECTED`

At least one candidate completes 4,000 intervals. Persist exactly one selected replacement: the first passing candidate in frozen order.

### `Z43D_NO_REFERENCE_SOLVABLE_REPLACEMENT`

Both frozen B01 candidates fail.

### `Z43D_EXECUTION_INVALID`

Build/reporting invalid.

## Consequence

A positive result authorizes a separately preregistered revised admission-candidate run using:

- O05_N64_T49;
- B12_N64_T49;
- O05_N32_T25;
- the selected B01 replacement;

all under the unchanged explicit MAXIT16 test profile.

No production default changes.

## Stop rules

Do not:

- try a third candidate inside Z43D;
- change MAXIT;
- change forcing/tolerances after exposure;
- invoke adaptive manager;
- infer performance from the reference preflight.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z43D

BASELINE: `749d23e246b1d007f7b8b660a3212585d5ec4214`

BRANCH: `research/f-pe-nlglob14z43d-reference-holdout-replacement`

NEXT SAFE STEP: reference-only deterministic B01 candidate preflight.

## Production boundary

Reference-fixture selection only.

`LEGACY_NUMERICS` remains production default.
