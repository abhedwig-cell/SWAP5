# F-PE-TIMEINT11 result — TR-BDF2 / ESDIRK cost feasibility

Date: 2026-09-29

Status: `CLOSED_TRBDF2_DEFAULT_COST_TOO_HIGH`

Authority:

- canonical base: `integration/f-ci-canonical@2bf6c717647dc3fce685d5b46af5a8d859d2255a`;
- Actions run: `36516525202`;
- cost job: `109239930705`;
- conclusion: SUCCESS.

## Optimistic lower-bound construction

For each outer interval:

1. one fully implicit BE stage over `gamma*h`, with `gamma=2-sqrt(2)`;
2. one fully implicit variable-step BDF2 stage over `(1-gamma)*h`.

This is not claimed as exact TR-BDF2 accuracy.

It is an optimistic nonlinear-work lower bound for a two-stage stiff architecture using existing solver machinery.

## Result

Eight smooth fixed-flux trajectories completed.

Work ratio two-stage lower bound / single fully implicit BDF2:

- minimum: `1.725`;
- median: `1.975`;
- maximum: `2.000`.

Individual ratios range from about 1.73 to 2.00.

## Decision

The preregistered >1.70 rejection gate is crossed.

Classification:

`CLOSED_TRBDF2_DEFAULT_COST_TOO_HIGH`.

A true TR-BDF2 implementation cannot plausibly be cheaper than this optimistic two-implicit-stage lower bound.

Therefore TR-BDF2 / ESDIRK is rejected as the default smooth-regime production integrator.

It may remain a transition/restart fallback research option if future evidence shows a specific robustness advantage that offsets its structural cost.
