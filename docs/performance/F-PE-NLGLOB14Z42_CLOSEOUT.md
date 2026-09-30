# F-PE-NLGLOB14Z42 closeout — larger-profile production-shaped trajectory timing

Date: 2026-09-30

Final status:

`QUALIFIED_Z42_TRAJECTORY_TIMING_GAIN`

Qualification authority:

- workflow run `36774835520`;
- job `110090024530`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z42 closes positively.

On the frozen N=64 / O05 4,000-interval trajectory:

- full/adaptive physical differences remain effectively zero;
- per-interval mass ledgers remain around 7.4e-17 cm;
- reduced route is used on 100% of intervals;
- fallback count is zero;
- bypass count is zero;
- active dimension remains n=49;
- deterministic work ratio is 0.765625;
- trajectory wall-clock ratio is 0.92666.

Thus the adaptive manager reduces deterministic work by about 23.4% and measured trajectory wall-clock by about 7.3%.

## Strategic conclusion

The line has now demonstrated a real compiled trajectory-level timing gain behind the production-shaped manager seam.

The remaining work is no longer mechanism discovery or architecture design.

The next phase should prepare a production-admission candidate with compact heterogeneous trajectory holdouts and explicit non-default configuration.

## Direct successor

Open:

`F-PE-NLGLOB14Z43 — moving-interface manager production-admission candidate preparation`.

Z43 should:

1. freeze a compact heterogeneous trajectory holdout set;
2. confirm transaction/mass safety;
3. confirm explicit fallback/bypass semantics;
4. confirm no material performance regression across the holdouts;
5. package the adaptive manager behind an explicit non-default production configuration;
6. prepare canonical admission evidence while keeping `LEGACY_NUMERICS` default.

Do not jump directly to a broad BOFEK campaign.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z42

BRANCH: `research/f-pe-nlglob14z42-large-profile-trajectory`

RESULT POSTIMAGE BEFORE CLOSEOUT: `dbaf7996e5d95302e070ad43eb3201d01567a0e1`

QUALIFICATION STATUS: `QUALIFIED_Z42_TRAJECTORY_TIMING_GAIN`

NEXT SAFE STEP: Z43 production-admission candidate preparation.

## Production boundary

No production default change.

`LEGACY_NUMERICS` remains production default.
