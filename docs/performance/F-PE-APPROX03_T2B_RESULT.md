# F-PE-APPROX03 T2B result — intermediate temporal budget screen

Date: 2026-09-26

Status: `SCREEN_SELECTS_1P25X_ONLY`

Controlling workload:

- B01 wet;
- h0 = -10 cm;
- top and predictor-qbot factors = +5e-5 of local conductivity;
- requested interval = 1e-4 day;
- exact budget = 1e-5 cm;
- nine replicas per budget point.

## Result

| Multiplier | Commit replicas | Substeps | Nonlinear | HeadCalc | Median speedup | Bottom-flux error | Storage-change error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1.00x | 9/9 | 3 | 21 | 6 | reference | 0 | 0 |
| 1.25x | 9/9 | 2 | 12 | 4 | ~16.09% | ~10.45% | ~1.35% |
| 1.50x | 0/9 | candidate failure | | | | | |
| 1.75x | 0/9 | candidate failure | | | | | |
| 2.00x | 0/9 | candidate failure | | | | | |

For 1.25x:

- maximum relative pressure-head deviation: approximately `1.87e-7`;
- maximum relative water-content deviation: approximately `8.61e-9`;
- canonical mass residual: zero in the reported run;
- no retries.

## Interpretation

The temporal-budget robustness boundary is discontinuous in this controlling case.

A 25% relaxation remains transactionally robust and removes one accepted substep. A 50% relaxation and every larger tested point fail reproducibly.

The state variables remain very close at 1.25x, but the emergent terminal bottom flux is substantially more sensitive than pressure head or water content. A ~10.45% terminal flux difference is too large to treat as already qualified.

## Decision

Only 1.25x survives the controlling screen.

It does not advance directly to coupled or production qualification.

It must first pass a broader material/regime matrix specifically to determine whether the approximately 10% controlling-case flux deviation is exceptional or representative.

If the broader matrix shows larger or systematic exchange bias, temporal-budget relaxation is rejected as a production practical mode and APPROX03 should close without admission.
