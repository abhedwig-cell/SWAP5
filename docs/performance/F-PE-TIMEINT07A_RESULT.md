# F-PE-TIMEINT07A result — blind holdout of analytical BDF2 LTE estimator

Date: 2026-09-28

Status: `CLOSED_ANALYTICAL_BDF2_LTE_HOLDOUT_FAILED`

Authority:

- canonical base: `integration/f-ci-canonical@55762688c2d613aa7cf50278bae3beaabf5fcd0b`;
- Actions run: `36484370885`;
- holdout job: `109137554715`;
- conclusion: SUCCESS.

## Frozen estimator

`E3 = h^2*(h+k)/a0 * max|D3|`

with no multiplier or fitted correction.

## Holdout result

All 36 full-step BDF2 trajectories complete.

Local research labels:

- complete labels: 143;
- unavailable labels: 1;
- incomplete-label trajectories: 1.

Estimator ranking remains strong:

- overall Spearman: 0.9382;
- R1: 0.9559;
- R1P5: 0.9413;
- R2: 0.9206.

Scale behavior also remains compact:

- median `E_HEAD/E3 = 0.6042`;
- max `E_HEAD/E3 = 1.6296`;
- 99.3% of ratios lie within [0.25,4.0].

## False-safe

One actual false-safe occurs:

- material: B12;
- rain: 5 cm/day;
- pattern: R1;
- dt: 0.005 d;
- E3: 0.0098926 cm;
- actual E_HEAD: 0.0118331 cm.

Thus the direct 0.01 cm local SAFE threshold is not conservative.

## Research-label unavailable point

One two-half research label is unavailable:

- material: O14;
- rain: 3 cm/day;
- pattern: R2;
- step ratio: 0.5;
- dt: 0.003333 d;
- first half solves;
- second half fails.

The full-step BDF2 trajectory itself completes. This is therefore an authority-label limitation, not a full-step mechanism failure.

## Preregistration defect

The holdout preregistration required at least 240 complete labels.

Given 36 trajectories with:
- 2 labels at base_dt=0.010 d;
- 6 labels at base_dt=0.005 d;

the theoretical maximum is 144 labels.

The 240-label threshold was therefore impossible by construction.

This is recorded as a preregistration design error.

It does not affect the scientific decision because the frozen zero-false-safe gate independently fails.

## Decision

The analytical third-difference estimator remains scientifically informative but is not directly conservative enough for timestep acceptance at the 0.01 cm threshold.

Classification:

`CLOSED_ANALYTICAL_BDF2_LTE_HOLDOUT_FAILED`.
