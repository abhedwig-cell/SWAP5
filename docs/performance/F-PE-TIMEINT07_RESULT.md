# F-PE-TIMEINT07 P0 result — third-divided-difference BDF2 LTE estimator

Date: 2026-09-28

Status: `THIRD_DIFFERENCE_BDF2_LTE_MECHANISM_QUALIFIED`

Authority:

- canonical base: `integration/f-ci-canonical@55762688c2d613aa7cf50278bae3beaabf5fcd0b`;
- Actions run: `36484038455`;
- characterization job: `109136423880`;
- conclusion: SUCCESS.

## Analytical estimator

For current step `h`, previous step `k`, variable-step BDF2 endpoint coefficient `a0`, and third divided difference `D3` over four accepted head levels:

`E3 = h^2*(h+k)/a0 * max|D3|`.

No fitted multiplier is used.

## Result

Complete labelled estimator points:

`96`.

Spearman correlation with actual full-versus-two-half max head error:

- overall: `0.9615`;
- R1: `0.9494`;
- R1P5: `0.9597`;
- R2: `0.9582`.

All frozen rank-correlation gates pass.

Scale diagnostics:

- median `E_HEAD/E3 = 0.6713`;
- min = `0.2483`;
- max = `1.3754`;
- fraction within [0.25,4.0] = `98.96%`.

The estimator therefore carries both strong ordering and first-principles magnitude information across the qualified ratio<=2 variable-step BDF2 envelope.

## Interpretation

Unlike the TIMEINT06 first-derivative-change signal, E3 explicitly represents higher temporal curvature and the actual variable-step BDF2 geometry.

This materially improves predictivity without any empirical material/regime term or extra nonlinear solve.

## Decision

Classification:

`THIRD_DIFFERENCE_BDF2_LTE_MECHANISM_QUALIFIED`.

Advance the unchanged analytical estimator to a new-material holdout.
