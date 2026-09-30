# F-PE-NLGLOB14Z17C closeout — recurrent fine-RUNOFF retry before 13:16 -> 14:16

Date: 2026-09-30

Final status:

`BLOCKED_NLGLOB14Z17C_BY_RECURRENT_FINE_RUNOFF_RETRY`

## Closure

Z17C does not satisfy its three-fixture positive aggregate because fine RUNOFF encounters a second retry before the target event.

Positive repaired event trajectories:

- HEAD fine: event at 514.66475 d;
- RUNOFF coarse: event at 514.661375 d.

Blocked trajectory:

- RUNOFF fine;
- second retry at 348.0423125 d;
- accepted tail still 13:16;
- target event not yet reached.

Accepted state, geometry and mass remain valid.

## Direct successor

Attribute the second fine-RUNOFF retry before attempting any second local repair.

No split ownership beyond 13:16 is authorized yet.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z17C

BRANCH: `research/f-pe-nlglob14z17c-repaired-event-continuation`

RUN: `36692861086`

STATUS: blocked by recurrent fine-RUNOFF retry before target event

NEXT SAFE STEP: second-retry attribution for fine RUNOFF at 348.0423125 d.

## Production boundary

No production source/default change.
