# F-PE-APPROX03 T1 result — prescribed-qbot temporal-budget screen

Date: 2026-09-26

Status: `SCREEN_POSITIVE_NOT_ADVANCED`

Parent:
`F-PE-APPROX03`

## Question

T1 tested whether relaxing only the model-owned temporal head budget removes real serialized Reference transaction work.

The research workload was the certificate-discovery case:

- prescribed qbot: `5e-10 cm/day`;
- requested interval: `0.01 day`;
- exact qualification budget: `2.5e-11 cm`;
- local Richards tolerances unchanged;
- retry scale unchanged;
- constitutive physics unchanged.

## Work frontier

Five timing repetitions were run for each budget.

| Budget | Relative | Accepted substeps | Nonlinear iterations | HeadCalc calls | Median speedup |
| --- | ---: | ---: | ---: | ---: | ---: |
| 2.5e-11 cm | 1x | 20 | 188 | 94 | reference |
| 5.0e-11 cm | 2x | 14 | 118 | 59 | 32.75% |
| 1.0e-10 cm | 4x | 10 | 76 | 38 | 53.80% |
| 2.0e-10 cm | 8x | 7 | 46 | 23 | 67.84% |

No arm introduced retries.

This establishes that temporal acceptance is a material runtime lever. The speedup is accompanied by an actual reduction in accepted substeps and nonlinear work, rather than only a cheaper acceptance check.

## Why T1 does not select a practical mode

The prescribed-qbot screen is not a sufficient hydrological error frontier.

In this fixture:

- the lower boundary exchange is prescribed rather than emergent;
- the reported terminal pressure-head and water-content vectors were identical across the tested budgets;
- storage differences were at roundoff scale;
- bottom-exchange differences were exactly zero.

Those observations are useful as a transaction/work screen, but they do not show that a 2x, 4x or 8x budget is safe under a state-dependent groundwater boundary.

In particular, exact zero endpoint differences in a prescribed-flux fixture must not be generalized to production mode 5.

## Decision

T1 is retained as evidence that the temporal budget controls a large amount of real work.

No T1 budget multiplier advances to production qualification.

The next experiment must use a non-trivial state-dependent prescribed-head transient where temporal coarsening can affect:

- the terminal pressure-head profile;
- water content;
- emergent bottom flux / exchange;
- storage change;
- cumulative exchange.

## Handoff

Proceed to:

`F-PE-APPROX03 T2 — prescribed-head temporal-budget frontier`

T2 must retain the same one-dimensional budget axis and unchanged local Richards tolerances.
