# F-PE-TIMEINT10A preregistration — blind holdout embedded BDF2/BE pair

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_HOLDOUT_RESULTS`

Parent:

F-PE-TIMEINT10 P0.

## Frozen estimator

Use exactly the P0 construction:

- same variable-step fully implicit BDF2 mechanism;
- same final Newton factor capture;
- same exact BE-versus-BDF2 storage residual at the converged BDF2 endpoint;
- same single backsolve through the final BDF2 Newton factorization;
- `E10=max|delta_BE|`.

No multiplier, intercept, material term, forcing term, ratio term or threshold adjustment.

## Blind holdout bank

Same previously established new-material envelope:

- B12 and O14;
- infiltration 1, 3 and 5 cm/day;
- patterns R1, R1P5, R2;
- base mean dt 0.010 and 0.005 d;
- horizon 0.04 d.

Total full trajectories: 36.

Two-half BDF2 remains local research authority only.

## Frozen gates

E10 qualifies only if:

1. all 36 full trajectories complete;
2. at least 130 complete local labels;
3. no more than 2 trajectories contain unavailable research labels;
4. estimator backsolve succeeds for every complete label;
5. no estimator-authority alternative-solver use;
6. overall Spearman >=0.80;
7. per-pattern Spearman >=0.75;
8. zero false-safe classifications at E10<=0.01 cm;
9. safe coverage >=30%.

## Stop rule

If blind holdout fails, stop this one-correction embedded-BE construction.

No post-hoc multiplier or threshold rescue.

If it passes, the next question is controller feasibility and end-to-end work saving under adaptive variable-step BDF2, not another estimator redesign.
