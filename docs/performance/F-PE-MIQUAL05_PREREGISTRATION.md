# F-PE-MIQUAL05 preregistration — dynamic-top pre-failure event-window qualification

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@9bad713b0d2ab24d40fcf937d11c850d3fb52a22`

Parent authority:

`MIQUAL04_REFERENCE_COVERAGE_INSUFFICIENT`

## Purpose

Qualify full-versus-moving-interface equivalence across a bounded dynamic-top event window that is guaranteed to remain before the earliest exposed full-reference WET failure from MIQUAL04.

This is a bounded physical/event qualification, not a long-horizon performance benchmark.

## Frozen horizon

Exactly:

- dt = 0.00125 d;
- 64 nominal intervals;
- total horizon = 0.08 d.

The 64-interval window was selected only from MIQUAL04 full-reference failure times, before any adaptive result exposure. The earliest exposed WET full-reference failure occurred after 81 accepted intervals.

Do not change the horizon after results.

## Frozen material/geometry and rainfall bank

Reuse all 20 MIQUAL04 cases:

Five material/geometry pairs:

- B01_N64_T49;
- B12_N64_T49;
- O05_N64_T49;
- B12_N32_T25;
- O05_N32_T25.

Four precipitation classes:

- DRY = 0.0 cm/d;
- MODERATE = 1.0 cm/d;
- WET = 8.0 cm/d;
- PONDING = 25.0 cm/d.

No case may be added, replaced or removed after exposure.

## Frozen dynamic-top and numerical contract

Unchanged from MIQUAL04:

- ponding maximum = 0.05 cm;
- runoff resistance = 0.05 d;
- runoff exponent = 1;
- no irrigation, snowmelt, runon or potential evaporation;
- previous ponding comes from committed accepted state;
- conductivity mean method = 1;
- SWKIMPL=0 fixed top-node conductivity semantics;
- qbot = 0;
- MAXIT16 evidence profile;
- max_backtracking = 8;
- min step duration = 1e-6 d;
- head absolute/relative tolerance = 1e-9;
- ponding tolerance = 1e-10;
- balance tolerance = 1e-12;
- independent full and adaptive trajectories;
- no adaptive-state repair from full.

## Reference-first exposure rule

All 20 cases run the complete 64-interval full-reference window first.

Adaptive execution is allowed only for reference-valid cases.

Reference-valid requires:

- 64/64 intervals complete;
- finite state;
- dynamic-top result available;
- physical ledger <=5e-8 cm;
- contiguous saturated tail;
- ownership change <=1 face per interval.

Coverage gate:

- at least 18/20 reference-valid;
- every rainfall class represented by at least four reference-valid material/geometry pairs.

## Dynamic-top exposure gate

Across the reference-valid bank require actual observation of:

- surface-flux or atmospheric-head;
- ponded-head;
- ponded-head-linear-runoff.

A bank that never reaches ponding/runoff cannot qualify as MIQUAL05.

## Physical equivalence gates

For every reference-valid adaptive window require:

- adaptive completion;
- finite state;
- physical ledger <=5e-8 cm;
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

Report active-dimension histogram, allocation counters and dynamic-top route counts.

## Performance reporting

Because the window is only 64 intervals:

- deterministic work ratio is a qualification metric;
- wall-clock ratio is diagnostic only and must not be interpreted as a stable speedup estimate.

Require geometric-mean deterministic work ratio <0.90.

Do not impose a wall-clock acceptance threshold in MIQUAL05.

## Frozen classifications

- `QUALIFIED_MIQUAL05_DYNAMIC_TOP_EVENT_WINDOW`
- `MIQUAL05_REFERENCE_COVERAGE_INSUFFICIENT`
- `MIQUAL05_DYNAMIC_TOP_EXPOSURE_INSUFFICIENT`
- `MIQUAL05_PHYSICAL_MISMATCH`
- `MIQUAL05_OPERATIONAL_ROUTE_FAILURE`
- `MIQUAL05_WORK_REDUCTION_NOT_READY`
- `MIQUAL05_EXECUTION_INVALID`

## Positive consequence

A positive MIQUAL05 result closes the single-column manager physics qualification sufficiently to move to production-shaped SWAP Heritage integration and end-to-end benchmarking.

Do not open another local manager micro-study unless MIQUAL05 exposes a specific adaptive failure.

## Production boundary

No default change.

Moving-interface manager remains explicit opt-in.

`LEGACY_NUMERICS` remains production default.
