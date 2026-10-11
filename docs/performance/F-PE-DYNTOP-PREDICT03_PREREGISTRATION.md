# F-PE-DYNTOP-PREDICT03 preregistration — blind H0 classifier validation

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_VALIDATION_RESULTS`

Canonical authority:

`integration/f-ci-canonical@3b94726fe7d01aec42a5a53587769f38916203f4`

Parent:

F-PE-DYNTOP-PREDICT02 calibration.

## Frozen classifier

H0 predicts a proposed large interval SAFE only when all are true:

1. two accepted history intervals are available;
2. the origin-frozen corrected dynamic-top predictor is available;
3. origin-frozen `runoff_potential = false`;
4. most recent normalized accepted head movement:

`r_last = max_i(|h_i(t_k)-h_i(t_{k-1})| / max(10 cm, |h_i(t_{k-1})|)) <= 0.10`.

No coefficient or threshold is recalibrated in PREDICT03.

## Blind validation bank

Use all four repository-backed hydraulic archetypes B01, B12, O05 and O14.

Use four new state/forcing points not used in BOFEK01, PRACTICAL02 or PRACTICAL03:

- DRY4:
  - h0 = -180 cm;
  - rain = 2.0 cm/day.
- TRANS4:
  - h0 = -85 cm;
  - rain = 3.0 cm/day.
- WET4:
  - h0 = -35 cm;
  - rain = 9.0 cm/day.
- POND4:
  - h0 = -12 cm;
  - rain = 16.0 cm/day.

Horizon remains 0.12 d.

Total source cases: 16.

## Large-step origin generation

Use the same conservative data-generation route as calibration:

- historical Reference TimeControl owns accepted intervals at or below 0.02 d;
- normalized accepted-state proposal with target R=0.40 may request up to 0.08 d;
- every requested large interval is labelled using one full and two-half local trajectories;
- the two-half endpoint remains the continuation route during data collection.

Thus classifier predictions do not alter future validation origins.

## Local truth label

SAFE only when full and two-half routes both solve and:

- max endpoint head difference <= 0.50 cm;
- ponding endpoint difference <= 0.01 cm;
- runoff-depth difference <= 0.01 cm;
- storage endpoint difference <= 0.01 cm;
- all relevant ledger residuals <= 5e-8 cm.

## Validation gate

H0 validates only if:

- at least 10 labelled large-step intervals are produced;
- false-safe count = 0;
- safe coverage >= 50%;
- at least 3 of the four hydraulic archetypes contribute at least one labelled interval;
- at least one WET4 or POND4 case contributes a labelled interval.

An incomplete source case does not erase labels already generated before failure, but the incomplete-case count must be reported.

No threshold relaxation or new feature is allowed after exposure.

## Outcome

If H0 passes:

`CHEAP_DYNAMIC_TOP_CLASSIFIER_VALIDATED_RESEARCH_ONLY`

and a separately preregistered controller-application workunit may test whether using H0 to choose full versus split large intervals yields sufficient end-to-end work gain.

If H0 fails:

`CLOSED_NO_CHEAP_DYNAMIC_TOP_CLASSIFIER`.

No production source change in PREDICT03.
