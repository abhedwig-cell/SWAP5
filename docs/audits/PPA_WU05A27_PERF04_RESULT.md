# PPA-WU05-A27-PERF04 result — run-trial surface hydraulic memo

Date: 2026-10-02
Status: REJECTED_NO_MEASURABLE_PERFORMANCE_BENEFIT
Production disposition: REVERT

PERF03 established exact duration invariance for the tested default-MvG surface hydraulic values. PERF04 therefore tested a run-trial-scoped exact-key memo keyed by surface pressure head, surface water content and panel count.

Smaller qualification:
- run 37002821065: A26 live preservation PASS, backend preservation PASS, A8 preservation PASS, memo semantics PASS;
- first cached-wet preparation requires 65 demand calls;
- identical h/theta at a different trial duration reuses the memo with 0 demand calls;
- a 1e-12 cm surface-head change forces a 65-call miss;
- reset forces a 65-call miss.

Full ABC01:
- run 37003019860: SUCCESS;
- artifact 11224338512, sha256:5abfe3b0448eb880a871341e08311370787ac17a69eddb331e2d63596ee644ee;
- B 29/32, C 30/32, 29 joint E1;
- all 96 sorted raw records are exactly equal to PERF02 in every non-wall-time field.

Performance, however, does not improve materially. PERF04 repeated medians are:
- case1 B 0.002665 s, C 0.002901 s, C/B 1.089;
- case2 B 0.002978 s, C 0.009654 s, C/B 3.242;
- case3 B 0.002713 s, C 0.003812 s, C/B 1.405;
- case4 B 0.002584 s, C 0.005539 s, C/B 2.143.

These ratios are not meaningfully better than PERF02 and absolute cross-run differences are within/against CI machine variation. The memo adds backend scratch state, exact-key comparisons and API surface without demonstrated end-to-end benefit.

Decision: do not retain PERF04 in production code. Revert to qualified PERF02 production implementation and keep PERF04 only as negative performance evidence.

The next exact-performance question is transaction multiplicity: count how often production C actually revisits the identical surface key during full/half/retry. If hit opportunities are sparse, further caching work should stop.
