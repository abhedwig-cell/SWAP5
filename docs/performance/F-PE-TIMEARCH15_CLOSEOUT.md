# F-PE-TIMEARCH15 closeout — flux AUTO fallback state machine

Date: 2026-09-28

Final status:

`CLOSED_NEAR_QUALIFIED_SINGLE_PONDING_FAILURE`

## Decision

The AUTO_FLUX -> LEGACY_SAFE state-machine architecture is retained as a promising research direction but is not qualified.

TIMEARCH15 achieved:

- 15/16 P-C1;
- about 34.3% median deterministic work reduction on passing cases.

The sole blocker is B01/POND solver-floor failure.

## Required successor

`F-PE-TIMEARCH16 — wet-zone AUTO eligibility guard`.

TIMEARCH16 may test state-based AUTO eligibility thresholds, but must:

- keep all TIMEARCH15 physical/performance gates;
- use no material/regime identifiers;
- switch to LEGACY_SAFE rather than merely cap one step;
- keep the normalized AUTO proposal unchanged where eligible;
- preregister thresholds before exposure.

## Production boundary

No production timestep behavior changes.
