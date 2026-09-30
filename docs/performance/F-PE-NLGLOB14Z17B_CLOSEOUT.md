# F-PE-NLGLOB14Z17B closeout — three-fixture local recovery

Date: 2026-09-30

Final status:

`QUALIFIED_Z17B_THREE_FIXTURE_LOCAL_RECOVERY`

## Closure

All three Z17 retry-advised control blockers recover by exact rollback followed by:

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

`13:16 -> 14:16`.

Use only the already-qualified one-time local recovery at each known first retry origin.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z17B

BRANCH: `research/f-pe-nlglob14z17b-three-fixture-local-recovery`

QUALIFICATION RUN: `36691927302`

QUALIFICATION STATUS: `QUALIFIED_Z17B_THREE_FIXTURE_LOCAL_RECOVERY`

NEXT SAFE STEP: repaired three-fixture continuation to `13:16 -> 14:16`.

## Production boundary

No production source/default change.
