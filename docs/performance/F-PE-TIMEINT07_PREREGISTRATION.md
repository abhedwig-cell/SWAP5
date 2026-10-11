# F-PE-TIMEINT07 preregistration — step-ratio-aware third-difference BDF2 LTE estimator

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@55762688c2d613aa7cf50278bae3beaabf5fcd0b`

Parent authority:

- TIMEINT05 qualifies variable-step fully implicit BDF2 for adjacent step ratios 0.5 through 2.0;
- TIMEINT06 shows first-derivative-change history is strongly predictive but a fixed empirical multiplier does not hold across materials.

## Purpose

Test a mathematically BDF2-specific, solve-free local head-error estimator based on a third divided difference across four accepted state levels.

No timestep authority and no production source change.

## Analytical estimator

For current step `h`, previous step `k`, and the variable-step BDF2 coefficient:

`a0=(1+2r)/(1+r)`, with `r=h/k`.

Use accepted head levels at:

- `t_{n+1}`: converged candidate;
- `t_n`: current accepted origin;
- `t_{n-1}`: previous accepted endpoint;
- `t_{n-2}`: second previous accepted endpoint.

Let `D3(h)` be the componentwise third Newton divided difference over these four nonuniform times.

For the derivative formula, the quadratic interpolation derivative defect at `t_{n+1}` is proportional to:

`h*(h+k)*D3`.

Convert derivative defect to a local endpoint-head scale using the implicit BDF2 endpoint coefficient `a0/h`:

`E3 = h^2*(h+k)/a0 * max_i |D3_i|`.

No fitted multiplier is used in P0.

## Calibration bank

Reuse the smooth fixed-flux B01/O05 mechanism bank:

- B01, 2 and 4 cm/day;
- O05, 2 and 4 cm/day.

Patterns:

- R1;
- R1P5;
- R2.

Base mean steps:

- 0.010 d;
- 0.005 d.

The first two steps only establish history. Estimator points begin when four state levels are available.

## Research authority

At each estimator point:

1. execute the full variable-step BDF2 candidate;
2. independently execute two BDF2 half steps from the same origin/history;
3. define actual local head error:
   `E_HEAD=max|h_full-h_twohalf|`;
4. discard the two-half route and continue the normal full-step BDF2 trajectory.

The two-half route is research authority only.

## P0 mechanism gates

Advance the analytical E3 mechanism only if:

1. at least 80 complete estimator points;
2. all calibration trajectories complete;
3. E3 finite and positive for every nonzero-error point;
4. overall Spearman(E3,E_HEAD) >=0.90;
5. per-pattern Spearman >=0.80 for R1, R1P5 and R2;
6. median `E_HEAD/E3` between 0.5 and 2.0;
7. at least 90% of finite positive ratios `E_HEAD/E3` lie within [0.25,4.0].

These gates test both ordering and first-principles scale.

## Next step

If P0 advances, open a separately preregistered B12/O14 holdout with the analytical coefficient frozen exactly as above.

Do not fit a calibration multiplier in TIMEINT07.

Possible outcomes:

- `THIRD_DIFFERENCE_BDF2_LTE_MECHANISM_QUALIFIED`;
- `CLOSED_THIRD_DIFFERENCE_BDF2_LTE_NOT_QUALIFIED`.

## Production boundary

No production `src/**` change.
