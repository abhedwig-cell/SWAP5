# F-PE-BOFEK-PRACTICAL02 result — regime-aware practical validation

Date: 2026-09-28

Status: `REGIME_ONLY_POLICY_NOT_QUALIFIED_HYDRAULIC_CLASS_SIGNAL`

Authority:

- canonical base: `integration/f-ci-canonical@1113eb11966f3e5a5ced5c6e14f243d6de79a3b5`;
- Actions run: `36415035870`;
- regime-validation job: `108904028138`;
- conclusion: SUCCESS.

## Frozen candidate

- DRY / TRANSITION: DTMAX x4;
- WET: initial dt = 0.5 * DTMAX;
- POND: initial dt = DTMAX;
- all other controls unchanged.

Validation used 16 new material/regime cases that were not used in PRACTICAL01.

## Result

The candidate did not validate.

Aggregate:

- P-C1 pass: 13/16;
- median deterministic work reduction over passing cases: 20.6%;
- deterministic performance threshold itself was met;
- WET/POND preservation failed;
- material coverage rule failed.

By regime:

- DRY: 4/4 pass, median work reduction about 40.6%;
- TRANSITION: 3/4 pass, median work reduction about 20.6%;
- WET: 4/4 pass, median work reduction about 10.9%;
- POND: 2/4 pass, median work reduction about 61.2%.

By material:

- B01: 4/4 pass;
- B12: 2/4 pass;
- O05: 4/4 pass;
- O14: 3/4 pass.

## Failures

All three validation failures are accuracy failures on cumulative runoff, not mass-balance failures or solver instability:

- B12/TRANS2:
  - runoff difference about 0.0122 cm;
  - max head difference about 0.49 cm.
- B12/POND2:
  - runoff difference about 0.0137 cm;
  - max head difference about 0.50 cm.
- O14/POND2:
  - runoff difference about 0.0149 cm;
  - max head difference about 0.015 cm.

These failures occur with complete solves and very small ledger residuals.

## Interpretation

A regime-only policy is too coarse.

The data show a reproducible hydraulic-response interaction:

- B12, the strong-capillary/gradual-retention archetype, is more trajectory-sensitive in transition and ponding regimes;
- O14 also needs more conservative handling in ponding;
- B01 and O05 tolerate the aggressive regime policy across this validation bank.

## Decision

Do not qualify the regime-only candidate.

Open a final research-only hydraulic-archetype + regime validation workunit.

The PRACTICAL02 validation cases are now exposed and may not be reused as validation evidence.

