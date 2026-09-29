# F-PE-ELASTIC01R — corrected legacy-ELAS bracket refinement

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_REFINEMENT_RESULTS

Parent result: `F-PE-ELASTIC01_PHASE_A_RESULT.md`.

## Scope

Refine the positive ELAS coefficient around Pim Dik's nominated `1e-6` after the initial logarithmic screen was frozen and recorded.

No holdout case may be opened.

## Cases

Only Phase-A screening cases that are physically or numerically informative near saturation:

- B01/WET
- B01/POND
- B12/MOIST
- B12/WET
- O05/WET
- O05/POND

## Frozen refinement coefficients

`2e-7, 5e-7, 7.5e-7, 1e-6, 1.5e-6, 2e-6, 5e-6`.

The existing ELAS-off Reference is rerun for comparison.

## Measurements

Record success, accepted/rejected attempts, nonlinear work index, runoff, ponding, top/mid/bottom head, matrix-plus-pond storage and water ledger.

This refinement is descriptive. It does not impose a new admission threshold and does not select a production coefficient.

## Questions

1. Is the O05/POND nonconvergence around `1e-6` monotone or a bounded instability interval?
2. Does B01/POND show a smooth storage/runoff response with increasing ELAS?
3. Are B12 head changes monotone with ELAS?
4. Is any numerical-work improvement separable from physical storage redistribution?
5. Do the three material archetypes require visibly different coefficient ranges?
