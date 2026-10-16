# F-PE-TIMEINT06 P0 result — cheap BDF2 local-error signals

Date: 2026-09-28

Status: `CHEAP_BDF2_ERROR_SIGNAL_PREDICTIVE`

Authority:

- canonical base: `integration/f-ci-canonical@e1b575f3e40ad7fe4cc6d26f5e383f5353218130`;
- Actions run: `36483276422`;
- characterization job: `109133897415`;
- conclusion: SUCCESS.

## Complete labels

120/120 local full-versus-two-half BDF2 labels completed.

All storage differences and candidate signals were finite.

## Signal S1 — derivative-change raw head defect

Definition:

`S1 = 0.5*h*max|d_now-d_prev|`.

Spearman versus actual local max head error:

- overall: 0.8628;
- R1: 0.7662;
- R1P5: 0.8809;
- R2: 0.8912.

All frozen correlation gates pass.

## Signal S2 — linear head extrapolation defect

S2 has exactly the same rank ordering as S1.

This is expected because on the defined history geometry it is a constant scaling of the same derivative-change information.

No separate estimator family is therefore needed.

## Signal S3 — water-content extrapolation defect

Spearman:

- overall: 0.8141;
- R1: 0.7293;
- R1P5: 0.8396;
- R2: 0.8542.

S3 fails the frozen R1 per-pattern gate.

## Calibration diagnostic for successor

On the exposed P0 bank:

`E_HEAD / S1` ranges from about 0.0083 to 0.1897.

A conservative simple multiplier of 0.20 would upper-bound all 120 exposed local head errors.

This multiplier is not qualified by P0 itself. It may be frozen in a successor before new holdout exposure.

## Decision

Advance S1 to a separate calibration/holdout workunit.

Classification:

`CHEAP_BDF2_ERROR_SIGNAL_PREDICTIVE`.
