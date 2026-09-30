# F-PE-NLGLOB14Z14A closeout — three-fixture retry attribution

Date: 2026-09-30

Final status:

`QUALIFIED_Z14A_THREE_FIXTURE_RETRY_ATTRIBUTION`

## Closure

All three Z14 pre-event blockers are local `SW_SOLVE_RETRY_ADVISED` endpoint-solve failures with clean accepted state and mass.

Failure times:

- HEAD fine: 165.565500 d;
- RUNOFF coarse: 207.464250 d;
- RUNOFF fine: 71.1821875 d.

No hard failure, geometry inconsistency or mass corruption is observed.

## Direct successor

Test one-level transaction-safe recovery separately at each first retry origin:

`dt -> dt/2 + dt/2 -> dt`.

No recursive subdivision or tolerance tuning.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z14A

BRANCH: `research/f-pe-nlglob14z14a-pre-event-attribution`

QUALIFICATION RUN: `36680488191`

QUALIFICATION STATUS: `QUALIFIED_Z14A_THREE_FIXTURE_RETRY_ATTRIBUTION`

NEXT SAFE STEP: three-fixture bounded local retry recovery.

## Production boundary

No production source/default change.
