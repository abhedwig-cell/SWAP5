# F-PE-TIMEINT08 P0 result — linearized BDF2 truncation-defect response estimator

Date: 2026-09-28

Status: `LINEARIZED_BDF2_LTE_RESPONSE_MECHANISM_QUALIFIED`

Authority:

- canonical base: `integration/f-ci-canonical@dec1233deb167a785c237c0fcb5d597d17d4bc6b`;
- Actions run: `36485063319`;
- characterization job: `109139848133`;
- conclusion: SUCCESS.

## Candidate

The analytical BDF2 third-difference derivative defect is propagated through one local tridiagonal Richards response solve:

`J_e = a0*M/h + L`

`J_e delta = M tau_h`

`E8 = max|delta|`.

No empirical multiplier is used.

## Result

Complete labelled points:

`96`.

All estimator tridiagonal solves succeeded.

Correlation with actual full-versus-two-half local max head error:

- overall Spearman: `0.9613`;
- R1: `0.9479`;
- R1P5: `0.9597`;
- R2: `0.9582`.

Scale:

- median `E_HEAD/E8 = 0.6726`;
- min = `0.2483`;
- max = `1.3928`;
- 98.96% lie within [0.25,2.0].

Direct local SAFE classification at `E8 <= 0.01 cm`:

- false-safe: `0`;
- actually safe: `95`;
- true-safe: `90`;
- safe coverage: `94.74%`.

All frozen P0 gates pass.

## Interpretation

The extra local hydraulic-response solve preserves the strong third-history ordering while materially improving direct SAFE discrimination.

The estimator cost is one tridiagonal solve and no extra nonlinear solve.

This is the first TIMEINT estimator that passes both predictive and direct-conservative calibration gates without an empirical correction factor.

## Decision

Classification:

`LINEARIZED_BDF2_LTE_RESPONSE_MECHANISM_QUALIFIED`.

Advance E8 unchanged to blind B12/O14 holdout.
