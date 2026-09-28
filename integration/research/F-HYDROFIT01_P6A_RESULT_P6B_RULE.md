# F-HYDROFIT01 P6A result and P6B workload rule

Authority remained `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`.

## P6A result

Run `36405292045` at `2c8ba3827018e52032e35403b0f7757897b96bc9`: SUCCESS.

The deterministic P5B construction produced 8 function-space representatives from 1446 primary-envelope members. The fit optimum had `J*=0.020424238930579042`.

Frozen probe: uniform initial head -75 cm, bottom head -75 cm, top factor -1, duration 0.01 d, common numerical tolerances.

All 8 representatives:

- converged;
- used 1 nonlinear iteration;
- used 1 Jacobian build;
- used 1 linear solve;
- reported 1 backtracking attempt;
- had zero reported integrated mass residual.

Thus P6A is a valid null result for numerical-effort differentiation.

Hydraulic outcomes were not identical. Reported bottom flux ranged approximately from -1.2143 to -2.0107 in harness units, and initial/final water contents differed. Therefore the representatives are hydraulically distinct even though this probe is numerically too easy to separate them.

## P6B workload-selection rule

A harder probe may be selected without observing representatives 1-7.

Use representative 0 only for workload discovery, following the pre-existing APPROX02 discovery dimensions:

- initial head: -10, -75, -500 cm;
- top factor: -1, 0, -2, 1;
- duration: 1e-4, 1e-3, 1e-2, 5e-2 d;
- bottom head equal to initial head;
- unchanged numerical tolerances.

Selection rule:

1. retain converged representative-0 cases;
2. sort by nonlinear iteration count descending, then backtracking count descending;
3. choose the first case with nonlinear iterations >= 2;
4. if none exists, P6B closes as BLOCKED_NO_MULTI_NEWTON_WORKLOAD;
5. freeze the selected workload before running representatives 1-7;
6. apply that workload unchanged to all 8 representatives.

This preserves independence of the harder workload from the comparison outcomes.

P6A remains part of the evidence and is not superseded by P6B.
