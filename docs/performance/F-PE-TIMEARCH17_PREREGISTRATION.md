# F-PE-TIMEARCH17 preregistration — blind validation of frozen GUARD_M5 AUTO_REFERENCE

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_VALIDATION_RESULTS`

Canonical authority:

`integration/f-ci-canonical@6dabb1d6e5baa351659363a1f938d596dddedc7c`

Parent authority:

- TIMEARCH16 selected GUARD_M5 by preregistered calibration on the exposed 16-case BOFEK01 screening bank;
- calibration result: 16/16 P-C1 and about 33.6% median deterministic work reduction;
- no soil/material/regime identifiers are used by the controller.

## Frozen candidate

No parameter or semantic change is permitted in TIMEARCH17.

AUTO_REFERENCE candidate:

1. bootstrap dt = 0.005 d;
2. normalized accepted-state proposal target R = 0.40;
3. no normal operating DTMAX in AUTO;
4. AUTO allowed only while accepted dynamic-top mode is FLUX and accepted top pressure head <= -5 cm;
5. accepted top head > -5 cm enters LEGACY_SAFE permanently;
6. FLUX -> HEAD/runoff candidate transition uses REFINE4;
7. AUTO nonlinear failure enters LEGACY_SAFE;
8. LEGACY_SAFE uses the current Reference timestep policy;
9. retry floor remains 0.001 d;
10. hard-event and retry ownership are unchanged.

## Blind validation bank

The validation forcing/state points below have not been used in TIMEARCH16 calibration and are not copied from the earlier PRACTICAL02/PRACTICAL03 banks.

Use all four repository-backed hydraulic archetypes B01, B12, O05 and O14.

Use five new hydrologic points:

- DRY4:
  - initial head = -225 cm;
  - rain = 1.2 cm/day.
- TRANS4:
  - initial head = -85 cm;
  - rain = 5.5 cm/day.
- MOIST4:
  - initial head = -40 cm;
  - rain = 7.0 cm/day.
- WET4:
  - initial head = -15 cm;
  - rain = 13.0 cm/day.
- POND4:
  - initial head = -3 cm;
  - rain = 22.0 cm/day.

Horizon remains 0.12 d.

Total validation cases: 20.

No validation point may be changed after result exposure.

## Comparator

Current corrected LEGACY_NUMERICS Reference route on the same material/forcing case.

## P-C1 accuracy gates

Unchanged from the practical BOFEK authority:

- cumulative runoff difference <= 0.01 cm when baseline runoff < 1 cm, otherwise <= 1%;
- terminal storage difference <= max(0.01 cm, 0.5% of Reference terminal storage);
- terminal ponding difference <= 0.02 cm;
- terminal top/mid/bottom head difference <= 2.0 cm each;
- maximum ledger <= 5e-8 cm;
- no solver failure;
- rejected attempts <= max(2x Reference rejected attempts, 25% candidate attempts).

## Blind validation gate

GUARD_M5 validates only if all are true:

1. at least 19/20 cases pass P-C1;
2. every WET4 and POND4 case passes;
3. every material passes at least 4/5 validation regimes;
4. median total deterministic work reduction across passing cases >= 20%;
5. no hydrologic regime has median work regression > 5%;
6. candidate retry-work fraction is no more than 5 percentage points above LEGACY_NUMERICS;
7. no new solver-floor pathology appears in WET4 or POND4.

The 20% performance threshold is higher than the TIMEARCH16 calibration threshold because this is blind validation of a more complex automatic controller.

## Timing

If the deterministic blind gate passes, execute five paired process-level repetitions for Reference and GUARD_M5 for every validation case.

Timing is supporting evidence only unless the repeated within-case signal is clearly separated from process-startup noise.

A production admission is not allowed in TIMEARCH17.

## Outcome

Possible statuses:

- `PRACTICAL_MODE_CANDIDATE_RESEARCH_ONLY`;
- `CLOSED_GUARD_M5_BLIND_VALIDATION_FAILED`;
- `BLOCKED_<reason>`.

