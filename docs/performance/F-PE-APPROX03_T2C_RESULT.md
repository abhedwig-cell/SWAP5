# F-PE-APPROX03 T2C result — 1.25x cross-material qualification

Date: 2026-09-26

Status: `REJECTED_INSUFFICIENT_GENERAL_BENEFIT`

Candidate:

- model temporal-indicator budget: `1.25e-5 cm`;
- exact reference: `1.00e-5 cm`;
- no other numerical control changed;
- A2C OFF.

## Reference-domain calibration

The preregistered reference-only calibration covered 24 combinations:

- B01, B12, O05, O14;
- wet, mid, dry;
- plus and minus forcing orientation.

For each case, the largest interval in the fixed discovery grid was selected only when the exact reference:

- committed;
- had complete mass accounting;
- had zero retries;
- used at least two accepted substeps.

Result:

- 5 of 24 cases contained a usable multi-substep temporal workload;
- 19 of 24 were classified `NO_TEMPORAL_WORKLOAD_IN_GRID`.

Selected workloads:

- B01 wet plus: `2e-4 day`;
- B01 wet minus: `1e-3 day`;
- O05 wet minus: `2e-4 day`;
- O14 mid plus: `1e-3 day`;
- O14 mid minus: `1e-3 day`.

This already shows that temporal refinement under the exact production certificate is sparse in the tested material/regime space.

## Paired 1.25x result

All five selected reference-stable cases also committed under 1.25x.

There were no candidate-only transaction failures and mass residuals remained at roundoff scale.

However, the practical benefit was sparse:

- only 1 of 5 cases reduced accepted substeps or nonlinear work;
- only 1 of 5 cases was measurably speed-positive;
- 3 of 5 cases were speed-negative;
- median speedup was approximately `-0.85%`;
- minimum observed speedup was approximately `-4.0%`.

The one materially positive case was B01 wet minus:

- accepted substeps: 7 -> 6;
- nonlinear iterations: 82 -> 63;
- HeadCalc calls: 28 -> 21;
- measured speedup: approximately `16.67%`;
- maximum relative pressure-head deviation: approximately `1.84e-8`;
- maximum relative water-content deviation: approximately `8.44e-10`;
- terminal bottom-flux deviation: approximately `0.196%`;
- storage-change deviation: approximately `0.252%`;
- interval bottom-exchange absolute difference: approximately `1.19e-9 cm`.

The other four eligible cases showed no physical difference because the accepted temporal trajectory did not change. In three of them the timing was slightly worse.

## Interpretation

The earlier controlling T2B screen demonstrated that a 1.25x budget can produce a large local benefit on a carefully selected workload.

The calibrated cross-material result shows that this is not a broad production-shaped opportunity:

- exact temporal refinement is absent in most tested material/regime cases;
- where temporal work exists, 1.25x usually does not alter the accepted trajectory;
- the resulting runtime benefit is therefore too sparse and inconsistent to justify a new production approximation mode.

This is a different rejection mechanism from T2A.

T2A at 2x was rejected because it lost transaction robustness.

T2C at 1.25x is transactionally robust on the calibrated reference domain, but fails the material-benefit criterion.

## Decision

T2C is rejected as a production practical mode.

No application-shaped or coupled qualification is warranted because the prerequisite broad material/regime benefit is absent.

The exact temporal budget remains authority.
