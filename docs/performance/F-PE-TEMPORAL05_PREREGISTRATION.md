# F-PE-TEMPORAL05 — blinded temporal accuracy/performance Pareto frontier

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

Parent: `F-PE-TEMPORAL04` / PR #648

Parent head: `c9101b13a63469ac1963097024bf1005fdd297a5`

## Trigger

TEMPORAL04 established a real Pareto trade-off:

- `HIST_HALF = max(1e-5, 0.5*dt*||h_dot_previous||_inf)` satisfies the fixed physical oracle-error envelope on 48/48 points;
- but it incurs one temporal retry on every point and is about 2.29x slower than a direct-accept benchmark;
- looser P0 policies remove retries but exceed the fixed head/theta bounds.

Do not move the error bounds post hoc.

## Purpose

Identify whether a coefficient between the half-history and direct-accept regimes can reduce retry cost while preserving the same physical error envelope, using a calibration/holdout design.

Research-only. No production temporal-policy change.

## Policy family

`budget(c) = max(1e-5 cm, c * dt * ||h_dot_previous||_inf)`

Calibration coefficients:

- 0.55;
- 0.60;
- 0.65;
- 0.70;
- 0.75;
- 0.80;
- 0.90.

`c=0.50` remains the baseline. `c=1.00` is not a selectable calibration arm because TEMPORAL04 already showed it exceeds the fixed P1 state envelope globally.

## Frozen physical envelope

Unchanged from TEMPORAL04 P1:

- completion required;
- max terminal |dh| versus refined oracle <= 0.01 cm;
- max terminal |dtheta| <= 1e-5;
- max relative terminal bottom-flux difference <= 1%;
- max relative integrated bottom-exchange difference <= 0.5%;
- complete mass accounting.

## Calibration split

Calibration origins:

- B01 wet;
- B12 wet;
- O14 mid.

For each:

- both +/-10% dynamic-history directions;
- offsets +/-0.001 and +/-0.01 cm.

Total calibration points: 24 per coefficient.

## Selection rule

A coefficient is calibration-feasible only if all 24 points satisfy the frozen physical envelope.

Among feasible coefficients:

1. choose the coefficient with the fewest total transaction retries;
2. tie-break on fewest temporal rejections;
3. tie-break on smallest coefficient.

The selected coefficient is frozen before holdout evaluation.

If no coefficient improves retry count relative to c=0.50 while remaining feasible, close without a candidate.

## Blind holdout

Holdout origins:

- B01 mid;
- O05 wet;
- O14 wet.

Same history directions and offsets: 24 blind points.

The frozen coefficient must:

- complete 24/24;
- satisfy the same physical envelope;
- preserve complete mass accounting;
- not exceed the c=0.50 retry count on the holdout;
- demonstrate runtime improvement in paired repeated-trial timing versus c=0.50.

## Oracle authority

Use the recovered BALTOL01/BALTOL02 fixed-substep Reference oracle with the qualified integrated-depth balance floor.

## Stop conditions

Stop without admission if the selected coefficient fails the blind holdout, if the physical envelope is exceeded, or if runtime does not improve materially.

No production source change is allowed in TEMPORAL05.