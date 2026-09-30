# F-PE-NLGLOB14Z14B closeout — three-fixture local recovery

Date: 2026-09-30

Final status:

`QUALIFIED_Z14B_THREE_FIXTURE_LOCAL_RECOVERY`

## Closure

All three Z14 retry-advised control blockers are recovered by exact rollback followed by:

`dt/2 + dt/2`.

For every fixture:

- both half intervals accept;
- rollback is exact;
- nominal dt resumes;
- no recurrent retry occurs over the frozen local horizon;
- state remains finite;
- physical mass remains clean.

## Direct successor

Continue the three repaired trajectories far enough to test exact accepted:

`12:16 -> 13:16`.

Use only the already-qualified one-time local recovery at each known first retry origin.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z14B

BRANCH: `research/f-pe-nlglob14z14b-three-fixture-local-recovery`

QUALIFICATION RUN: `36681068364`

QUALIFICATION STATUS: `QUALIFIED_Z14B_THREE_FIXTURE_LOCAL_RECOVERY`

NEXT SAFE STEP: repaired three-fixture event continuation.

## Production boundary

No production source/default change.
