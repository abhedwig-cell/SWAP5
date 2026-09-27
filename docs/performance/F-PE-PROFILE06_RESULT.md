# F-PE-PROFILE06 result — difficult Richards practical-stack characterization

Date: 2026-09-26

Status: `MEASURED_DIFFICULT_STACK_COMPLEMENTARY`

## P1 — difficult direct Richards matrix

Twelve B01/B12/O05/O14 wet/mid/dry cases were run as 20-step exact versus A2C sequences with five timing repetitions per case.

The selected difficult set was frozen from exact nonlinear work using the preregistered rule:

- exact nonlinear work at least 2x the easy-floor count;
- at least 20% A2C nonlinear reduction.

Selected:

- B01 wet: 250 -> 174 nonlinear iterations, median runtime speedup 31.03%;
- B01 mid: 117 -> 78, median speedup 48.34%;
- B12 wet: 116 -> 77, median speedup 29.73%;
- O05 wet: 236 -> 165, median speedup 29.41%;
- O14 wet: 180 -> 126, median speedup 28.67%;
- O14 mid: 140 -> 100, median speedup 24.46%.

The selected cases therefore show genuine solve-effort reduction, not only timing fluctuation.

Across these difficult cases A2C reduces nonlinear/backtracking work by approximately 28-34%.

Hydrological deviations remain extremely small and inside the already-qualified A2C envelope.

## P1 wider matrix

The wider 12-case matrix also shows that runtime gain is not equivalent to nonlinear-count reduction in every easy case.

Examples:

- B12 mid: 60 -> 60 nonlinear, yet median timing +12.0%;
- O05 dry: 40 -> 40, yet median timing +15.6%.

Those short cases are retained as timing observations only and were not selected for P2.

## P2 — real participant directional stack

P2 used the real FGC44 prescribed-head transaction participant with accepted-direction response tangents requested.

For each frozen difficult case, five timing repetitions were performed with 4000 same-origin corrector trials per arm.

Arms:

- exact;
- A1;
- A2C;
- A1 + A2C.

A1 cache accounting was stable:

- median fresh tangents: 445 / 4000;
- median reused tangents: 3555 / 4000.

No candidate-only failure occurred.

A1 physical exchange checksums matched exact to roundoff.

A2C exchange checksums matched exact in the observed runs; tangent differences were at most sub-1e-9 relative scale in the reported P2 cases.

## P2 case results

### B01 mid

- A1: +21.33%;
- A2C: +6.26%;
- stack: +27.46%;
- stack versus A1: +7.79%;
- stack versus A2C: +22.62%.

### B01 wet

- A1: +21.34%;
- A2C: +5.58%;
- stack: +26.77%;
- stack versus A1: +6.90%;
- stack versus A2C: +22.44%.

### B12 wet

- A1: +18.86%;
- A2C: -0.65%;
- stack: +21.55%;
- stack versus A1: +3.31%;
- stack versus A2C: +22.05%.

### O05 wet

- A1: +21.31%;
- A2C: +5.12%;
- stack: +26.72%;
- stack versus A1: +6.87%;
- stack versus A2C: +22.76%.

### O14 mid

- A1: +21.11%;
- A2C: +4.92%;
- stack: +26.99%;
- stack versus A1: +7.45%;
- stack versus A2C: +23.22%.

### O14 wet

- A1: +21.15%;
- A2C: -1.29%;
- stack: +20.59%;
- stack versus A1: -0.71%;
- stack versus A2C: +21.60%.

## Aggregate directional result

Across the six selected cases:

- stack median speedup versus exact: about 26.74%;
- stack mean speedup: about 25.01%;
- A1 median speedup: about 21.23%;
- A2C median speedup: about 5.02%;
- stack median incremental speedup versus A1: about 6.89%;
- stack median incremental speedup versus A2C: about 22.53%.

The preregistered complementarity rule required stack to beat both A1 and A2C in at least four of six cases.

Result:

- complementary cases: 5/6.

Therefore A1 and A2C are measurably complementary on difficult accepted-direction workloads, even though A1 remains the larger contributor.

## Interpretation

Two performance regimes are now distinct.

### Easy short coupled loop

PROFILE05R2:

- A1 dominates;
- A2C adds no resolved incremental benefit;
- combined stack median speedup is only a few percent because the physical solve is already trivial and timing noise is large.

### Difficult Richards / accepted-direction route

PROFILE06:

- A2C removes genuine nonlinear work;
- A1 removes most repeated tangent work;
- combined stack gives roughly 20-27% direct participant speedup across all six difficult cases;
- the two modes are complementary in 5/6 cases.

This is the regime in which the retained practical stack is scientifically and computationally meaningful.

## Remaining hotspot

A1 reuses the response tangent, but every same-origin corrector trial still performs the physical Reference Richards solve needed to obtain the trial exchange/candidate state.

After A1:

- 3555/4000 tangent requests are reused in the representative P2 measurements;
- yet stack cost remains roughly 7.7-8.3 us/trial in the selected cases.

The remaining dominant work is therefore the repeated physical Reference solve on same-origin corrector trials, not tangent recomputation.

A2C reduces that physical cost modestly in this one-step participant fixture and substantially in difficult multistep sequences, but it does not remove the repeated solve itself.

This is the next factual performance target.
