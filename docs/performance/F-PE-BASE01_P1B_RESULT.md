# F-PE-BASE01 P1B result — non-HeadCalc backend decomposition

Date: 2026-09-27

Status: `PASS_TEMPORAL_INDICATOR_SELECTED_FOR_P2`

PR:
`#660 — F-PE-BASE01: base q/state Richards solve decomposition`

Current-head authority:
- branch head exercised: `c5f1881d3d95695993ab6420e232adb32c9df60b`;
- workflow run: `36306634228`;
- job: `p1b-outer-backend`;
- frozen q-only LIVE01 head population.

## Preservation

The instrumented replay preserves the frozen discrete trajectory:

- transaction calls: 52;
- accepted substeps: 52;
- attempts: 72;
- retries: 20;
- temporal rejections: 20;
- solver rejections: 0;
- nonlinear iterations: 236;
- backtracking attempts: 236.

No production source is modified.

## Aggregate backend decomposition

Across the 12 group medians:

- serialized backend: `831,307 ns`;
- kernel core: `803,041 ns`, `96.60%`;
- canonical interval: `724,302 ns`, `87.13%`;
- transaction execution: `687,553 ns`, `82.71%`;
- model advance: `617,837 ns`, `74.32%`;
- HeadCalc: `329,968 ns`, `39.69%`;
- temporal-indicator / temporal-certificate evaluation: `184,224 ns`, `22.16%`.

Smaller measured families:

- transaction clone: `2.66%`;
- transaction context capture/restore: `1.01%`;
- canonical preparation: `2.65%`;
- kernel state clone: `0.84%`;
- kernel postprocessing: `0.41%`.

Residual nested families are:

- model-other: `12.47%`;
- transaction-other: `4.71%`;
- canonical-other: `1.77%`;
- kernel-other: `8.22%`.

Nested percentages must not be summed as disjoint costs.

## Gate disposition

The preregistered P2 selection threshold is:

- >=20% aggregate backend time, or
- >=15% broadly across difficult groups,

plus a concrete exact-preserving reduction mechanism.

The temporal-indicator family satisfies the measured-cost gate:

`TEMPORAL_SHARE = 22.1608%`.

It also has a concrete exact-preserving candidate. The current Reference temporal indicator performs two full constitutive evaluations although its operator uses:

- base-state conductivity;
- candidate-state capacity;
- candidate water content only for consistency validation.

The unused outputs can be avoided with demand-specialized provider calls while preserving the same constitutive functions and the same temporal-defect mathematics.

## Decision

Advance exactly one candidate to P2:

`TEMPORAL_INDICATOR_DEMAND_SPECIALIZATION`.

Do not advance generic HeadCalc, constitutive, linear solve, Jacobian, transaction clone, context, or state-copy work in BASE01.

P2 must prove semantic identity and composed runtime benefit before any production handoff.
