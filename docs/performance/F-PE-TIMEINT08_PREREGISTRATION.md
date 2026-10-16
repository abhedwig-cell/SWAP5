# F-PE-TIMEINT08 preregistration — linearized BDF2 truncation-defect response estimator

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@dec1233deb167a785c237c0fcb5d597d17d4bc6b`

Parent authority:

- TIMEINT05 qualifies variable-step fully implicit BDF2 for adjacent accepted step ratios `0.5 <= r <= 2.0`;
- TIMEINT07 shows the analytical third-divided-difference signal E3 is strongly predictive but not directly conservative on blind holdout;
- no empirical multiplier may be fitted as a rescue.

## Purpose

Test whether the BDF2 truncation defect can be converted to a better endpoint-head error estimate by propagating it through a cheap local linearized Richards response operator.

The candidate adds one tridiagonal linear solve per evaluated accepted step and no additional nonlinear solve.

This is estimator research only.

## Truncation derivative defect

Use the same four accepted head levels and third divided difference `D3` as TIMEINT07.

For current step `h` and previous step `k`:

`tau_h = h*(h+k)*D3`.

`tau_h` has pressure-head-rate units and represents the leading BDF2 temporal derivative defect.

## Linearized response operator

For the converged BDF2 candidate endpoint, construct a tridiagonal response operator:

`J_e = a0*M/h + L`

where:

- `a0=(1+2r)/(1+r)`;
- `M_i = C_i(h_np1) * dz_i`;
- `L` is the vertical hydraulic diffusion stiffness assembled from candidate-endpoint conductivities and node distances;
- top explicit-flux boundary contributes no head stiffness;
- bottom prescribed-flux mode 2 contributes no head stiffness.

Interior face conductance:

`G_i = 0.5*(K_{i-1}+K_i)/distance_i`.

Then solve:

`J_e * delta = M * tau_h`.

Candidate estimator:

`E8 = max_i |delta_i|`.

No fitted multiplier, intercept, soil term, forcing term or step-ratio correction is permitted.

## Relationship to E3

If storage dominates `L`, the response reduces approximately to:

`delta ≈ h/a0 * tau_h`

which is exactly the TIMEINT07 E3 scale.

TIMEINT08 therefore tests whether hydraulic redistribution in the local linear response explains the remaining material-dependent E3 error.

## Calibration bank

Use the same exposed mechanism bank as TIMEINT07 P0:

- B01, infiltration 2 and 4 cm/day;
- O05, infiltration 2 and 4 cm/day;
- patterns R1, R1P5, R2;
- base mean dt 0.010 and 0.005 d;
- horizon 0.04 d.

Estimator points begin when four accepted state levels exist.

## Research authority

Actual local endpoint error remains full variable-step BDF2 versus two BDF2 half steps from the same origin/history.

The full-step trajectory remains the research trajectory.

A failed two-half label is recorded as unavailable and does not invalidate a completed full BDF2 trajectory.

## Metrics

Per complete label record:

- E8;
- E3;
- actual E_HEAD;
- E_THETA;
- E_STORAGE;
- step ratio;
- estimator tridiagonal solve status;
- min/max capacity;
- min/max conductivity;
- full and two-half nonlinear work.

## Frozen P0 gates

E8 advances only if:

1. all full-step BDF2 trajectories complete;
2. at least 80 complete local labels;
3. E8 is finite and positive for every positive-error labelled point;
4. estimator tridiagonal solve succeeds for every labelled point;
5. overall Spearman(E8,E_HEAD) >= 0.95;
6. per-pattern Spearman >= 0.90 for R1, R1P5 and R2;
7. median `E_HEAD/E8` lies in [0.5,2.0];
8. at least 95% of finite positive ratios `E_HEAD/E8` lie in [0.25,2.0];
9. direct SAFE classification at `E8 <= 0.01 cm` has zero false-safe points;
10. at least 20% of actually safe points are classified safe;
11. one tridiagonal solve is the only estimator solve overhead.

No threshold or multiplier is changed after exposure.

## Successor rule

If P0 passes, freeze E8 unchanged and validate blindly on B12/O14 before any controller experiment.

If P0 fails, close this linearized-response estimator family. Do not fit a scalar multiplier.

Possible outcomes:

- `LINEARIZED_BDF2_LTE_RESPONSE_MECHANISM_QUALIFIED`;
- `CLOSED_LINEARIZED_BDF2_LTE_RESPONSE_NOT_QUALIFIED`.

## Production boundary

No production `src/**` change.
