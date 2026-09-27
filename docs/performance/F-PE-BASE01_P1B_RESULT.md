# F-PE-BASE01 P1B result — non-HeadCalc backend decomposition

Date: 2026-09-27

Status: `PASS_TEMPORAL_INDICATOR_SELECTED_FOR_P2`

PR:
`#660 — F-PE-BASE01: base q/state Richards solve decomposition`

Authority:
- branch head exercised: `957ee92eddc0be24303ed922d7d74dce5b8f4a01`;
- workflow run: `36306105717`;
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

- serialized backend: `503,943 ns`;
- kernel core: `491,901 ns`, 97.61%;
- canonical interval: `447,680 ns`, 88.84%;
- transaction execution: `426,200 ns`, 84.57%;
- model advance: `380,872 ns`, 75.58%;
- HeadCalc: `210,717 ns`, 41.81%;
- temporal-indicator / temporal-certificate evaluation: `112,698 ns`, 22.36%.

Smaller measured families:

- transaction clone: 2.69%;
- transaction context capture/restore: 1.37%;
- canonical preparation: 2.46%;
- kernel state clone: 0.67%;
- kernel postprocessing: 0.47%.

Residual nested families are:

- model-other: 11.40%;
- transaction-other: 4.94%;
- canonical-other: 1.80%;
- kernel-other: 7.63%.

Nested percentages must not be summed as disjoint costs.

## Group behavior

Temporal-indicator share is broadly material:

- about 19.4% to 20.6% in the low-cost mid/B12 groups;
- about 22.3% to 24.2% in the wet difficult groups.

Thus it is not one isolated outlier.

## Gate disposition

The preregistered P2 selection threshold is:

- >=20% aggregate backend time, or
- >=15% broadly across difficult groups,

plus a concrete exact-preserving reduction mechanism.

The temporal-indicator family satisfies the measured-cost gate:

`TEMPORAL_SHARE = 22.3632%`.

It also has a concrete exact-preserving candidate. The current Reference temporal indicator performs two full constitutive evaluations although its operator uses:

- base-state conductivity;
- candidate-state capacity;
- candidate water content only for consistency validation.

The unused outputs can be avoided with demand-specialized provider calls while preserving the same constitutive functions and the same temporal-defect mathematics.

## Decision

Advance exactly one candidate to P2:

`TEMPORAL_INDICATOR_DEMAND_SPECIALIZATION`.

Do not advance generic HeadCalc, constitutive, linear solve, Jacobian, transaction clone, context, or state-copy work in BASE01.

P2 must prove that demand specialization preserves the temporal indicator and accepted/retry trajectory before any performance claim is admitted.
