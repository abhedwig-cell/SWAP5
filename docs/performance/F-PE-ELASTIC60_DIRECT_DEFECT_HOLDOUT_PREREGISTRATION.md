# F-PE-ELASTIC60 — direct defect-head blind multi-profile holdout preregistration

Date: 2026-09-30

Status: PREREGISTERED_BLIND_HOLDOUT

Parent authority:
`F-PE-ELASTIC59 — QUALIFIED_DIRECT_DEFECT_HEAD_RESEARCH_CANDIDATE`

Parent postimage:
`research/f-pe-elastic59-direct-defect-head@7dabf12068953fa61a7f9aeee51514dc54467a34`

Canonical authority at start:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Frozen candidates

Independent physical head limit inherited unchanged from TEMPORAL04/05:

`H_LIMIT = 0.01 cm`.

Primary research metric:

`D1 = DEFECT_HEAD_INF = max(abs(delta_defect))`.

Primary accept rule:

`D1 <= 0.01 cm`.

Conservative comparator:

`D2 = 2 * DEFECT_HEAD_INF`.

Comparator accept rule:

`D2 <= 0.01 cm`.

No multiplicative calibration, intercept, regime correction, saturation
correction or post-hoc scaling is permitted.

## Blind profile selection

Use the same frozen BRO GeoPackage authority as ELASTIC55/59.

Eligibility is identical to ELASTIC55:
- positive profile id;
- exclude profile 90116260;
- ordered contiguous horizons from 0 m;
- horizon_count <= 16;
- every block in 101..118 or 201..218;
- no peat horizon;
- positive dry density;
- organic matter NULL or <=20 percent.

Diversity key remains:

`(soilunit, horizon_count, tuple(staringseriesblock by layer))`.

Holdout selection algorithm:

1. enumerate eligible profiles in ascending profile id;
2. retain only the first profile per unique diversity key;
3. partition by horizon_count;
4. use the same first four horizon-count classes selected in ELASTIC55;
5. within each class order unique candidates by profile id;
6. choose the second candidate in that class, not the ELASTIC55 first candidate;
7. fail closed if any of the four classes has fewer than two eligible unique candidates.

Thus holdout profile identity is fixed algorithmically before any ELASTIC60
numerical result.

The ELASTIC55 profiles
`11060,10260,8016,3030`
and original profile `90116260` must not appear in the ELASTIC60 holdout.

## Frozen physical/numerical bank

Per holdout profile:
- 16-node variable representation;
- admitted Staringreeks retention materialization;
- profile-specific generated Ss;
- parent-fixture Ksat/lambda held fixed as in ELASTIC55/59;
- bottom mode 7;
- swkimpl=0;
- explicit fixed-flux top boundary;
- unchanged solver/tolerances.

States:
- h0 = -75, -20, +2, +10 cm.

Perturbations:
- delta = +/-0.035 and +/-0.05 cm/day.

Regimes:
- OFF;
- FIXED_1E6;
- GENERATED.

Retry ladder:
- 0.015625 day followed by factor-0.5 refinement through retry index 8.

Total requested:
`4 profiles * 4 states * 4 perturbations * 3 regimes * 9 dt = 1728 cases`.

## C-SAFE evaluation

For each profile/state/forcing/regime sequence and each candidate independently:

1. inspect dt from largest to smallest;
2. unavailable full solve/direct indicator -> continue;
3. candidate metric <= 0.01 cm -> select that dt;
4. otherwise continue refinement;
5. no passing point -> EXHAUSTED.

No monotonicity assumption is allowed.

## Blind safety gates

For every paired selected observation under D1:
- realized `H_INF <= 0.01 cm`;
- realized `THETA_INF <= 1e-5`.

The same gates apply independently to D2.

Any paired selected head-limit failure falsifies that candidate.

## Practicality observations

Report separately for D1 and D2:
- selected/exhausted counts;
- saturated selected count;
- unsaturated selected count;
- paired selected count;
- maximum selected realized H_INF;
- maximum selected realized THETA_INF;
- selected dt distribution.

No minimum selection rate is required for safety qualification, but a candidate
that selects zero saturated sequences is classified as impractical in the
saturated domain.

## Gates

A1. Exactly four blind holdout profiles selected by the frozen second-candidate
algorithm and none overlaps ELASTIC55 or profile 90116260.

A2. All 1728 requested cases execute.

A3. O0/O2 semantic identity.

A4. Direct head observables finite/nonnegative whenever available.

A5. No candidate scaling/refit.

A6. D1 paired-selected physical head/theta gates enforced.

A7. D2 paired-selected physical head/theta gates enforced.

A8. Zero production `src/**` changes.

## Decision

Possible classifications:
- `DIRECT_DEFECT_HEAD_BLIND_HOLDOUT_PASS`;
- `DIRECT_DEFECT_HEAD_BLIND_HOLDOUT_FALSIFIED`;
- comparator-specific pass/falsification;
- saturated impracticality if no saturated sequence can be selected.

ELASTIC60 does not authorize production admission or F-CI14 completion.
