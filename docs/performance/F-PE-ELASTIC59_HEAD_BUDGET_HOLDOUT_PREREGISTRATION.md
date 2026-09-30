# F-PE-ELASTIC59 — 1 cm head-budget expanded holdout preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC58 — QUALIFIED_MODE7_HEAD_BUDGET_FRONTIER_WITHOUT_PHYSICAL_SELECTION`

Parent postimage:
`research/f-pe-elastic58-head-budget-frontier@cca8e91da98db7166f325cfd3d2dfa127c4b402b`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Frozen conservative scaling:
`alpha = 0.17320259355765216`.

Primary research-candidate head budget:
`1.0 cm`.

Frozen comparator:
`0.3 cm`.

## Question

Does the 1.0-cm mode-7 model-certificate head-budget candidate survive an
independent expanded holdout with different source profiles, state levels and
forcing magnitudes?

No alpha or budget is refit in ELASTIC59.

## Independent profile selection

Use the same frozen BRO GeoPackage authority as ELASTIC55-58.

Exclude all previously used profile IDs:
- 90116260;
- 11060;
- 10260;
- 8016;
- 3030.

Also exclude the previously used soilunits:
- Zn30A;
- Zd30;
- EZg21;
- gY30.

Eligibility is identical to ELASTIC55:
- positive profile id;
- ordered contiguous horizons from 0 m;
- horizon_count <= 16;
- all blocks in 101..118 or 201..218;
- no peat_type;
- positive dry density;
- organic matter NULL or <= 20 pct.

Diversity key:
`(soilunit, horizon_count, tuple(staringseriesblock by layer))`.

Selection algorithm:
1. enumerate eligible profiles in ascending profile id;
2. retain first profile per unique diversity key;
3. partition by horizon_count;
4. choose the smallest profile id from each of the first four distinct
   horizon-count classes;
5. fail closed if fewer than four classes remain.

Selected IDs are therefore determined before any numerical result.

## Expanded physical bank

For every selected profile use the same ELASTIC55 materialization:
- Staringreeks retention by admitted ELASTIC21/20 mapping;
- profile geometry from BRO;
- Ksat/lambda frozen to the parent research fixture;
- GENERATED Ss from the admitted profile-prior chain;
- bottom mode 7;
- swkimpl=0;
- fixed-flux top boundary;
- same solver/tolerances;
- same nine-dt ladder.

New initial heads:
- -150 cm;
- -40 cm;
- -5 cm;
- +5 cm;
- +20 cm.

New forcing perturbations:
- -0.07 cm/day;
- -0.02 cm/day;
- +0.02 cm/day;
- +0.07 cm/day.

Regimes:
- OFF;
- FIXED_1E6;
- GENERATED.

Per profile:
`5 * 4 * 3 * 9 = 540` requested cases.

Total:
`2160` requested cases.

## C-SAFE candidate evaluation

For each profile/state/forcing/regime sequence traverse the frozen dt ladder.

For the primary 1.0-cm candidate:
- skip unavailable full solve/indicator;
- compute `E = alpha * Binf`;
- accept first point with `E <= 1.0 cm`;
- otherwise EXHAUSTED.

Apply the same rule to the frozen 0.3-cm comparator.

## Primary gates

A1. Exactly four new profiles selected and none overlap prior IDs/soilunits.

A2. All 2160 requested cases execute.

A3. O0/O2 semantic identity.

A4. 1.0-cm C-SAFE never accepts unavailable points or `E > 1.0 cm`.

A5. Every paired accepted 1.0-cm observation satisfies:
`H_INF <= alpha*Binf <= 1.0 cm`.

A6. Frozen alpha remains unchanged.

A7. 1.0-cm acceptance count is >= 0.3-cm comparator acceptance count.

A8. Zero `src/**` production changes.

## Secondary observations

Record for both budgets:
- accepted/exhausted;
- accepted retry-index distribution;
- mean attempted ladder points;
- paired accepted count;
- maximum/median realized H_INF;
- maximum `H_INF / budget`;
- maximum global-envelope utilization;
- counts by regime and saturated/unsaturated state.

## Decision

A green ELASTIC59 qualifies only a strengthened 1.0-cm research candidate for
the mode-7 model-certificate route.

It does not authorize:
- production temporal budget admission;
- replacement of the identity gate;
- completion of the full eight-metric F-CI14 policy;
- weakening hard mass acceptance.

Failure of any paired accepted point against the frozen global envelope
falsifies the 1.0-cm candidate immediately.
