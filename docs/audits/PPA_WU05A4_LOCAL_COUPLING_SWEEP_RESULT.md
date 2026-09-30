# PPA-WU05-A4 local coupling-strength sweep

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / ADVERSARIAL_REGIMES_IDENTIFIED`

## Purpose

Use the reduced R2 fixed-point model as the high-throughput laboratory layer before spending GitHub Actions capacity on real Richards confirmations.

## Matrix

4,800 combinations over:

- matrix theta: 0.05 to 0.40;
- event age: 0 to 2 d;
- step duration: 1e-4 to 0.1 d;
- sorptivity scale: 0.1 to 2.0;
- available macropore water: 0.005 to 2.0 cm.

For each case, 12 fixed-point iterations were used as the local converged reference.

## Results

Maximum relative exchange change after the first corrector:

`13.21%`.

99th percentile:

`3.73%`.

95th percentile:

`1.40%`.

Only 20 of 4,800 cases exceeded 5% first-corrector change.

Only 2 of 4,800 exceeded 10%.

Maximum error relative to the converged local fixed point:

- one exchange estimate / first corrector basis: `13.10%`;
- after two exchange estimates: `1.845%`;
- after three exchange estimates: `0.257%`.

No local case retained more than 1% error after the third exchange estimate.

## Adversarial pattern

The strongest coupling occurs for the combination:

- wet matrix, around theta = 0.40;
- fresh sorptivity event;
- long step, dt = 0.1 d;
- high sorptivity scale, 2.0;
- enough macropore water that storage does not cap exchange.

This pattern is physically sensible: exchange feedback is strongest when the initial sorptivity demand is high enough to noticeably wet the matrix within the same step.

## Implication

The earlier real-Richards fresh case with 3.11% first-corrector feedback was not the worst possible reduced regime.

Therefore:

- one corrector should remain a practical research candidate only;
- two correctors are likely adequate for many regimes but are not yet a strict reference;
- three correctors look promising as a bounded practical/reference compromise;
- strict policy should be based on observed exchange convergence, not a fixed iteration count alone.

## Next step

Confirm a small adversarial real-Richards matrix rather than a broad CI sweep.

Recommended real-Richards probes:

1. wet/fresh, approximately theta 0.40, long step;
2. moderately wet/fresh;
3. dry/fresh;
4. wet/aged.

Use high sorptivity in the research exchange model to challenge the outer fixed-point coupling.

The purpose is to test convergence shape and mass closure, not parameter realism.
