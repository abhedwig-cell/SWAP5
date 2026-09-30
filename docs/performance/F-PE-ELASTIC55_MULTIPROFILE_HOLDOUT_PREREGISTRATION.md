# F-PE-ELASTIC55 — multi-profile mode-7 defect scaling holdout preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC54 — QUALIFIED_GLOBAL_MODE7_DEFECT_SCALING_RESEARCH_CANDIDATE`

Parent postimage:
`research/f-pe-elastic54-mode7-indicator-calibration@4dfd68474b693e8c513516870165156bd53b5145`

Canonical authority at start:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Frozen global research envelope from ELASTIC54:

`H_INF <= 0.17320259355765216 * Binf`.

## Question

Does the ELASTIC54 global conservative envelope survive holdout on independent
BRO/BOFEK source profiles with different soilunit, horizon structures and
Staringreeks block combinations?

No alpha is refit in ELASTIC55.

## Source-profile selection

The frozen BRO GeoPackage from producer run `36550782840`, artifact
`f-pe-elastic12a4-pdok-atom`, SHA-256
`f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`
is the sole source.

Select exactly four holdout profiles deterministically.

Eligibility:
- profile id positive;
- profile id != `90116260`;
- ordered contiguous horizons beginning at 0 m;
- every Staringreeks block in 101..118 or 201..218;
- no horizon has peat_type present;
- every horizon has dry density > 0;
- organic matter is either NULL or <= 20 pct.

Diversity key:
`(soilunit, horizon_count, tuple(staringseriesblock by layer))`.

Selection algorithm:
1. enumerate eligible profiles in ascending `normalsoilprofile_id`;
2. retain only the first profile for each unique diversity key;
3. partition by horizon_count;
4. choose one profile from each of the first four distinct horizon_count classes
   in ascending horizon_count order;
5. within a class choose the smallest profile id.

If fewer than four distinct eligible horizon-count classes exist, fail closed.

The selected IDs are outputs of the preregistered algorithm, not hand-picked
after numerical results.

## Generated-prior path

For each selected profile use the admitted chain:

`ELASTIC24 profile retrieval`
-> `ELASTIC33 row interchange`
-> admitted ELASTIC22/21/20/19/17/16 preparation
-> generated ELAS row-24 parameters.

No spatial point/maparea lookup is used because profile identity is explicit in
this holdout.

## Numerical bank

For every selected profile:
- build a 16-node variable grid by the same proportional horizon-splitting rule
  used in ELASTIC46-54;
- bottom mode 7;
- swkimpl=0;
- explicit fixed-flux top boundary;
- same solver/tolerances as ELASTIC53/54.

Regimes:
- OFF;
- FIXED_1E6;
- GENERATED.

States:
- h0 = -75, -20, +2, +10 cm.

Perturbations:
- delta = +/-0.035 and +/-0.05 cm/day.

Retry ladder:
- dt0 = 0.015625 day;
- factor 0.5;
- retry indices 0 through 8.

Per selected profile:
`4 states * 4 perturbations * 3 regimes * 9 dt = 432` requested cases.

Total requested bank:
`4 * 432 = 1728` cases.

## Primary frozen test

For every paired-converged holdout observation:

`H_INF <= 0.17320259355765216 * Binf`.

No value from ELASTIC55 may alter the alpha.

## Secondary observations

Record:
- paired-converged count per profile/regime;
- maximum realized `H_INF/Binf` ratio per profile;
- Binf monotonicity under decreasing dt for full-converged sequences with at
  least three points;
- generated Ss min/max by profile;
- whether any profile fails generated-prior materialization.

## Gates

A1. Exactly four profiles selected by the frozen selection algorithm.

A2. Selection is byte/deterministically reproducible from the frozen artifact.

A3. All requested cases execute for every selected profile.

A4. O0/O2 semantic outputs agree per profile.

A5. Binf finite/nonnegative whenever full solve converges.

A6. H_INF emitted only when full, half1 and half2 converge.

A7. ELASTIC54 alpha remains exactly frozen and is not recomputed.

A8. Zero production `src/**` changes.

## Decision

If any paired holdout violates the frozen global envelope, classify the
ELASTIC54 scaling as multi-profile falsified.

If all paired holdouts pass, classify only as a strengthened multi-profile
research candidate.

No production admission is authorized by ELASTIC55.
