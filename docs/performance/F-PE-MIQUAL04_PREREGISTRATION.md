# F-PE-MIQUAL04 preregistration — dynamic-top runoff/ponding qualification

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

Parent authority:

`QUALIFIED_MIQUAL03_FIXED_FLUX_FORCING_DIVERSITY`

## Purpose

Qualify the canonically admitted moving-interface manager with the production-shaped B110 dynamic-top boundary, including atmospheric/flux switching, ponding and linear runoff, while preserving a valid saturated-tail moving-interface geometry.

This workunit changes only the top-boundary forcing/provider relative to MIQUAL03. Moving-interface reconstruction, accepted-state ownership, fallback semantics and numerical tolerances remain unchanged.

## Frozen material/geometry bank

Use exactly the five MIQUAL02/03 reference-valid material/geometry pairs:

- B01_N64_T49;
- B12_N64_T49;
- O05_N64_T49;
- B12_N32_T25;
- O05_N32_T25.

## Frozen precipitation levels

For every pair run exactly four precipitation rates:

- `DRY`: 0.0 cm/d;
- `MODERATE`: 1.0 cm/d;
- `WET`: 8.0 cm/d;
- `PONDING`: 25.0 cm/d.

This yields 20 frozen cases.

Dynamic-top contract:

- ponding maximum = 0.05 cm;
- runoff resistance = 0.05 d;
- runoff exponent = 1;
- no irrigation, snowmelt or runon;
- no potential evaporation;
- previous ponding is committed accepted-state ponding;
- conductivity mean method = 1;
- SWKIMPL=0 fixed top-node conductivity semantics;
- qbot = 0.

## Frozen numerical and trajectory contract

- MAXIT16 evidence profile;
- max_backtracking = 8;
- conductivity implicit mode = 0;
- min step duration = 1e-6 d;
- head absolute/relative tolerance = 1e-9;
- ponding tolerance = 1e-10;
- balance tolerance = 1e-12;
- dt = 0.00125 d;
- 4,000 nominal intervals;
- independent full and adaptive trajectories;
- compiled Heritage/reference HeadCalc;
- no adaptive-state repair from full.

MAXIT16 remains evidence scope only.

## Reference-first exposure rule

All 20 cases first run the complete full-reference trajectory.

Adaptive execution is allowed only for reference-valid cases.

A case is reference-valid only if:

- all 4,000 intervals complete;
- states remain finite;
- dynamic-top result remains available;
- physical ledger <= 5e-8 cm.

No reference-invalid case may be replaced after exposure.

Coverage gate:

- at least 15/20 reference-valid cases;
- every precipitation class represented by at least three reference-valid material/geometry pairs.

## Dynamic-top exposure gate

Across the reference-valid bank require observed use of:

- surface-flux or atmospheric-head route;
- at least one ponded-head route;
- at least one ponded-head-linear-runoff route.

If these routes are not actually exercised, classify `MIQUAL04_DYNAMIC_TOP_EXPOSURE_INSUFFICIENT` even if numerical trajectories pass.

## Physical gates

For every reference-valid adaptive case require:

- full and adaptive completion;
- finite state;
- physical ledger <= 5e-8 cm;
- no accepted-origin leak;
- contiguous saturated tail;
- ownership change <=1 face per interval;
- max |h adaptive-full| <=5e-3 cm;
- max |theta adaptive-full| <=5e-6;
- max ponding-depth difference <=1e-5 cm;
- cumulative runoff difference <=1e-5 cm;
- final tails equal or differ by at most one face;
- identical ordered ownership directions.

## Manager-route gates

Per reference-valid case require:

- reduced-route fraction >=95%;
- fallback + bypass <=5%;
- no silent fallback;
- typed fallback/bypass reasons.

Report active-dimension histogram, mean active dimension, allocation counters and dynamic-top route counts.

## Performance gates

For every reference-valid case report wall and deterministic work ratios.

Aggregate qualification requires:

- no wall ratio >1.10;
- geometric-mean wall ratio <1.00;
- at least 75% of reference-valid cases wall ratio <0.98;
- geometric-mean deterministic work ratio <0.90.

## Frozen classifications

- `QUALIFIED_MIQUAL04_DYNAMIC_TOP_RUNOFF_PONDING`
- `MIQUAL04_REFERENCE_COVERAGE_INSUFFICIENT`
- `MIQUAL04_DYNAMIC_TOP_EXPOSURE_INSUFFICIENT`
- `MIQUAL04_PHYSICAL_MISMATCH`
- `MIQUAL04_OPERATIONAL_ROUTE_FAILURE`
- `MIQUAL04_PERFORMANCE_NOT_READY`
- `MIQUAL04_EXECUTION_INVALID`

## Consequence

If qualified, the next step is not another single-column micro-study. Proceed to production-shaped SWAP Heritage integration and end-to-end timing on representative runs.

If a specific dynamic-top case fails adaptively while its full reference is valid, open a targeted mechanistic successor for that case only.

## Production boundary

No production-default change.

Moving-interface manager remains explicit opt-in.

`LEGACY_NUMERICS` remains production default.
