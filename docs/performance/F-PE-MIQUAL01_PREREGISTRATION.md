# F-PE-MIQUAL01 preregistration — broad post-admission moving-interface qualification

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

Parent authorities:

- Z43E: `QUALIFIED_Z43E_PRODUCTION_ADMISSION_CANDIDATE_READY`;
- Z43F: `QUALIFIED_Z43F_CANONICAL_ADMISSION_READY`;
- PR #920 merged the explicit non-default moving-interface manager into canonical;
- `LEGACY_NUMERICS` remains production default.

## Purpose

Test whether the canonically admitted moving-interface manager remains physically valid and performance-positive beyond the four frozen Z43E admission holdouts.

This workunit is post-admission qualification. It does not change manager physics, reconstruction, fallback semantics, numerical tolerances, or production defaults.

## Frozen numerical profile

Reuse the Z43E evidence profile unchanged:

- max_iterations = 16;
- max_backtracking = 8;
- conductivity implicit mode = 0;
- conductivity mean = 1;
- min step duration = 1e-6 d;
- compartment and total balance tolerance = 1e-12;
- head absolute and relative tolerance = 1e-9;
- ponding tolerance = 1e-10.

MAXIT16 remains evidence scope only and is not a universal production setting.

## Frozen bank

Use all four repository-backed hydraulic archetypes from
`docs/performance/F-PE-BOFEK01_TESTBANK.json`:

- B01;
- B12;
- O05;
- O14.

Run each at both already-qualified geometric shapes:

- N64 with initial saturated-tail start T49;
- N32 with initial saturated-tail start T25.

This yields exactly eight frozen cases:

1. B01_N64_T49
2. B12_N64_T49
3. O05_N64_T49
4. O14_N64_T49
5. B01_N32_T25
6. B12_N32_T25
7. O05_N32_T25
8. O14_N32_T25

Common trajectory contract:

- dz = 10 cm;
- dt = 0.00125 d;
- fixed top flux = -0.01 cm/d;
- qbot = 0;
- zero sources/sinks;
- 4,000 nominal intervals;
- independent full and adaptive trajectories;
- compiled Heritage/reference HeadCalc on both paths;
- no adaptive-state repair from full.

The BOFEK01 bank is explicitly a hydraulic-archetype bank, not a complete BOFEK-ID production catalogue. MIQUAL01 must not overclaim BOFEK-wide portability.

## Reference gate

Every frozen case first runs the full-reference preflight.

If the reference route fails, classify the case as reference-invalid for this frozen bank. Do not replace it after result exposure.

Aggregate qualification requires at least 6/8 reference-valid cases and at least three of the four hydraulic archetypes represented among reference-valid cases.

## Physical gates

For each reference-valid case require:

- full and adaptive trajectory completion;
- finite states;
- adaptive per-interval ledger <= 5e-8 cm;
- no accepted-origin leak;
- contiguous saturated tail;
- ownership jump <= 1 face per interval;
- max |h adaptive-full| <= 5e-3 cm;
- max |theta adaptive-full| <= 5e-6;
- final tails equal or differ by at most one face;
- identical ordered ownership directions.

## Manager-route gates

For each reference-valid case report:

- reduced-route fraction;
- fallback count;
- bypass count;
- fallback reasons;
- active-dimension histogram;
- mean active dimension;
- request/candidate reallocations.

Require:

- reduced route >=95%;
- fallback + bypass <=5%;
- no silent fallback;
- fallback/bypass reasons must be typed by the existing manager contract.

## Performance gates

For each reference-valid case report full/adaptive wall time and deterministic work.

Broad qualification requires:

- no case wall ratio > 1.10;
- geometric-mean wall ratio < 1.00;
- at least half of reference-valid cases wall ratio < 0.98;
- geometric-mean deterministic work ratio < 0.90.

This is solver/trajectory evidence only, not whole-SWAP or MultiSWAP speedup.

## Frozen classifications

- `QUALIFIED_MIQUAL01_BROAD_POSTADMISSION_BANK`: reference coverage, physical, route, and performance gates all pass.
- `MIQUAL01_REFERENCE_COVERAGE_INSUFFICIENT`: fewer than 6/8 reference-valid cases or fewer than three archetypes represented.
- `MIQUAL01_PHYSICAL_MISMATCH`: a reference-valid adaptive case violates a physical gate.
- `MIQUAL01_OPERATIONAL_ROUTE_FAILURE`: fallback/bypass contract fails.
- `MIQUAL01_PERFORMANCE_NOT_READY`: physical/route gates pass but broad performance gates do not.
- `MIQUAL01_EXECUTION_INVALID`: build, timer, or reporting is invalid.

## Positive consequence

A positive result authorizes MIQUAL02 to expand forcing/regime diversity, including dry-to-wet, infiltration and ponding cases, before any discussion of broader activation.

A negative result must be localized by case/material/geometry. Do not redesign the manager globally unless evidence requires it.

## Stop rules

Do not:

- tune tolerances after exposure;
- alter reconstruction or moving-interface physics;
- introduce fitted corrections;
- relax hard mass;
- replace failed frozen cases;
- change production default;
- infer whole-MultiSWAP performance.

## Production boundary

Manager remains explicit opt-in.

`LEGACY_NUMERICS` remains production default.
