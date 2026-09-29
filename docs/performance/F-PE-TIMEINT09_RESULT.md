# F-PE-TIMEINT09 P0 result — exact final-Newton-Jacobian BDF2 truncation response

Date: 2026-09-29

Status: `EXACT_NEWTON_BDF2_LTE_RESPONSE_MECHANISM_QUALIFIED`

Authority:

- canonical base: `integration/f-ci-canonical@5cb278cdc6463b3c88c873917671e60e672370a9`;
- Actions run: `36515503746`;
- conclusion: SUCCESS.

## Candidate

The TIMEINT07 third-history BDF2 truncation defect is propagated through the exact final converged Newton tridiagonal factorization captured from the accepted fully implicit BDF2 solve.

No Jacobian reassembly and no extra nonlinear solve are performed.

One additional backsolve is used:

`J_final * delta = M * tau_h`

`E9 = max|delta|`.

## P0 result

Calibration bank:

- B01/O05;
- infiltration 2 and 4 cm/day;
- R1/R1P5/R2;
- base dt 0.010 and 0.005 d.

Complete labels:

`96`.

All full BDF2 trajectories complete.

All factor captures and backsolves succeed.

No estimator-authority point used the alternative solver.

Predictivity:

- overall Spearman: `0.9592`;
- R1: `0.9468`;
- R1P5: `0.9567`;
- R2: `0.9516`.

Scale:

- median actual/E9: `0.7167`;
- minimum: `0.2564`;
- maximum: `1.4954`;
- 100% of positive finite ratios lie within [0.25, 2.0].

Direct SAFE classification at E9 <= 0.01 cm:

- false-safe: `0`;
- actually safe: `95`;
- true-safe: `90`;
- safe coverage: `94.74%`.

## Decision

All frozen P0 gates pass.

Classification:

`EXACT_NEWTON_BDF2_LTE_RESPONSE_MECHANISM_QUALIFIED`.

Freeze E9 unchanged for blind B12/O14 holdout.
