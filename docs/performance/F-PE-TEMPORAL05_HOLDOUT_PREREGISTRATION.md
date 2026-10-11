# F-PE-TEMPORAL05 blind holdout — frozen c=0.65

Date: 2026-09-26

Status: `PREREGISTERED_BLIND_HOLDOUT`

## Frozen candidate

`budget = max(1e-5 cm, 0.65 * dt * ||h_dot_previous||_inf)`

The coefficient is frozen by the calibration result and cannot be changed in response to holdout outcomes.

## Holdout origins

- B01 mid;
- O05 wet;
- O14 wet.

For each:

- both +/-10% dynamic-history directions;
- offsets +/-0.001 and +/-0.01 cm.

Total: 24 blind physical points.

## Comparator

`c=0.50` HIST_HALF baseline.

## Replication

Three fresh processes per physical point and arm.

For timing, each process performs:

- one diagnostic trial;
- three warm-up same-origin trials;
- twenty measured same-origin trials with candidate discard.

Only the trial call is timed.

## Blind acceptance gates

The frozen c=0.65 candidate must:

- complete 24/24 physical points in every repetition;
- satisfy the unchanged physical envelope:
  - max |dh| <= 0.01 cm;
  - max |dtheta| <= 1e-5;
  - max relative terminal-flux difference <= 1%;
  - max relative integrated-exchange difference <= 0.5%;
- preserve complete mass accounting;
- have total retries no greater than c=0.50;
- show a lower median paired repeated-trial runtime than c=0.50.

Failure of any gate closes TEMPORAL05 without admission.

No production temporal-policy change is allowed.