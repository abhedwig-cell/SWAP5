# F-PE-TIMEARCH16 closeout — wet-zone AUTO eligibility calibration

Date: 2026-09-28

Final status:

`QUALIFIED_AUTO_REFERENCE_CALIBRATION_CANDIDATE_GUARD_M5`

## Decision

The first AUTO_REFERENCE candidate has cleared a preregistered calibration gate without using:

- soil IDs;
- regime IDs;
- a normal operating DTMAX.

Selected candidate:

`GUARD_M5`

with 16/16 P-C1 and about 33.6% median deterministic work reduction.

## Required successor

`F-PE-TIMEARCH17 — blind validation of frozen GUARD_M5 AUTO_REFERENCE candidate`.

Validation must use new state/forcing points and may not tune:

- R=0.40;
- -5 cm guard;
- REFINE4;
- bootstrap dt;
- fallback semantics;
- P-C1 gates.

## Production boundary

Research candidate only.
