# F-PE-STATESTEP02 result — normalized accepted-step head controller

Date: 2026-09-28

Status: `NORMALIZED_SIGNAL_PROMISING_BUT_NOT_QUALIFIED`

Authority:

- canonical base: `integration/f-ci-canonical@0714438bbb248e8056b0ad096dc02ceae8e48e22`;
- Actions run: `36416164416`;
- normalized-screen job: `108907725801`;
- conclusion: SUCCESS.

## Result

The dimensionless normalized head-change signal is materially better than absolute max|dh|.

Best arm:

`RH_SURF, target R=0.40`

- P-C1 pass: 14/16;
- median deterministic work reduction on passing cases: about 34.3%;
- no qualification because all WET/POND must pass and at least 15/16 are required.

Failures:

- B01/POND: solver nonconvergence after aggressive history-driven stepping;
- B12/MOIST: trajectory accuracy failure after the case transitions into ponding.

## Interpretation

The signal itself has useful performance content. The failure mechanism is that the surface safeguard only acts after accepted ponding/runoff is already present. It cannot prevent the preceding aggressive step that enters the sensitive near-surface regime.

## Decision

Do not qualify RH_ONLY or RH_SURF.

One final causal pre-ponding safeguard may be tested with target R=0.40 frozen.
