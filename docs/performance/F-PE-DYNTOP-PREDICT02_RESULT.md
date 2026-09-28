# F-PE-DYNTOP-PREDICT02 result — two-step normalized-history classifier

Date: 2026-09-28

Status: `CALIBRATION_ADVANCED_H0`

Authority:

- current canonical: `integration/f-ci-canonical@3b94726fe7d01aec42a5a53587769f38916203f4`;
- parent DYNERR01 is incorporated in branch history;
- Actions run: `36418913146`;
- history-classifier job: `108916630806`;
- conclusion: SUCCESS.

## Calibration set

The classifier observed 31 labelled proposed large intervals:

- locally SAFE: 21;
- locally UNSAFE: 10;
- one source case later became incomplete, but labels generated before that failure were retained.

Local SAFE remained the preregistered full-versus-two-half P-C1-style endpoint criterion.

## Frozen rules

### H0

Requires:

- two accepted history steps available;
- origin-frozen dynamic-top predictor available;
- origin-frozen runoff potential false;
- most recent normalized accepted head movement `r_last <= 0.10`.

Result:

- true safe: 12;
- false safe: 0;
- true unsafe: 10;
- false unsafe: 9;
- safe coverage: 57.1%;
- ADVANCE.

### H1

`r_last <= 0.20`.

- safe coverage: 81.0%;
- false safe: 1;
- rejected by zero-false-safe gate.

### H2 / H3

Trend-based rules produced zero false safe but zero safe coverage.

They are non-useful always-conservative rules and do not advance.

## Interpretation

Two-step availability plus the most recent normalized accepted head movement adds information that the surface-only classifier lacks.

H0 is deliberately conservative: it rejects 9 of 21 actually safe intervals, but it did not release any of the 10 unsafe intervals in calibration.

This is the first cheap pre-solve classifier in the BOFEK/state-aware sequence to satisfy the frozen safety and nontrivial-coverage gates.

## Decision

Freeze H0 before validation.

No timestep authority and no production change are granted by this calibration result.
