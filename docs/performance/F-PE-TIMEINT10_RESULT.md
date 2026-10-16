# F-PE-TIMEINT10 P0 result — embedded BDF2/BE endpoint pair

Date: 2026-09-29

Status: `EMBEDDED_BDF2_BE_MECHANISM_QUALIFIED`

Authority:

- canonical base: `integration/f-ci-canonical@3aab0ac589766f409911b06c28ff081c8e68a69b`;
- Actions run: `36516000023`;
- P0 job: `109238284952`;
- conclusion: SUCCESS.

## Candidate

At the converged fully implicit BDF2 endpoint, form the exact Backward Euler storage residual difference and apply one backsolve through the already captured final BDF2 Newton factorization.

Estimator:

`E10 = max|delta_BE|`.

No empirical scaling and no additional nonlinear solve.

## Result

Calibration bank:

- B01/O05;
- infiltration 2 and 4 cm/day;
- R1, R1P5, R2;
- base mean dt 0.010 and 0.005 d.

Complete labels:

`96/96`.

Predictivity:

- overall Spearman: about `0.9180`;
- R1: about `0.8794`;
- R1P5: about `0.9245`;
- R2: about `0.9029`.

Direct SAFE classification at `E10 <= 0.01 cm`:

- false-safe: `0`;
- actually safe: `95`;
- correctly classified safe: `47`;
- safe coverage: about `49.5%`.

Cost:

- one extra tridiagonal backsolve;
- zero extra nonlinear solves;
- zero extra Jacobian assemblies.

Scale is deliberately conservative:

- median actual/E10: about `0.067`;
- max actual/E10: about `0.159`.

No scale calibration is applied.

## Decision

All frozen P0 gates pass.

Classification:

`EMBEDDED_BDF2_BE_MECHANISM_QUALIFIED`.

Freeze the estimator unchanged for blind B12/O14 holdout.
