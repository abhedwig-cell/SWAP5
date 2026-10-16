# F-PE-BOFEK-PRACTICAL01 result — bounded global practical-policy screen

Date: 2026-09-28

Status: `GLOBAL_POLICY_NOT_QUALIFIED_REGIME_SIGNAL_CONFIRMED`

Authority:

- canonical base: `integration/f-ci-canonical@1113eb11966f3e5a5ced5c6e14f243d6de79a3b5`;
- Actions run: `36414665791`;
- job: `108902804269`;
- conclusion: SUCCESS.

## Frozen P-C1 gate

P-C1 preserved exact mass accounting and bounded trajectory differences relative to the corrected adaptive Reference baseline.

Global advancement required:

- at least 15/16 screening cases passing P-C1;
- median deterministic work reduction >= 15%;
- no wet/ponding screening failure;
- no retry pathology.

## Global candidates

No global candidate qualified.

- DTMAX_X2: 12/16 pass, median work reduction among passing cases 37.3%, wet/ponding failures present.
- DTMAX_X4: 12/16 pass, median work reduction among passing cases 42.4%, wet/ponding failures present.
- DT0_HALFMAX: 16/16 pass, median work reduction 12.3%, below the frozen 15% gate.
- DT0_MAX: 14/16 pass, median work reduction 23.8%, wet failure present.
- HEAD_X10: 16/16 pass, median work reduction 3.1%.
- HEAD_X100: 16/16 pass, median work reduction 7.4%.

The 15% threshold is not relaxed post hoc.

## Regime structure

A preregistered regime split may be considered because no global candidate qualified and the screen shows strong opposing regime behavior.

Observed screening signal:

- DRY:
  - DTMAX_X4 passes 4/4;
  - work reduction about 48%.
- TRANSITION:
  - DTMAX_X4 passes 4/4;
  - work reduction about 47%.
- MOIST:
  - DT0_HALFMAX passes 3/3;
  - work reduction about 12.5%.
- WET:
  - DT0_HALFMAX passes 3/3;
  - work reduction about 8.6%.
- POND:
  - DT0_MAX passes 2/2;
  - work reduction about 71%.

The aggressive DTMAX candidates fail specifically as the surface becomes runoff/ponding sensitive.

## Decision

No global practical policy advances.

Open F-PE-BOFEK-PRACTICAL02 as a data-derived regime-policy validation workunit.

The screening cases used here cannot serve as validation for PRACTICAL02.

