# F-PE-MIQUAL02 preregistration — reference-valid post-admission manager qualification

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

Parent authorities:

- Z43E: `QUALIFIED_Z43E_PRODUCTION_ADMISSION_CANDIDATE_READY`;
- Z43F: `QUALIFIED_Z43F_CANONICAL_ADMISSION_READY`;
- MIQUAL01: `MIQUAL01_REFERENCE_COVERAGE_INSUFFICIENT`.

MIQUAL01 exposed reference solvability only and did not execute adaptive holdouts.

## Purpose

Qualify the canonically admitted moving-interface manager on the complete MIQUAL01 reference-valid subset without changing numerical or physical settings.

This is the first post-admission manager qualification on a bank selected solely by full-reference solvability.

## Frozen cases

Exactly:

1. B01_N64_T49
2. B12_N64_T49
3. O05_N64_T49
4. B12_N32_T25
5. O05_N32_T25

No case may be added, replaced, or removed after result exposure.

## Frozen numerical and trajectory contract

Reuse MIQUAL01/Z43E unchanged:

- MAXIT16 evidence profile;
- max_backtracking = 8;
- conductivity implicit mode = 0;
- conductivity mean = 1;
- dt = 0.00125 d;
- fixed top flux = -0.01 cm/d;
- qbot = 0;
- zero sources/sinks;
- 4,000 nominal intervals;
- independent full and adaptive trajectories;
- compiled Heritage/reference HeadCalc;
- no adaptive-state repair from full.

MAXIT16 remains evidence scope only.

## Reference guard

All five full-reference preflights must complete again.

Any unexpected reference failure classifies `MIQUAL02_REFERENCE_REGRESSION`.

## Physical gates

For every case require:

- full and adaptive completion;
- finite state;
- max adaptive per-interval physical ledger <= 5e-8 cm;
- no accepted-origin leak;
- contiguous saturated tail;
- ownership change <=1 face per interval;
- max |h adaptive-full| <=5e-3 cm;
- max |theta adaptive-full| <=5e-6;
- final tails equal or differ by at most one face;
- identical ordered ownership directions.

## Manager-route gates

Require per case:

- reduced-route fraction >=95%;
- fallback + bypass <=5%;
- no silent fallback;
- all fallback/bypass reasons typed by manager contract.

Report active-dimension histogram, mean active dimension, and request/candidate reallocations.

## Performance gates

Report per case:

- full trajectory wall time;
- adaptive trajectory wall time;
- adaptive/full wall ratio;
- deterministic work ratio.

Aggregate qualification requires:

- no wall ratio >1.10;
- geometric-mean wall ratio <1.00;
- at least 3/5 wall ratios <0.98;
- geometric-mean deterministic work ratio <0.90.

These are solver/trajectory metrics only.

## Frozen classifications

- `QUALIFIED_MIQUAL02_REFERENCE_VALID_MANAGER_BANK`
- `MIQUAL02_REFERENCE_REGRESSION`
- `MIQUAL02_PHYSICAL_MISMATCH`
- `MIQUAL02_OPERATIONAL_ROUTE_FAILURE`
- `MIQUAL02_PERFORMANCE_NOT_READY`
- `MIQUAL02_EXECUTION_INVALID`

## Consequence

If qualified, proceed to a separate forcing/regime-diversity successor. Do not return to local reconstruction micro-tuning unless a specific failure requires it.

## Production boundary

No default change.

Moving-interface manager remains explicit opt-in and `LEGACY_NUMERICS` remains production default.
