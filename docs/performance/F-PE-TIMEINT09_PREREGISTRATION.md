# F-PE-TIMEINT09 preregistration — exact final-Newton-Jacobian BDF2 truncation response

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@5cb278cdc6463b3c88c873917671e60e672370a9`

Parent authority:

- TIMEINT05 qualifies variable-step fully implicit BDF2 for adjacent accepted ratio `0.5 <= r <= 2.0`;
- TIMEINT07 shows the analytical third-difference LTE signal is strongly predictive but not directly conservative;
- TIMEINT08 shows a simplified response operator `a0*M/h + L` improves direct classification but leaves one blind B12 false-safe;
- TIMEINT08 closeout identifies omission of the fully implicit conductivity-derivative Jacobian terms as the next mechanistic question.

## Purpose

Test whether propagating the same BDF2 truncation defect through the exact final converged Newton Jacobian removes the remaining material-dependent underprediction without requiring another nonlinear solve.

This is estimator research only.

## Temporal mechanism

Use the exact TIMEINT05 variable-step fully implicit BDF2 equations and TIMEINT04 representation-aware total-balance floor.

Four accepted head levels define the same third divided difference `D3` used in TIMEINT07/08.

For current step `h` and previous accepted step `k`:

`tau_h = h*(h+k)*D3`.

The defect RHS is the same mass-weighted temporal defect used by TIMEINT08:

`rhs_i = M_i * tau_h_i`

with `M_i = C_i(h_np1)*dz_i`.

No empirical multiplier, material term, forcing term, step-ratio correction or threshold adjustment is permitted.

## Exact response operator

For the accepted fully implicit BDF2 solve, capture the final normal tridiagonal Newton factorization produced by HeadCalc.

Use exactly the final arrays:

- `dfdh_upper`;
- `dfdh_main`;
- `dfdh_lower`;
- captured TRIDAG elimination coefficients/factors.

No response matrix is reassembled from simplified physics.

Perform one extra backsolve:

`J_final * delta = rhs`.

Estimator:

`E9 = max_i |delta_i|`.

This uses the exact final converged Newton linear operator, including fully implicit conductivity-derivative terms already present in HeadCalc.

## Factorization capture

Capture is test-only.

The binding may enable existing TRIDAG factorization capture unconditionally for this test harness.

The estimator must:

- require normal TRIDAG completion;
- fail closed on alternative-solver use;
- perform no additional Jacobian assembly;
- perform one extra backsolve only.

## Calibration bank P0

Same exposed mechanism bank as TIMEINT08:

- B01, infiltration 2 and 4 cm/day;
- O05, infiltration 2 and 4 cm/day;
- patterns R1, R1P5, R2;
- base mean dt 0.010 and 0.005 d;
- horizon 0.04 d.

Full variable-step BDF2 trajectory remains primary.

Two-half BDF2 is local research authority only.

## P0 metrics

Per complete label record:

- E9;
- E8;
- E3;
- actual E_HEAD;
- E_THETA;
- E_STORAGE;
- step ratio;
- exact-factor backsolve status;
- alternative-solver count;
- full and two-half deterministic nonlinear work.

## Frozen P0 gates

E9 advances only if all are true:

1. all full-step BDF2 trajectories complete;
2. at least 80 complete local labels;
3. exact-factor capture/backsolve succeeds for every complete labelled point;
4. no alternative solver is used on an estimator-authority point;
5. E9 is finite and positive for every positive-error labelled point;
6. overall Spearman(E9,E_HEAD) >= 0.95;
7. per-pattern Spearman >= 0.90 for R1, R1P5 and R2;
8. median `E_HEAD/E9` lies in [0.5,2.0];
9. at least 95% of positive finite ratios lie in [0.25,2.0];
10. max `E_HEAD/E9 <= 2.0`;
11. at `E9 <= 0.01 cm`, false-safe count = 0;
12. at least 50% of actually safe points are classified safe;
13. estimator overhead is one backsolve and zero extra nonlinear solves.

No gate moves after exposure.

## Blind holdout

If P0 passes, freeze E9 unchanged and evaluate on the same blind new-material envelope used by TIMEINT08A:

- B12 and O14;
- infiltration 1, 3 and 5 cm/day;
- patterns R1, R1P5, R2;
- base mean dt 0.010 and 0.005 d;
- horizon 0.04 d.

Holdout qualification requires:

1. all 36 full BDF2 trajectories complete;
2. at least 130 complete local labels;
3. no more than 2 trajectories with unavailable two-half research labels;
4. exact-factor backsolve succeeds for every complete label;
5. no estimator-authority alternative-solver use;
6. overall Spearman >=0.90;
7. per-pattern Spearman >=0.85;
8. median `E_HEAD/E9` in [0.5,2.0];
9. at least 95% of ratios in [0.25,2.0];
10. max ratio <=2.0;
11. zero false-safe classifications at E9<=0.01 cm;
12. safe coverage >=50%.

## Stop rule

If P0 fails, stop this response-estimator family.

If P0 passes but blind holdout fails, stop this response-estimator family.

Do not fit a scalar correction.

If exact-Jacobian response still produces the known B12 false-safe, the required successor is an embedded integrator pair rather than another response approximation.

## Production boundary

No production `src/**` change.

Possible outcomes:

- `EXACT_NEWTON_BDF2_LTE_RESPONSE_MECHANISM_QUALIFIED`;
- `EXACT_NEWTON_BDF2_LTE_RESPONSE_HOLDOUT_QUALIFIED`;
- `CLOSED_EXACT_NEWTON_RESPONSE_NOT_CONSERVATIVE`.
