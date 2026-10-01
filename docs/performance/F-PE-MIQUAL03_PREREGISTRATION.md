# F-PE-MIQUAL03 preregistration — fixed-flux forcing diversity

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

Parent authority:

`QUALIFIED_MIQUAL02_REFERENCE_VALID_MANAGER_BANK`

## Purpose

Test whether the canonically admitted moving-interface manager remains physically valid and performance-positive when the top-boundary forcing varies materially, while preserving a valid reconstructible saturated-tail geometry.

This workunit intentionally keeps the top boundary as explicit fixed flux. Dynamic-top/ponding is a separate successor because those semantics add a second mechanism and should not be confounded with moving-interface forcing response.

## Frozen material/geometry bank

Use exactly the five MIQUAL02 reference-valid material/geometry pairs:

- B01_N64_T49;
- B12_N64_T49;
- O05_N64_T49;
- B12_N32_T25;
- O05_N32_T25.

## Frozen forcing levels

For every material/geometry pair run exactly five top-flux levels:

- `DRYING`: +0.02 cm/d;
- `NEUTRAL`: 0.00 cm/d;
- `BASE`: -0.01 cm/d;
- `INFILTRATION`: -0.10 cm/d;
- `STRONG_INFILTRATION`: -1.00 cm/d.

Sign convention follows the existing fixed-flux/ledger contract used by Z43E/MIQUAL02, where negative top flux adds water to storage.

This yields 25 frozen cases.

## Frozen numerical and trajectory contract

Unchanged from MIQUAL02 except the top flux:

- MAXIT16 evidence profile;
- max_backtracking = 8;
- conductivity implicit mode = 0;
- conductivity mean = 1;
- dt = 0.00125 d;
- qbot = 0;
- zero sources/sinks;
- 4,000 nominal intervals;
- independent full and adaptive trajectories;
- compiled Heritage/reference HeadCalc;
- no adaptive-state repair from full.

MAXIT16 remains evidence scope only.

## Reference preflight and exposure rule

All 25 cases run full-reference preflight first.

A case is reference-valid only if the full route completes all 4,000 intervals.

Adaptive execution is allowed only for reference-valid cases.

No failed reference case may be replaced after exposure.

Broad forcing qualification requires:

- at least 20/25 reference-valid cases;
- all five forcing classes represented by at least three reference-valid material/geometry pairs.

## Physical gates

For every reference-valid adaptive case require:

- full and adaptive completion;
- finite state;
- max adaptive per-interval physical ledger <= 5e-8 cm;
- no accepted-origin leak;
- contiguous saturated tail;
- ownership change <= 1 face per interval;
- max |h adaptive-full| <= 5e-3 cm;
- max |theta adaptive-full| <= 5e-6;
- final tails equal or differ by at most one face;
- identical ordered ownership directions.

## Manager-route gates

Per reference-valid case require:

- reduced-route fraction >=95%;
- fallback + bypass <=5%;
- no silent fallback;
- typed fallback/bypass reason.

Report active-dimension histogram, mean active dimension and allocation counters.

## Performance gates

For every reference-valid case report wall and deterministic work ratios.

Aggregate qualification requires:

- no wall ratio >1.10;
- geometric-mean wall ratio <1.00;
- at least 75% of reference-valid cases wall ratio <0.98;
- geometric-mean deterministic work ratio <0.90.

## Frozen classifications

- `QUALIFIED_MIQUAL03_FIXED_FLUX_FORCING_DIVERSITY`
- `MIQUAL03_REFERENCE_COVERAGE_INSUFFICIENT`
- `MIQUAL03_PHYSICAL_MISMATCH`
- `MIQUAL03_OPERATIONAL_ROUTE_FAILURE`
- `MIQUAL03_PERFORMANCE_NOT_READY`
- `MIQUAL03_EXECUTION_INVALID`

## Consequence

If qualified, proceed to dynamic-top / infiltration-runoff-ponding qualification.

If reference coverage is insufficient, localize by forcing class before any numerical-policy change.

If adaptive physics fails on a reference-valid case, open a targeted mechanistic successor for that case only.

## Production boundary

No default change.

Moving-interface manager remains explicit opt-in.

`LEGACY_NUMERICS` remains production default.
