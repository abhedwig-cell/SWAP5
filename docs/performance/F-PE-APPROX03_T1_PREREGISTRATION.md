# F-PE-APPROX03 T1 preregistration — relaxed model-certificate head budget

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Parent:
`F-PE-APPROX03`

## Evidence for the target

Production model-certificate discovery identified a converged temporal-refinement workload:

- prescribed qbot: `5e-10 cm/day`;
- requested interval: `0.01 day`;
- exact qualification head budget: `2.5e-11 cm`;
- accepted substeps: `20`;
- retries: `0`;
- nonlinear iterations: `188`;
- HeadCalc calls: `94`;
- terminal normalized certificate: approximately `0.745`;
- mass residual: machine precision.

This is genuine production temporal work. It is not the rejected external-full-half route.

## Candidate axis

T1 varies only the model-owned temporal head budget.

Research arms:

- `1x`: `2.5e-11 cm` exact reference;
- `2x`: `5.0e-11 cm`;
- `4x`: `1.0e-10 cm`;
- `8x`: `2.0e-10 cm`.

All other settings remain identical.

In particular:

- local Richards tolerances remain fixed;
- retry scale remains `0.5`;
- transaction mass tolerance remains exact;
- constitutive physics remain unchanged;
- forcing and initial state are identical.

## Required evidence

For each arm measure:

- accepted substeps;
- retries;
- nonlinear iterations;
- HeadCalc calls;
- runtime;
- final pressure head;
- final water content;
- bottom exchange over the interval;
- storage change;
- canonical mass residual.

Report deviations against the `1x` exact-budget trajectory.

## Advancement rule

A T1 arm advances only if:

1. it materially reduces accepted substeps / solve work;
2. runtime is reproducibly lower;
3. final state and interval exchange errors are bounded;
4. canonical mass accounting remains within the unchanged hard gate;
5. no new retry/failure pathology appears.

## Rejection rule

Reject an arm if the larger budget mainly shifts work into failed attempts/retries or causes material state/exchange bias.

## Production status

T1 is research-only.

No production temporal budget or default behavior is changed by this preregistration.
