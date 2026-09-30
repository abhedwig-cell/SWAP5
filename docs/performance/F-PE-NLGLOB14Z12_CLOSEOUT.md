# F-PE-NLGLOB14Z12 closeout — blocked control beyond 11:16

Date: 2026-09-30

Final status:

`BLOCKED_NLGLOB14Z12_CONTROL_EXPOSURE`

## Closure

Z12 does not qualify its four-fixture event contract.

Accepted `11:16 -> 12:16` is exposed in three fixtures near 123.5845-123.5879 d, but fine RUNOFF hits `ENDPOINT_SOLVE_FAILURE` before the event while still at accepted tail `11:16`.

Mass and accepted geometry remain clean.

## Preserved evidence

Valid event exposure:

- HEAD dt 1.25e-4;
- HEAD dt 6.25e-5;
- RUNOFF dt 1.25e-4.

Not qualified:

- RUNOFF dt 6.25e-5;
- aggregate control event authority;
- downstream split ownership.

## Direct successor

Attribute and, only if transaction semantics permit, recover the fine-RUNOFF pre-event endpoint solve failure without changing tolerances or physics.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z12

BRANCH: `research/f-pe-nlglob14z12-control-beyond-11`

RUN: `36674896760`

STATUS: blocked aggregate with preserved 3/4 accepted event evidence

NEXT SAFE STEP: local fine-RUNOFF pre-event retry/failure attribution.

## Production boundary

No production source/default change.
