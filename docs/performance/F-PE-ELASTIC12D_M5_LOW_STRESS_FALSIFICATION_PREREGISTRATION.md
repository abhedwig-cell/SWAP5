# F-PE-ELASTIC12D — frozen deep-M5 low-stress falsification

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_M5_LOW_STRESS_PREDICTIONS

Parents:
- F-PE-ELASTIC11C frozen deep-mechanical M5 model;
- F-PE-ELASTIC11D independent deep BHR-GT holdout;
- F-PE-ELASTIC12A root-zone transfer/domain audit;
- F-PE-ELASTIC12B low-stress coverage;
- F-PE-ELASTIC12C qualified five-object low-stress mechanical target set.

## Purpose

Test whether the already frozen deep BHR-GT M5 relation transfers to the
independent <=25 kPa mechanical target set.

This is a pure falsification. No coefficient, threshold, target, predictor or
object may be selected using the low-stress prediction errors.

## Frozen target authority

F-PE-ELASTIC12C workflow:
`36539242031`.

Target artifact:
`f-pe-elastic12c-low-stress-targets`.

Artifact id:
`11019543072`.

Artifact digest:
`sha256:887e87b13bf0ee4e890567fa715fce1bf233ff0a8ec303bc51a4cc74bcdce864`.

Exactly five low-stress targets are opened:

- BHR000000466495;
- BHR000000466498;
- BHR000000469044;
- BHR000000469048;
- BHR000000469193.

No target may be dropped, including BHR000000469048 with its weaker descriptive
OLS linearity.

## Frozen predictor source

Predictor metadata must be extracted target-blind from the same frozen BHR-GT
object bytes used by F-PE-ELASTIC12B:

- workflow run `36538267535`;
- artifact id `11018544503`;
- artifact digest
  `sha256:c47ebb65c641a4b01504e709f4b65da27816aba4d99e72f15c5b1f3dcc3e3f7b`.

For each exact target determination use only the nearest enclosing
`investigatedInterval`.

Required predictor:

`waterContent`

with exact source unit:

`%`.

Rules follow F-PE-ELASTIC11B:
- zero values -> MISSING;
- one unique source value -> ASSIGNED;
- repeated identical values -> ASSIGNED;
- distinct equal-scope values -> AMBIGUOUS;
- unexpected unit -> fail closed;
- no imputation.

All five candidates must have one ASSIGNED water-content value or the
falsification is INCOMPLETE.

## Frozen stress predictor

For each low-stress target:

`stress_midpoint_kpa = 0.5 * (stress_start_kpa + stress_end_kpa)`.

The endpoints are from the already frozen F-PE-ELASTIC12C target.

No alternative stress statistic may be chosen after seeing errors.

## Frozen M5 model

No refit.

`log10(Ssk_cm_inv_pred) =
   -5.213084677584852
   + 1.0383403589566573 * log10(water_content_pct)
   - log10(stress_midpoint_kpa)`.

Equivalently:

`Ssk_cm_inv_pred =
  10^-5.213084677584852
  * water_content_pct^1.0383403589566573
  / stress_midpoint_kpa`.

The stress exponent remains exactly `-1`.

## Frozen metrics

For each object:

`error_i = log10(predicted Ssk_cm_inv) - log10(observed Ssk_cm_inv)`.

Report:
- absolute log10 error;
- signed log10 error;
- multiplicative error factor `10^abs(error_i)`.

Across the five objects report:
- mean absolute log10 error;
- median absolute log10 error;
- maximum absolute log10 error;
- mean signed log10 error;
- median signed log10 error;
- object count with absolute error <=0.30;
- object count with absolute error <=0.50.

All metrics are object-level because there is exactly one frozen target per
object.

## Primary falsification gate

Classification:

### LOW_STRESS_M5_TRANSFER_SUPPORTED

Only when both:
- mean absolute log10 error <= `0.30`;
- maximum absolute log10 error <= `0.50`.

The maximum gate corresponds to a factor of about 3.16 on every frozen object.
The mean gate requires substantially better behavior than merely staying below
the per-object ceiling.

### LOW_STRESS_M5_TRANSFER_NOT_QUALIFIED

If either primary condition fails.

No post-result model repair is allowed inside this workunit.

## Bias diagnostic

Report mean and median signed error.

Systematic under- or over-prediction is descriptive evidence for the next
scientific decision, not a third acceptance criterion.

## Secondary context only

For interpretation only, compare the five-object error envelope with the already
qualified deep BHR-GT holdout:

- deep M5 mean object MAE: `0.1379154881` log10;
- deep M5 maximum object MAE: `0.2306336583` log10;
- deep R3 route maximum absolute error: `0.24209` log10.

These values do not relax the frozen primary low-stress gate.

## Required integrity gates

- exact five target objects;
- exact 12C artifact identity;
- exact 12B predictor-source artifact identity;
- no target field read during predictor extraction except target identity;
- source-bound water-content unit `%`;
- no missing or ambiguous water predictor;
- no M5 coefficient mutation;
- deterministic duplicate evaluation.

## Prohibited

Do not:
- refit M5;
- estimate a new stress exponent;
- add density/route/depth terms after seeing low-stress errors;
- exclude BHR000000469048;
- replace the endpoint-secant target by the OLS diagnostic;
- widen the stress threshold above 25 kPa;
- use LS50 targets;
- use SWAP runtime performance;
- translate a successful result directly into a production ELAS default.

## Decision boundary

If LOW_STRESS_M5_TRANSFER_SUPPORTED:
- the frozen mechanical relation has survived an independent low-stress
  falsification;
- a separate workunit may then study transport from BHR-GT specimen mechanics
  to BHR-P/root-zone soil descriptors and field-scale ELAS.

If LOW_STRESS_M5_TRANSFER_NOT_QUALIFIED:
- the deep M5 law may not be extrapolated into the root-zone stress regime;
- retain low-stress Ssk as a separate evidence regime;
- any root-zone ELAS generator requires new low-stress model identification
  with a separately frozen calibration/holdout design.

Neither class establishes a production ELAS value.
