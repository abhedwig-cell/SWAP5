# F-PE-TIMEARCH12 result — AUTO_REFERENCE effort-controller discovery

Date: 2026-09-28

Status: `CLOSED_EFFORT_ONLY_AUTO_CONTROLLER_REJECTED`

Canonical base:

`integration/f-ci-canonical@eb3a5718a5b7b0b24ebe744e595b781882e7f25a`

Evidence:

- Actions run: `36430360032`;
- discovery job: `108954663091`;
- conclusion: SUCCESS.

## Candidate family

Continuous effort controller:

`factor = clamp(sqrt(I_target/max(I,1)),0.5,2.0)`

with:

- no normal operating DTMAX;
- internal retry floor = 0.001 d;
- rejected attempts excluded from accepted preferred-step memory;
- horizon as hard event;
- initial internal bootstrap dt = 0.005 d.

Frozen targets:

- I3;
- I4;
- I5;
- I6.

## Results

### I3

- P-C1 pass: 8/16;
- median deterministic work reduction: -340.6%;
- wet/ponding preservation: FAIL.

### I4

- P-C1 pass: 10/16;
- median deterministic work reduction: -163.9%;
- wet/ponding preservation: FAIL.

### I5

- P-C1 pass: 12/16;
- median deterministic work reduction: -52.5%;
- wet/ponding preservation: FAIL.

### I6

- P-C1 pass: 16/16;
- wet/ponding preservation: PASS;
- median deterministic work reduction: -20.8%.

Negative work reduction means more deterministic solver work than LEGACY_NUMERICS.

## Interpretation

Nonlinear iteration count is not a suitable primary temporal-control signal.

A conservative target can preserve the bounded physical envelope, but it does so by over-refining enough cases that total solver work increases materially.

More aggressive effort targets are both slower and less robust.

This is consistent with earlier BOFEK evidence showing that iteration-count thresholds are weak performance levers.

## Decision

No effort-only AUTO_REFERENCE controller advances.

The next controller candidate must consume richer accepted-state or boundary-risk information rather than reparameterizing nonlinear iteration count.

No production controller is enabled.
