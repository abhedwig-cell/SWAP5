# F-PE-TIMEINT08A result — blind holdout of linearized BDF2 LTE response estimator

Date: 2026-09-28

Status: `CLOSED_LINEARIZED_BDF2_LTE_RESPONSE_HOLDOUT_FAILED`

Authority:

- canonical base: `integration/f-ci-canonical@dec1233deb167a785c237c0fcb5d597d17d4bc6b`;
- Actions run: `36485284643`;
- holdout job: `109140593043`;
- conclusion: SUCCESS.

## Frozen estimator

The TIMEINT08 P0 estimator was used unchanged:

`tau_h = h*(h+k)*D3`

`J_e = a0*M/h + L`

`J_e delta = M*tau_h`

`E8=max|delta|`.

No multiplier or post-hoc correction was fitted.

## Holdout result

All 36 full-step variable-BDF2 trajectories complete.

Local research labels:

- complete labels: 143;
- unavailable labels: 1;
- incomplete-label trajectories: 1.

Predictivity remains strong:

- overall Spearman: 0.9253;
- R1: 0.9376;
- R1P5: 0.9340;
- R2: 0.9148.

Scale:

- median `E_HEAD/E8 = 0.7150`;
- min = 0.2495;
- max = 1.8367;
- 99.30% of ratios lie in [0.25,2.0].

Direct local SAFE classification at `E8<=0.01 cm`:

- actually safe points: 89;
- true-safe: 70;
- safe coverage: 78.65%;
- false-safe: 1.

## False-safe

The false-safe is:

- material: B12;
- infiltration: 5 cm/day;
- pattern: R1;
- dt = 0.005 d;
- E3 = 0.00989263 cm;
- E8 = 0.00987979 cm;
- actual E_HEAD = 0.01183310 cm.

Thus the simplified linearized response barely changes the TIMEINT07 estimate on the failing point and remains non-conservative at the frozen 0.01 cm decision threshold.

## Research-label unavailable point

The single unavailable two-half label is unchanged from TIMEINT07A:

- O14;
- 3 cm/day;
- R2;
- dt = 0.003333 d;
- first half completes;
- second half does not.

The full-step BDF2 trajectory completes.

## Decision

The frozen zero-false-safe gate fails.

Classification:

`CLOSED_LINEARIZED_BDF2_LTE_RESPONSE_HOLDOUT_FAILED`.

No multiplier or threshold adjustment is allowed.
