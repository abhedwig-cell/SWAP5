# F-PE-TIMEINT04 result — closed-loop mixed-LTE adaptive backward Euler

Date: 2026-09-28

Status: `CLOSED_MIXED_LTE_CONTROLLER_NO_GAIN`

Canonical authority:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

Evidence:

- preregistration: `docs/performance/F-PE-TIMEINT04_PREREGISTRATION.md`;
- Actions run: `36437158400`;
- job: `108977918508`;
- conclusion: SUCCESS.

## Candidate

Qualified TIMEINT03 mixed-state score:

`S = max(LTE_H_INF/0.50 cm, LTE_THETA_INF/1e-4)`.

Backward-Euler accepted steps were controlled directly by `S <= 1`.

Frozen safety factors:

- A70 = 0.70;
- A80 = 0.80;
- A90 = 0.90.

All rejected solver/temporal candidates count in total deterministic work.

## Result

No arm advances.

### A70

- P-C1 pass: 11/16;
- temporal rejections: 20;
- median reject fraction: about 3.6%;
- median deterministic work reduction: -100%.

### A80

- P-C1 pass: 12/16;
- temporal rejections: 22;
- median reject fraction: about 4.7%;
- median deterministic work reduction: about -87.3%.

### A90

- P-C1 pass: 11/16;
- temporal rejections: 27;
- median reject fraction: about 6.7%;
- median deterministic work reduction: about -66.7%.

Wet/ponding preservation fails for every arm.

## Interpretation

The mixed-state LTE mechanism is predictive enough to be useful diagnostically, but direct first-order backward-Euler control with the frozen P-C1-related score is not performant.

The dominant cost is not an extreme rejection cascade.

Instead the controller systematically selects more/smaller accepted intervals because a first-order method needs small dt to keep local mixed-state LTE inside the frozen envelope.

Therefore loosening the score after seeing these results would merely trade away the error target and is not authorized.

## Decision

Do not admit mixed-LTE adaptive backward Euler as AUTO_REFERENCE.

Do not tune the TIMEINT03 score scales post hoc.

Proceed to a higher-order temporal-discretization prototype.
