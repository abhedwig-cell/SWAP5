# F-PE-TIMEINT06A preregistration — calibrated cheap BDF2 head-error estimator

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_HOLDOUT_RESULTS`

Parent:

F-PE-TIMEINT06 P0.

## Frozen estimator

Use only S1:

`S1 = 0.5*h*max|d_now-d_prev|`.

Calibration multiplier frozen from the already exposed P0 calibration bank:

`E_hat = 0.20 * S1`.

Reason:

The maximum exposed P0 ratio `E_HEAD/S1` is approximately 0.1897.

The multiplier is rounded upward to 0.20 before holdout exposure.

No additional fitted intercept or material/regime term is allowed.

## Local acceptance threshold for characterization

Scientific local head-error threshold:

`E_limit = 0.01 cm`.

Predict SAFE when:

`E_hat <= 0.01 cm`.

Actual SAFE label:

`E_HEAD <= 0.01 cm`.

This threshold is local estimator characterization only and is not yet a production timestep tolerance.

## New holdout bank

Use hydraulic archetypes not used in P0:

- B12;
- O14.

Forcing:

- infiltration 1 cm/day;
- infiltration 3 cm/day;
- infiltration 5 cm/day.

Patterns:

- R1;
- R1P5;
- R2.

Base mean steps:

- 0.010 d;
- 0.005 d.

Horizon remains 0.04 d.

This yields 36 trajectories and a target of at least 100 local BDF2 error labels.

## Holdout gates

Estimator qualifies only if:

1. all 36 trajectories complete;
2. at least 100 complete local labels;
3. false-safe count = 0;
4. SAFE coverage >=20% of actually safe points;
5. overall Spearman between E_hat and E_HEAD >=0.80;
6. per-pattern Spearman >=0.70 for R1, R1P5 and R2;
7. max `E_HEAD/E_hat <= 1.0` for finite positive E_hat;
8. no nonfinite state/storage diagnostic.

If gate 3 or 7 fails, do not fit a second multiplier post hoc.

## Interpretation boundary

A successful result qualifies a cheap local BDF2 head-error estimator mechanism on the smooth fixed-flux ratio<=2 envelope.

It does not yet qualify:

- dynamic-top use;
- automatic timestep control;
- a production error tolerance;
- BDF2 production admission.

Possible outcome:

- `CALIBRATED_BDF2_HEAD_ESTIMATOR_HOLDOUT_QUALIFIED`;
- `CLOSED_CALIBRATED_BDF2_HEAD_ESTIMATOR_FAILED`.
