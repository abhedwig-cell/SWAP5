# PPA-WU05-C3A-PERF01 result

Date: 2026-10-02
State: QUALIFIED_EXACT_PRESERVING_PERFORMANCE_CANDIDATE
Candidate production change: 71233fe41346896075e21ed3ff38b6a45b2f0b9e
Preservation postimage: 279cd1abcf43dee04828d8df1bda9301c315319f

## Finding

Profiling separated the admitted 3-node C3A factor-provider route into:
- REFERENCE waterfilm: 127447.96 ns/evaluation baseline;
- response assembly: 371.84 ns;
- profile oxygen solve: 10782.09 ns.

REFERENCE waterfilm therefore owned about 92% of measured runtime. The baseline recomputed every trapezoid level from scratch.

PERF01 changes only the numerical work schedule of the same trapezoid refinement: the previous trapezoid estimate is reused and only newly introduced midpoint integrand values are evaluated. The lower bound, maximum 24 levels, integrand, physical transformation and relative 1e-5 convergence criterion are unchanged.

## Performance

After the change:
- waterfilm median: 64029.996 ns, 49.76% lower than 127447.960 ns;
- full-stress low-ctop factor route: 77340 ns versus 138940 ns, 44.34% lower, 1.796x throughput;
- no-stress mid-ctop route: 67620 ns versus 128720 ns, 47.47% lower, 1.903x throughput.

Assembly and profile timings were unchanged within measurement noise.

The earlier wrapper and experimental fixed-work MACRO-root changes produced no material speedup and are not part of the candidate.

## Preservation

Run 36991780104, job 110789398982:
- complete unchanged corrected B1.11 assembled oracle: PASS at O0 and O2;
- maximum RWU difference: 2.3760167733755111e-5, unchanged and below 1e-4;
- actual typed production application: PASS at O0 and O2;
- application qualification marker: PASS.

The first preservation attempt was blocked by an unrelated lower-boundary compare-real Werror in the historical active-chain compile closure. The harness was isolated with the minimal hydraulic state contract required by that test; no warning, assertion, oxygen tolerance or production physics was weakened.

## Conclusion

The admitted C3A architecture was already clean, but its REFERENCE waterfilm implementation contained substantial exact-preserving computational waste. Reusing trapezoid levels removes that waste and nearly halves factor-provider runtime for the measured 3-node cases while retaining the B1.11 physical oracle and actual application gates.

This document does not by itself admit the performance candidate to canonical.
