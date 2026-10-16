# F-PE-TIMEINT06A result — calibrated cheap BDF2 head-error estimator holdout

Date: 2026-09-28

Status: `CLOSED_CALIBRATED_BDF2_HEAD_ESTIMATOR_FAILED`

Authority:

- canonical base: `integration/f-ci-canonical@e1b575f3e40ad7fe4cc6d26f5e383f5353218130`;
- Actions run: `36483519551`;
- holdout job: `109134713877`.

## Frozen estimator

`E_hat = 0.20 * S1`

with:

`S1 = 0.5*h*max|d_now-d_prev|`.

Local characterization threshold:

`E_limit = 0.01 cm`.

## Holdout bank

Previously unexposed hydraulic archetypes:

- B12;
- O14.

Forcing:

- 1, 3 and 5 cm/day infiltration.

Patterns:

- R1;
- R1P5;
- R2.

Base mean steps:

- 0.010 d;
- 0.005 d.

## Result

The estimator remains strongly rank-predictive:

- overall Spearman: 0.9365;
- R1: 0.8979;
- R1P5: 0.9573;
- R2: 0.9602.

Classification at 0.01 cm is also conservative in the observed complete labels:

- false-safe count: 0;
- actual-safe points: 91;
- predicted-and-actual safe points: 26;
- safe coverage: about 28.6%.

However the frozen holdout qualification fails.

### Calibration envelope failure

Maximum observed:

`E_HEAD/E_hat = 1.1867`.

Required:

`<= 1.0`.

The fixed 0.20 multiplier therefore underestimates at least one holdout local error.

Per preregistration no second multiplier is fitted post hoc.

### Research-authority completion failure

One holdout trajectory:

`O14, 3 cm/day, R2, base_dt=0.005 d`

fails in the second half of the full-versus-two-half research authority.

The full-step candidate produced several valid labels before the authority route failed.

This is not evidence that TIMEINT05 variable-step BDF2 itself is invalid; it is a limitation of this specific local two-half labelling construction on that point.

## Interpretation

The derivative-change signal contains strong local temporal-error information.

What failed is the assumption that one material-independent constant multiplier calibrated on B01/O05 upper-bounds B12/O14.

The estimator shape therefore needs a more principled BDF2 local-truncation-error construction rather than another empirical multiplier.

## Decision

Final classification:

`CLOSED_CALIBRATED_BDF2_HEAD_ESTIMATOR_FAILED`.

Do not:

- increase the multiplier after holdout;
- grant S1 direct timestep authority;
- infer a production tolerance from the zero false-safe observation.
