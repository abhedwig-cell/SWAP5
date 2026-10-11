# F-PE-TIMEINT07A preregistration — blind holdout of analytical BDF2 LTE estimator

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_HOLDOUT_RESULTS`

Parent:

F-PE-TIMEINT07 P0.

## Frozen estimator

Use exactly:

`E3 = h^2*(h+k)/a0 * max|D3|`.

No multiplier, intercept, material term, regime term or ratio-specific fit is allowed.

## New holdout bank

Hydraulic archetypes not used in P0:

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

Horizon:

- 0.04 d.

Potential holdout trajectories:

36.

Estimator points begin when four accepted state levels exist.

## Research-authority completion

Full-versus-two-half BDF2 remains the local research label.

A research half-route failure does not automatically invalidate the full-step BDF2 mechanism, but it removes that local label from estimator qualification.

Holdout requires:

- at least 240 complete labelled points;
- no more than 2 trajectories with incomplete research labels;
- all full-step BDF2 trajectories themselves complete.

## Frozen holdout gates

The analytical estimator qualifies only if:

1. at least 240 complete labelled points;
2. overall Spearman(E3,E_HEAD) >=0.90;
3. per-pattern Spearman >=0.85 for R1, R1P5 and R2;
4. median `E_HEAD/E3` within [0.5,2.0];
5. at least 90% of positive finite ratios within [0.25,4.0];
6. max `E_HEAD/E3 <=2.0`;
7. direct local SAFE classification at `E3<=0.01 cm` has zero false-safe points where actual `E_HEAD>0.01 cm`;
8. at least 20% of actually safe points are classified safe.

No post-hoc calibration is allowed if a gate fails.

## Outcome

If all gates pass:

`ANALYTICAL_BDF2_LTE_HOLDOUT_QUALIFIED`.

Otherwise:

`CLOSED_ANALYTICAL_BDF2_LTE_HOLDOUT_FAILED`.

## Production boundary

A successful holdout still does not production-admit BDF2 or an adaptive controller.

It authorizes the next research step: a controller that converts a local target error to a bounded step proposal within the TIMEINT05 ratio envelope.
