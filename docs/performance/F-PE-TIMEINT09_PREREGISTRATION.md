# F-PE-TIMEINT09 preregistration — final-Newton-Jacobian BDF2 truncation response

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@5cb278cdc6463b3c88c873917671e60e672370a9`

Parent authority:

- TIMEINT05 qualifies variable-step fully implicit BDF2 for adjacent accepted step ratios `0.5 <= r <= 2.0`;
- TIMEINT07 qualifies the third-history truncation signal as strongly predictive but not directly conservative;
- TIMEINT08 shows a simplified `a0*M/h + L` response operator is still non-conservative on one blind B12 point;
- no empirical multiplier may be fitted as a rescue.

## Purpose

Test whether the actual final tridiagonal Newton Jacobian already assembled by HeadCalc can convert the BDF2 truncation defect into a conservative local endpoint-head error estimate.

The candidate requires no extra Jacobian assembly and no extra nonlinear solve.

Research implementation may perform one extra tridiagonal solve using a copy of the final converged matrix.

## Exact response operator

For the converged full BDF2 candidate, capture the final HeadCalc matrix arrays:

- `dfdh_upper`;
- `dfdh_main`;
- `dfdh_lower`.

These are the exact tridiagonal coefficients from the last Newton Jacobian assembly used by the fully implicit TIMEINT05 BDF2 solve.

They include:

- BDF2 storage Jacobian coefficient `a0*C/h`;
- hydraulic face terms;
- fully implicit conductivity derivative contributions `dK/dh`;
- the exact fixed-flux boundary treatment of the qualified TIMEINT mechanism envelope.

No matrix term is reconstructed independently in TIMEINT09.

## Truncation forcing

Use the unchanged third-history derivative defect:

`tau_h = h*(h+k)*D3`.

Construct mass-weighted forcing:

`rhs_i = C_i(h_np1) * dz_i * tau_h_i`.

Solve with the captured final Newton matrix:

`J_final * delta = rhs`.

Candidate estimator:

`E9 = max_i |delta_i|`.

No multiplier, intercept, material term or ratio correction is allowed.

## Calibration bank

Use the same exposed B01/O05 mechanism bank:

- B01, infiltration 2 and 4 cm/day;
- O05, infiltration 2 and 4 cm/day;
- patterns R1, R1P5, R2;
- base mean dt 0.010 and 0.005 d;
- horizon 0.04 d.

## Research authority

Actual local endpoint error remains full variable-step BDF2 versus two BDF2 half steps from the same accepted origin/history.

The full-step trajectory remains authoritative for subsequent history.

Research-label failure is recorded and does not terminate a completed full BDF2 trajectory.

## Candidate overhead

TIMEINT09 P0 counts exactly:

- zero additional nonlinear solves;
- zero additional Jacobian assemblies;
- one tridiagonal response solve per estimator point.

The matrix-copy overhead is diagnostic-only and must be reported separately from the conceptual production path, where the final matrix/factorization could be retained in workspace.

## Frozen P0 gates

E9 advances only if:

1. all full-step BDF2 trajectories complete;
2. at least 80 complete local labels;
3. captured final Newton matrix is finite for every labelled point;
4. response solve succeeds for every labelled point;
5. E9 finite and positive for every positive-error labelled point;
6. overall Spearman(E9,E_HEAD) >=0.95;
7. per-pattern Spearman >=0.90 for R1, R1P5 and R2;
8. median `E_HEAD/E9` lies in [0.5,2.0];
9. at least 95% of positive finite ratios lie in [0.25,2.0];
10. max `E_HEAD/E9 <=2.0`;
11. at `E9<=0.01 cm`, false-safe count = 0;
12. at least 50% of actually safe points are classified safe.

No gate may be relaxed after result exposure.

## Stop rule

If E9 fails P0, close the response-estimator family.

Do not introduce another response approximation or scalar calibration in this line.

If E9 passes, freeze it unchanged and validate blindly on B12/O14 before any controller experiment.

## Production boundary

No production `src/**` change.

Possible outcomes:

- `FINAL_NEWTON_BDF2_RESPONSE_MECHANISM_QUALIFIED`;
- `CLOSED_FINAL_NEWTON_BDF2_RESPONSE_NOT_QUALIFIED`.
