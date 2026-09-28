# F-PE-BOFEK00F adaptive wet interval-ladder preregistration

Date: 2026-09-28

Status: PREREGISTERED BEFORE LADDER EXECUTION

Parent correction head: `work/f-pe-bofek00-correction-candidate@67c8cc1653587e8b528fa907bb5af68e87233985`.

Canonical authority at preregistration: `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`.

## Purpose

Characterize the unchanged current adaptive full/half timestep policy after BOFEK00E established roundoff-level old/corrected identity for a frozen 10 s timestep sequence.

The ladder is a characterization surface, not a timestep-policy tuning exercise.

## Frozen policy

Both old and corrected sources use exactly:

- temporal mode: `TX_TEMPORAL_EXTERNAL_FULL_HALF`;
- temporal tolerance: `1e-6`;
- retry scale: `0.5`;
- max retries: `8`;
- max committed substeps: `256`;
- solver max iterations: `32`;
- solver max backtracking: `12`;
- solver tolerances: `1e-10`;
- no model temporal indicator budget;
- no DTMIN/DTMAX or growth/decrease-factor mutation.

## Frozen wet physical fixture

- B01/D21 hydraulic parameters already used by BOFEK00C-E;
- initial top head `-3.5900902059398048 cm`;
- rainfall `4 * Ksat`;
- ponding maximum `Ksat * 10 s`;
- runoff resistance `0.001 day`;
- runoff exponent `1`;
- zero ET, irrigation, snowmelt and runon;
- zero prescribed lower flux;
- no roots, drainage, macropores, frost or soil temperature.

## Frozen interval ladder

The requested outer interval duration is frozen before execution at:

`[10, 20, 40, 80, 160, 320] seconds`.

Rationale: powers of two from the previously qualified 10 s wet scale. This ladder locates the acceptance boundary without choosing a duration after observing corrected behavior.

For every interval, old and corrected use the same initial state, forcing and policy.

## Measurements

For each source and interval retain at least:

- completed / committed;
- kernel status;
- accepted substeps;
- nonlinear iterations;
- internal retries;
- HeadCalc calls;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- mass completeness and residual;
- total input and output;
- runtime as descriptive only.

## Interpretation

- If corrected accepts an interval that old rejects under identical policy, that is evidence of correctness-policy interaction.
- If both accept, compare work and mass/runoff outputs without claiming policy improvement.
- If both reject across the same boundary, the current correction candidate has not reproduced the historical convergence benefit on this fixture.
- No ladder result authorizes policy retuning inside BOFEK00.
