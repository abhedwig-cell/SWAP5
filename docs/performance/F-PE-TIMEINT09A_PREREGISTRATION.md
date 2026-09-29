# F-PE-TIMEINT09A preregistration — blind holdout of exact Newton BDF2 LTE response

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_HOLDOUT_RESULTS`

Parent:

F-PE-TIMEINT09 P0.

## Frozen estimator

Use exactly the P0 estimator:

- same variable-step fully implicit BDF2 mechanism;
- same third divided difference;
- same `tau_h = h*(h+k)*D3`;
- same mass-weighted RHS;
- same exact final Newton TRIDAG factorization;
- one additional backsolve;
- `E9=max|delta|`.

No multiplier, intercept, material term, forcing term, ratio correction or threshold adjustment.

## Blind holdout bank

Use the previously defined TIMEINT08A new-material envelope:

- B12 and O14;
- infiltration 1, 3 and 5 cm/day;
- R1, R1P5 and R2;
- base mean dt 0.010 and 0.005 d;
- horizon 0.04 d.

Total full trajectories:

36.

The full BDF2 path is primary.

Two-half BDF2 remains local research authority only.

## Frozen gates

E9 qualifies only if:

1. all 36 full trajectories complete;
2. at least 130 complete local labels;
3. no more than 2 trajectories contain unavailable research labels;
4. factor capture/backsolve succeeds for every complete label;
5. no estimator-authority alternative-solver use;
6. overall Spearman >=0.90;
7. per-pattern Spearman >=0.85;
8. median actual/E9 in [0.5,2.0];
9. at least 95% of positive ratios in [0.25,2.0];
10. max actual/E9 <=2.0;
11. zero false-safe classifications at E9<=0.01 cm;
12. safe coverage >=50%.

## Stop rule

If the known B12 false-safe remains, stop this estimator family and proceed to an embedded integrator-pair study.

No post-hoc scalar correction is allowed.
