# F-PE-PROFILE05R2 result — post-repair practical-stack rebaseline

Date: 2026-09-26

Status: `MEASURED_STACK_POSITIVE_A1_DOMINATED`

## Robustness

All five initial four-arm live SWAP + MODFLOW6 replicas completed for:

- exact;
- A1;
- A2C;
- A1 + A2C.

All 15 repeated B1 cycles also completed for all four arms.

No candidate-only robustness failure occurred.

Across all four-arm measurements:

- coupled iteration count remained 2;
- SWAP exchange matched exact;
- ledger exchange matched exact;
- A1 and A2C heads matched exact;
- stack head differed only by approximately one binary64 ulp (`1.11e-16 m`) in the observed representation.

## Initial five-replica screen

The first five single-shot stack/exact speedups were:

- +4.20%;
- -1.98%;
- +5.95%;
- -2.39%;
- -2.06%.

Summary:

- speed-positive: 2/5;
- median: about -1.98%;
- mean: about +0.74%.

This was correctly classified as unresolved sub-millisecond timing variance and triggered B1.

## B1 repeated four-arm timing

B1 used one fixed build and 15 fresh coupled processes per arm with rotating arm order.

### A1 + A2C stack versus exact

Per-cycle stack speedups:

- +1.61%;
- +4.21%;
- +5.40%;
- +4.42%;
- +5.12%;
- +8.90%;
- +7.57%;
- +3.39%;
- -3.96%;
- -0.64%;
- +2.79%;
- +1.59%;
- +5.87%;
- +2.98%;
- +0.05%.

Summary:

- speed-positive: 13/15;
- median speedup: `3.39%`;
- mean speedup: `3.29%`;
- minimum: `-3.96%`;
- maximum: `+8.90%`.

The preregistered B1 speedup criterion was at least 12/15 positive cycles and positive median speedup.

The stack therefore qualifies as speed-positive on this repaired short live coupled fixture.

### A1 only versus exact

- speed-positive: 15/15;
- median speedup: `5.38%`;
- mean speedup: `4.61%`.

### A2C only versus exact

- speed-positive: 8/15;
- median speedup: `0.57%`;
- mean speedup: `1.80%`.

### Stack incremental value

Stack versus A1:

- stack faster: 5/15;
- median stack-vs-A1 speedup: `-3.00%`.

Stack versus A2C:

- stack faster: 10/15;
- median stack-vs-A2C speedup: `+1.74%`.

## Interpretation

The coupled practical-stack gain is real but modest in this fixture.

It is dominated by A1 tangent reuse.

A2C does not add a measurable incremental benefit on top of A1 in this two-iteration coupled workload. In fact, the stack is median about 3% slower than A1 alone.

That does not invalidate A2C's separately qualified practical envelope. It means this particular coupled workload is too easy for relaxed Richards convergence to create additional solve-effort savings.

No additive or multiplicative combination of historical A1 and A2C percentages is used.

## Supporting application-shaped evidence

Current-postimage A2C application sequence:

- measured speedup: about `27.34%`;
- nonlinear iterations: 60 versus 60;
- accepted substeps: 20 versus 20;
- retries: 0 versus 0;
- maximum mass residual: 0;
- cumulative net-flow difference: 0;
- cumulative storage difference: 0;
- storage-end difference: 0.

Because work counters are unchanged, this single short timing result is retained as supporting observation rather than used as a general solve-effort claim.

## Current runtime decomposition

On the same postimage:

- application N=10000 median: about `7.75 us/column`;
- Reference backend median: about `7.00 us`;
- Reference backend share: about `90.40%`;
- residual application wrapper: about `9.60%`;
- directional backend median: about `12.19 us`;
- directional/reference ratio: about `1.74x`;
- directional increment over reference: about `74.1%`.

Representative direct Reference diagnostics remain:

- one solver call;
- three nonlinear iterations;
- three Jacobian builds;
- three linear solves;
- three HeadCalc calls;
- three backtracking attempts.

## Scientific conclusion

After the ownership repair:

1. the live coupled timing authority is repeatable again;
2. A1 provides a small but consistent live coupled benefit;
3. A2C remains robust but does not improve the already-A1-enabled short two-iteration coupled case;
4. the majority of application runtime remains inside the Reference backend;
5. further performance research should target production-shaped workloads with enough nonlinear difficulty for solve-effort reductions to be observable, rather than optimizing this very short FGC44 loop further.
