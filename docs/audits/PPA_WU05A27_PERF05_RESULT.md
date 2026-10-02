# PPA-WU05-A27-PERF05 — transaction multiplicity and PERF04 closeout

Date: 2026-10-02
Status: CLOSED_NEGATIVE_CACHE_RESULT

PERF04 tested exact run-trial surface hydraulic memoization and was rejected/reverted because it produced no measurable end-to-end benefit despite exact hydrologic preservation.

The transaction algorithm itself establishes the reuse opportunity without further instrumentation. For each external full/half attempt:
1. `full_state` is cloned from the accepted checkpoint and advanced over the full attempted interval;
2. `half_state` is independently cloned from the same checkpoint and advanced over the first half interval;
3. only half2 starts from the changed half1 candidate.

Therefore full and half1 have the same accepted-state surface h/theta key. PERF03 already established that the default-MvG surface K/S used by RFM is bitwise invariant to the tested trial durations. A valid exact cache opportunity therefore exists once per wet full/half attempt.

The qualified ABC01 C screen contains 602 transaction calls, 610 attempts and 8 retries over its 32 cases. Only wet intervals need surface K/S, but the multiplicity is plainly not sparse enough to explain PERF04 as having no opportunities.

PERF04 full ABC evidence remains exact in all non-timing fields. Its timing ratios are not meaningfully better than PERF02 and fluctuate with CI-machine timing. The cache adds scratch state, exact-key comparisons and API complexity without demonstrated end-to-end benefit.

Conclusion:
- do not retain surface-hydraulic memoization;
- do not spend another work unit instrumenting cache hit counts;
- the counting-provider component timing is not a reliable estimate of its fraction of optimized production runtime;
- subsequent profiling must time the actual production provider/path directly.

Next exact-performance target: quantify fresh-endpoint sorptivity frequency and actual production cost, plus residual non-constitutive RFM preparation overhead, without a counting wrapper. Only retain a repair if the end-to-end ABC timing moves while all non-timing fields remain exact.
