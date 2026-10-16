# F-PE-STATESTEP01 result — absolute accepted-step head-change controller

Date: 2026-09-28

Status: `CLOSED_ABSOLUTE_HEAD_SCALE_REJECTED`

Authority:

- canonical base: `integration/f-ci-canonical@0714438bbb248e8056b0ad096dc02ceae8e48e22`;
- Actions run: `36415918545`;
- conclusion: SUCCESS.

## Result

No absolute-head target advanced.

H_ONLY targets 0.25, 0.5, 1, 2 and 4 cm produced median deterministic work changes of approximately:

- -633%;
- -311%;
- -227%;
- -72%;
- -25%.

H_SURF, which additionally caps dt at the Reference DTMAX after ponding/runoff activation, also produced no advancing candidate. Best tested arm, target 4 cm, still regressed work by about 18% and passed only 14/16 P-C1 cases.

## Interpretation

Absolute `max|dh|` is not a portable timestep-difficulty scale.

Dry profiles can undergo large pressure-head changes at strongly negative heads without requiring small temporal steps. A fixed absolute head-change target therefore over-refines the easy dry part of the domain.

The surface safeguard does not repair this fundamental scaling problem.

## Decision

Reject absolute-head accepted-step control.

No production code change.

Successor may test a dimensionless state-normalized head-change indicator, preregistered independently.
