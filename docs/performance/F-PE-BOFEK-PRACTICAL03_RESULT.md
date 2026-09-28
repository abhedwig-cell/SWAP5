# F-PE-BOFEK-PRACTICAL03 result — hydraulic-archetype + regime validation

Date: 2026-09-28

Status: `FINAL_PRACTICAL_CANDIDATE_NOT_QUALIFIED`

Authority:

- canonical base: `integration/f-ci-canonical@1113eb11966f3e5a5ced5c6e14f243d6de79a3b5`;
- Actions run: `36415345649`;
- archetype-regime validation job: `108905046768`;
- conclusion: SUCCESS.

## Frozen candidate

- B12: conservative `initial dt = 0.5*DTMAX` in all regimes;
- O14 POND: same conservative fallback;
- B01/O05 and non-POND O14:
  - DRY/TRANSITION: `DTMAX x4`;
  - WET: `initial dt = 0.5*DTMAX`;
  - POND: `initial dt = DTMAX`.

All other numerical controls remained Reference.

Validation used 16 new forcing/state cases not used in PRACTICAL01 or PRACTICAL02.

## Result

The candidate did not meet the frozen validation rule.

Aggregate:

- P-C1 pass: 15/16;
- median deterministic work reduction: 14.7%;
- required median work reduction: 20%;
- all material coverage gates: PASS;
- regime work-regression gate: PASS;
- WET/POND preservation gate: FAIL because O14/WET3 failed.

By regime:

- DRY: 4/4 pass, median work reduction about 27.1%;
- TRANSITION: 4/4 pass, median work reduction about 22.9%;
- WET: 3/4 pass, median work reduction about 9.7%;
- POND: 4/4 pass, median work reduction about 43.1%.

By material:

- B01: 4/4 pass;
- B12: 4/4 pass;
- O05: 4/4 pass;
- O14: 3/4 pass.

## Remaining failure

O14/WET3 failed only the terminal-head gate:

- max head difference: about 2.71 cm;
- P-C1 head limit: 2.0 cm;
- runoff difference: about 0.0081 cm;
- ponding difference: about 0.0049 cm;
- storage difference: about 0.0081 cm;
- water ledger remained at roundoff scale.

The candidate also used more work than Reference in this case:

- Reference work index: 188;
- candidate work index: 248.

This is therefore not a borderline accuracy-only miss that should be rescued by relaxing the gate. It is a genuine local performance regression as well.

## Decision

Per the preregistered stop rule, no further material-specific rescue policy is introduced.

The practical numerical-policy optimization line closes without a qualified production candidate.

