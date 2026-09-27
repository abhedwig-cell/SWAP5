# F-PE-TEMPORAL05 blind holdout result — frozen c=0.65

Date: 2026-09-26

Status: `BLIND_HOLDOUT_PASS`

## Frozen policy

`budget = max(1e-5 cm, 0.65 * dt * ||h_dot_previous||_inf)`

The coefficient was selected and frozen from the calibration set before any holdout execution.

## Holdout set

- B01 mid;
- O05 wet;
- O14 wet;
- both +/-10% dynamic-history directions;
- offsets +/-0.001 and +/-0.01 cm;
- 24 physical points;
- three fresh-process repetitions per arm.

Comparator:

`c=0.50`.

## Physical result

c=0.65:

- completion: 24/24;
- mass complete: yes;
- max absolute mass residual: 0;
- max terminal |dh| versus refined oracle = 6.5653e-3 cm;
- max |dtheta| = 6.2824e-6;
- max relative terminal-flux error = 7.199e-3, about 0.72%;
- max relative integrated-exchange error = 1.677e-3, about 0.17%.

All blind physical gates pass.

The worst-case physical envelope is unchanged from the c=0.50 baseline on this holdout.

## Retry result

c=0.50 baseline:

- retries = 24;
- temporal rejections = 24;
- solver rejections = 0.

c=0.65 selected:

- retries = 16;
- temporal rejections = 16;
- solver rejections = 0.

The selected coefficient removes one-third of the holdout temporal retries without introducing solver failures.

## Runtime

Paired repeated-trial timing:

- median selected / baseline runtime ratio = 0.99188;
- minimum paired ratio = 0.43714;
- maximum paired ratio = 1.03191.

The aggregate median improvement is modest because two-thirds of the holdout points retain the same retry path as c=0.50.

Where the selected policy removes the retry, the observed paired ratio can fall to roughly 0.44, consistent with avoiding an extra transaction solve.

## Decision

The frozen c=0.65 candidate passes the blind holdout exactly under the preregistered gates.

This is evidence of a reproducible Pareto improvement over c=0.50, but not yet production admission.