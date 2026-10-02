# PPA-WU05-A27-PERF02 preregistration — exact-preserving RFM preparation zero-waste

Date: 2026-10-02
Status: PREREGISTERED_BEFORE_IMPLEMENTATION
Parent: `e394e2a9c4be22c10b72764a1b5600ebcf5a70e7`

PROFILE01 run `36995016536` measured 65 constitutive-demand calls per 64-panel sorptivity integral, 130 for FULL_WET_CACHED and 130 for FULL_DRY_CACHED.

Two production-unused calculations are authorized for removal:
1. MB wall K/S in live preparation, because A26 leading MB is fast-through and the production candidate composer does not consume those wall-binding MB values.
2. Surface K/S when net surface supply is exactly zero, because zero-source activation returns AVAILABLE with zero matrix/preferential rates independently of K/S and DEP03 admits zero supply.

Positive-supply activation, endpoint hydraulics/release, panel count, RFM parameters, source ownership, transaction policy and standard macropore B must not change.

Qualification:
- A26 live and backend preservation PASS;
- A8 standard-macropore preservation PASS;
- PROFILE01 FULL_WET_CACHED demand count 65 and FULL_DRY_CACHED 0;
- exact qualified ABC01 rerun: B >=29/32, C >=30/32, all joint cases E1;
- non-timing hydrologic/counter evidence must match qualified run 36991992438 except counters directly representing removed unused constitutive work;
- repeat timing and report, with no minimum speedup gate.

Branch-local only; no canonical admission claim.
