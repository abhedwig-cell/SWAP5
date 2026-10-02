# A27 moving-wall cohort diagnostic

Status: PROPOSED_RESEARCH_ONLY. Date: 2026-10-02 UTC.
Baseline: f3fb5d375407e4182f8deac144e3d7c86a63bc2f. Canonical remains 828df126e0c0d70f5cbfae51614bfc3b53e832a4.
The preceding 280-column set completed. Retain its records separately.

A single stored first-contact clock/S cannot distinguish an entirely old wetted wall from a wall with both old and newly wetted parts. Introduce a research-only exact interval list per matrix contact: vertical lower/upper depth, wet exposure age, event seed S. Currently wetted intervals are clipped by the accepted hydrostatic receiver level. Retain age/S on still-wet intersections; seed only newly wet intervals at age zero from accepted node hydraulics. Drop history on drying under this explicit dry-reset hypothesis. Advance every participating interval age only on successful acceptance. Rejected evaluations receive immutable accepted history and publish nothing.

Integrate max(Philip,Darcy) separately over each interval using its own age/S. Sum within a node, bound only excess over the summed Darcy integral by the accepted node capillary deficit, then apply the existing node/receiver budgets. Saturated signed Darcy and unfilled-contact seepage remain the same diagnostic operator. All interval partitions are disjoint and sum to the wetted length; no fitted age averaging or arbitrary smoothing is introduced.

This closes the specified moving-wetted-area representation, not the full wall PDE or matrix-moisture feedback. Event S remains frozen within a cohort. The drying reset and capillary deficit closure are proposed assumptions, not new admitted physical authority.

Process oracles: analytically distinct old/new interval uptake; clipping/drying/rewetting; non-overlap, complete coverage, immutable trial/replay, restart via explicit arrays, invalid geometry/NaN, O0/O2. Retain scalar-history falsifiers as successful negative tests.

Column extension: mode 7 is finite contact with interval cohorts and the same capillary budget. Repeat 2 Ks x 4 states x 8 modes x 5 dt = 320 cases. Record maximum live cohort count and nominal packed payload bytes (four real64 fields per cohort), as well as existing matrix/receiver trajectories and solver counters. This is actual per-column state-size evidence, not a 100,000-column scaling extrapolation.

State-size falsifier: if changing level creates an ever-growing list dependent on accepted timestep count, reject the exact uncompressed list as a bounded-state reduced production replacement. Exact microscopic history reproduction is not automatically a useful fast model. Do not hide growth by unqualified merging.

No production source, restart layout, source ABI, dispatch or admission change. Full A27 paired production benchmarks and ensemble scaling remain open.
