# F-PE-TIMEINT08A preregistration — blind holdout of linearized BDF2 LTE response estimator

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_HOLDOUT_RESULTS`

Parent:

F-PE-TIMEINT08 P0.

## Frozen estimator

Use exactly the TIMEINT08 P0 estimator:

`tau_h = h*(h+k)*D3`

`J_e = a0*M/h + L`

`J_e delta = M*tau_h`

`E8=max|delta|`.

No multiplier, intercept, material term, forcing term, ratio correction or threshold correction is permitted.

## New-material holdout bank

Hydraulic archetypes:

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

Total trajectories:

36.

The full-step BDF2 trajectory remains the primary trajectory.

Two-half BDF2 is local research authority only. A failed research label is recorded as unavailable and does not terminate a completed full BDF2 trajectory.

## Frozen holdout gates

E8 qualifies only if:

1. all 36 full-step BDF2 trajectories complete;
2. at least 130 complete local labels;
3. no more than 2 trajectories contain unavailable research labels;
4. estimator linear solve succeeds for every complete label;
5. overall Spearman(E8,E_HEAD) >=0.90;
6. per-pattern Spearman >=0.85 for R1, R1P5 and R2;
7. median `E_HEAD/E8` lies in [0.5,2.0];
8. at least 95% of positive finite ratios `E_HEAD/E8` lie in [0.25,2.0];
9. max `E_HEAD/E8 <=2.0`;
10. at `E8<=0.01 cm`, false-safe count = 0;
11. at least 50% of actually safe points are classified safe;
12. all E8 values and response-operator diagnostics are finite.

No post-hoc calibration is allowed.

## Outcome

If all gates pass:

`LINEARIZED_BDF2_LTE_RESPONSE_HOLDOUT_QUALIFIED`.

Otherwise:

`CLOSED_LINEARIZED_BDF2_LTE_RESPONSE_HOLDOUT_FAILED`.

## Production boundary

Successful holdout would authorize an adaptive-controller research workunit only.

It would not production-admit BDF2, SWKIMPL=1 or a new timestep profile.
