# PPA-WU05-A27-PERF03 preregistration — surface-sorptivity reuse falsification

Date: 2026-10-02
Status: PREREGISTERED_BEFORE_EXECUTION
Parent: `98226a2f5d64060666812e8448ed0a30f229fc81`

PERF02 leaves exactly one 64-panel surface-sorptivity integral in cached wet RFM live preparation.

Do not cache it merely because the accepted physical state is unchanged. The default MvG provider is rebound for each trial duration and may expose timestep-dependent solver conductivity/capacity. PERF03 therefore tests the cache-key hypothesis first.

For B01 and O05, use fixed hydrostatic accepted states at water tables -300, -150, -100 and -20 cm. At node 1 evaluate the actual 64-panel RFM node sorptivity with the actual default MvG provider rebound independently at durations:
0.01, 0.005, 0.0025, 0.00125 and 0.000625 day.

Also evaluate conductivity at the same accepted node/state for each duration.

Gate:
- persist all values;
- classify exact duration invariance only if all sorptivity values are bitwise/equality identical;
- otherwise report max absolute/relative variation and reject duration-independent caching;
- no tolerance-based cache equivalence is allowed in PERF03.

Then measure transaction multiplicity for the existing production-C ABC01 cases from diagnostics: attempts/retries and full/half policy imply how often the same accepted state can be revisited at distinct durations. Do not implement caching in this work unit.

If duration-independent caching is falsified, the next exact-preserving options are restricted to duration-keyed memoization or algebraic reuse inside one fixed-duration preparation. Approximate cross-duration reuse requires a separate work unit.
