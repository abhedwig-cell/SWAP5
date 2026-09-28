# F-PE-TIMEINT06 preregistration — cheap local error estimator for variable-step BDF2

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@e1b575f3e40ad7fe4cc6d26f5e383f5353218130`

Parent authority:

- TIMEINT05 qualifies variable-step fully implicit BDF2 for adjacent accepted step ratios
  `0.5 <= h_n/h_{n-1} <= 2.0`;
- no adaptive BDF2 controller is admitted;
- no production BDF2 source exists.

## Purpose

Identify whether a cheap local temporal-error signal exists for variable-step BDF2 that can later support automatic timestep selection without requiring two additional nonlinear solves on every accepted step.

This workunit is estimator characterization only.

No candidate estimator receives timestep authority.

## Physical/method scope

Use the qualified smooth fixed-flux, fully implicit-conductivity BDF2 mechanism from TIMEINT05.

Materials/forcing:

- B01, infiltration 2 cm/day;
- B01, infiltration 4 cm/day;
- O05, infiltration 2 cm/day;
- O05, infiltration 4 cm/day.

Variable-step patterns:

- R1;
- R1P5;
- R2.

R3 is excluded because TIMEINT05 did not qualify ratio 3.

## Calibration trajectories

Base mean steps:

- 0.010 d;
- 0.005 d.

Horizon:

- 0.04 d.

The first step remains fully implicit Backward Euler bootstrap.

Only steps with complete BDF2 history are estimator points.

## Expensive local research authority

For each estimator point with current accepted origin:

1. snapshot:
   - `h_n`;
   - `theta_n`;
   - `theta_{n-1}`;
   - `h_{n-1}`;
   - previous accepted dt `h_{n-1,dt}`;
2. execute one variable-step BDF2 full step of duration `h`;
3. independently from the same snapshot execute:
   - BDF2 half step `h/2` using the original history;
   - BDF2 second half step `h/2` using the first-half accepted history;
4. define actual local endpoint errors:
   - `E_HEAD = max |h_full - h_twohalf|`;
   - `E_THETA = max |theta_full - theta_twohalf|`;
   - `E_STORAGE = |storage_full - storage_twohalf|`.

The normal research trajectory then follows the two-half endpoint so the next estimator origin follows the refined route and does not inherit the full-step local error.

The two-half work is research authority only and is not part of candidate estimator cost.

## Cheap candidate signals

All candidate signals use only accepted history and the converged full-step endpoint.

### S1 — derivative-change raw head defect

`d_now = (h_full-h_n)/h`

`d_prev = (h_n-h_nm1)/h_prev`

`S1 = 0.5*h*max|d_now-d_prev|`.

This is analogous to the raw derivative-history scale already used in the production fixed-flux temporal-indicator family, but without an extra operator solve.

### S2 — linear head extrapolation defect

`h_pred = h_n + (h/h_prev)*(h_n-h_nm1)`

`S2 = max|h_full-h_pred|`.

### S3 — linear water-content extrapolation defect

`theta_pred = theta_n + (h/h_prev)*(theta_n-theta_nm1)`

`S3 = max|theta_full-theta_pred|`.

No coefficient fitting occurs before primary correlation results are exposed.

## Primary mechanism gates

For each signal against actual `E_HEAD` across all complete estimator points:

1. at least 40 complete labelled points;
2. Spearman rank correlation >=0.85;
3. correlation >=0.75 separately in each of R1, R1P5 and R2;
4. signal is finite at every complete point;
5. no mass/storage ledger regression in the research harness.

Any signal satisfying gates 1-5 is considered predictive enough to enter a separately preregistered calibration step.

## Strict no-post-hoc rule

TIMEINT06 P0 does not fit a multiplier or acceptance threshold.

If a signal is predictive but not directly calibrated, open TIMEINT06A with calibration/holdout separation.

If none satisfies the correlation gates, close the cheap history-estimator family without threshold fitting.

## Secondary diagnostics

Record:

- local step ratio;
- full and two-half nonlinear work;
- boundary/forcing case;
- actual `E_HEAD`, `E_THETA`, `E_STORAGE`;
- S1, S2, S3.

## Production boundary

No production `src/**` change.

Possible P0 classifications:

- `CHEAP_BDF2_ERROR_SIGNAL_PREDICTIVE`;
- `CLOSED_CHEAP_BDF2_ERROR_SIGNAL_NOT_PREDICTIVE`;
- `BLOCKED_<reason>`.
