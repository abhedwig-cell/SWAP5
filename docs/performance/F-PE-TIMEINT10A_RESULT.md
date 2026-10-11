# F-PE-TIMEINT10A result — blind holdout embedded BDF2/BE endpoint pair

Date: 2026-09-29

Status: `CLOSED_EMBEDDED_BDF2_BE_TOO_CONSERVATIVE`

Authority:

- canonical base: `integration/f-ci-canonical@3aab0ac589766f409911b06c28ff081c8e68a69b`;
- Actions run: `36516085757`;
- holdout job: `109238554265`;
- conclusion: SUCCESS.

## Frozen estimator

At the converged BDF2 endpoint:

- form the exact Backward Euler storage residual difference;
- apply one backsolve through the captured final BDF2 Newton factorization;
- `E10=max|delta_BE|`.

No multiplier or recalibration was applied.

## Blind holdout result

Full trajectories:

- 36/36 complete.

Complete local labels:

- 143;
- unavailable labels: 1 trajectory.

Predictivity:

- overall Spearman: `0.9614`;
- R1: `0.9439`;
- R1P5: `0.9701`;
- R2: `0.9605`.

Conservativeness:

- false-safe: `0`;
- actually safe points: `89`;
- correctly classified safe at E10<=0.01 cm: `1`;
- safe coverage: `1.12%`.

Scale:

- median actual/E10: `0.1195`;
- minimum: `0.0475`;
- maximum: `0.2236`.

The raw BDF2/BE difference is therefore roughly an order of magnitude more conservative than the actual BDF2 local error on much of the blind envelope.

## Decision

The frozen holdout coverage gate fails badly.

Classification:

`CLOSED_EMBEDDED_BDF2_BE_TOO_CONSERVATIVE`.

No post-hoc scaling is permitted.

The one-correction BE companion is not suitable as direct adaptive timestep authority in raw form.
