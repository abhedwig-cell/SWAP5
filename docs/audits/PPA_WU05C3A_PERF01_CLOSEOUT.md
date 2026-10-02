# PPA-WU05-C3A-PERF01 closeout

Date: 2026-10-02
Status: CANONICAL_ADMITTED_PERFORMANCE_OPTIMIZATION

PR #979 merged to canonical as `56458070502e38cf0ac0e9b35cfe700814d3772a`.

The only production-physics change is in `mod_bartholomeus_waterfilm_independent.f90`: trapezoid refinement reuses the preceding level and evaluates only new midpoint samples. The MvG integrand, source lower bound, maximum 24 refinement levels, relative 1e-5 convergence rule and waterfilm transformation are unchanged.

Measured 3-node results:
- REFERENCE waterfilm 127447.96 ns -> 64029.996 ns (-49.76%);
- full-stress route 138940 ns -> 77340 ns (1.796x throughput);
- no-stress route 128720 ns -> 67620 ns (1.903x throughput).

Preservation run `36991780104`, job `110789398982`, passed the unchanged corrected B1.11 assembled oracle at O0/O2 and the actual typed production application at O0/O2. Maximum RWU difference remained `2.3760167733755111e-5`, below the frozen `1e-4` threshold. Rerun `36991801352` also passed.

Earlier wrapper and experimental MACRO-root changes showed no material performance gain and were removed from the admitted candidate.

The active-chain harness was isolated from an unrelated current lower-boundary `compare-reals` Werror with a minimal hydraulic-state test contract. No production solver code, oxygen assertion or tolerance was weakened.

PERF01 changes performance only. It does not broaden the bounded C3A oxygen admission envelope.
