# PPA-WU05-C3A E2E03 dynamic trajectory closeout

Status: NEGATIVE CHARACTERIZATION, CLOSED

Purpose: determine whether the accepted production-application fixture could provide a dynamic, physically evolving workload for estimating PERF02 gate-hit frequency.

Evidence:
- run 37113152672 / job 111174803400: 80/80 sequential production-application intervals accepted and committed with one persistent application instance.
- run 37117639617 / job 111187427111: direct serialized backend + kernel committed-state snapshots successfully classified PERF02 after every real commit.
- at DT=1e-5 day the state evolution was negligible: top-node head approximately -300.000 to -300.021 cm over 80 steps; PERF02 skip remained false throughout.
- hydrologically larger DT=0.1 day rejected at the first interval.
- DT=1e-3 day also rejected at the first interval.
- run 37120230129 / job 111194748003 classified the latter rejection as kernel status 2 before a completed candidate, with mass residual 0.0. This is not a water-balance failure.

Conclusion:
The short accepted application fixture is valid for application preservation and micro/E2E runtime measurement, but is not a valid basis for production-like PERF02 hit-frequency estimation over hydrologic time. Do not weaken numerical tolerances or redesign the fixture to manufacture a long trajectory. Reuse the read-only committed-state gate classification on an existing longer accepted SWAP5 workload instead.

No production code or admitted PERF02 behavior is changed by E2E03.
