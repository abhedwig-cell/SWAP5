# F-PE-TIMEARCH02 preregistration — executable timestep decision contracts

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@3b94726fe7d01aec42a5a53587769f38916203f4`

Parent:

F-PE-TIMEARCH01 target architecture.

## Purpose

Prove that explicit separation of:

- numerical proposal;
- event clip;
- process cap;
- solver retry;

can reproduce current Reference timestep decisions in a compatibility profile.

This is test-only architecture proof. No production source modification.

## Frozen compatibility formulas

Accepted successful step:

- start from accepted dt;
- if `numbit <= numbit_crit`: multiply by `fact_dt_increase`, cap at numerical max;
- if `numbit >= maxit`: multiply by `fact_dt_decrease`, floor at numerical min;
- apply process cap;
- apply event cap.

Failed trial retry:

- if `dt > failure_divisor * numerical_min`: retry dt = dt / failure_divisor;
- otherwise retry dt = numerical_min.

Day-start compatibility:

- optional legacy floor `sqrt(numerical_min*numerical_max)`;
- event/process caps then apply independently.

## Test matrix

Numerical minimum:

`0.001 d`

Numerical maximum:

`0.020 d`

Accepted dt values:

- 0.001
- sqrt(0.001*0.020)
- 0.010
- 0.020

Iteration counts:

- 1
- 4
- 5
- 8

with:

- `numbit_crit=4`;
- `maxit=8`;
- increase=2;
- decrease=0.5;
- failure divisor=2.

Event/process caps:

- unlimited;
- 0.050;
- 0.012;
- 0.006;
- 0.0005.

The test compares the separated decision pipeline against direct legacy formulas.

## Additional invariants

The executable contract must prove:

1. event clipping does not alter stored numerical max;
2. process clipping does not alter stored numerical max;
3. retry decision does not update accepted-step proposal state;
4. limiting reason is explicit;
5. proposal and executable dt are both retained;
6. legacy day-start behavior is optional compatibility policy, not scheduler behavior.

## Advancement

Advance TIMEARCH01 only if all matrix and ownership invariants pass at O0 and O2.

