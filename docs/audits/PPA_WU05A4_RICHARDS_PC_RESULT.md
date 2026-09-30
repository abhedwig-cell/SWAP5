# PPA-WU05-A4 dynamic Richards predictor/corrector result

Date: 2026-09-30

Status: `QUALIFIED_RESEARCH_PROBE / DYNAMIC_PREDICTOR_CORRECTOR_PASS`

Workflow run: `36765169021`

Head: `d366ad26035fbe3f566092af35d7c86d3a7eef41`

## Purpose

Replace the previously fixed internal exchange with a source-shaped macropore exchange computed from a real Richards predictor state and accepted macropore history.

## Sequence

For one physical step:

1. Richards predictor solve with zero macropore exchange;
2. compute sorptivity exchange from predictor matrix water content and accepted macropore history;
3. freeze that exchange vector;
4. Richards corrector solve;
5. update the paired macropore candidate with the same exchanged amount;
6. reconcile matrix + macropore mass;
7. optionally recompute exchange from the first corrector matrix state to characterize coupling strength.

No production macropore path or solver ABI was changed.

## Result

Both O0 and O2 passed.

Fresh-event case:

- predictor-derived exchange rate: `8.3813780726 cm d-1`;
- exchange recomputed after one Richards corrector: `8.1203910703 cm d-1`;
- relative exchange change: `3.1139%`;
- first-corrector matrix storage gain: `8.2381e-3 cm`.

Aged-event case:

- predictor-derived exchange rate: `0.2064276696 cm d-1`;
- recomputed rate after one corrector: `0.2063013032 cm d-1`;
- relative exchange change: `0.06122%`;
- first-corrector matrix storage gain: `6.3633e-5 cm`.

The A3 sorptivity-memory ordering is preserved by the real Richards coupling.

## Interpretation

The coupling is weak for the aged-event case but materially stronger at the start of a fresh sorptivity event.

A single frozen-exchange corrector is therefore not yet accepted as the strict R2 reference coupling rule.

Current interpretation:

- **practical candidate**: one corrector may ultimately be sufficient in many regimes;
- **strict research reference**: characterize fixed-point convergence first;
- no evidence currently requires a fully implicit exchange inside the Newton iteration.

## Next step

Run a bounded Picard-style characterization over several correctors:

`Richards state -> exchange -> Richards corrector -> updated exchange`

using the same accepted macropore history for the physical step.

Measure:

- exchange sequence;
- relative exchange change per iteration;
- matrix-state change;
- combined mass closure;
- fresh versus aged convergence rate.

Do not define a convergence tolerance until the sequence is observed.
