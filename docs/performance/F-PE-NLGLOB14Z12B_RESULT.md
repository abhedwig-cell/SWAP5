# F-PE-NLGLOB14Z12B result — local fine-RUNOFF retry recovery

Date: 2026-09-30

Status:

`QUALIFIED_FINE_RUNOFF_LOCAL_RETRY_RECOVERY`

Qualification authority:

- workflow run: `36676164314`;
- job: `109761489786`;
- conclusion: SUCCESS.

## Frozen question

Can the first fine-RUNOFF pre-event retry-advised interval at 71.1821875 d be crossed by exact rollback plus one bounded:

`dt -> dt/2 + dt/2 -> dt`

recovery?

## Result

PASS.

Observed:

- nominal retry count: 1;
- retry step: 1138915;
- rollback exact;
- half 1 accepted;
- half 2 accepted;
- recovered window equals one nominal dt;
- recurrent retry count through 75.0 d: 0;
- trajectory completes 75.0 d;
- final solver status converged.

## Physical mass

- max interval ledger: about `2.36e-14 cm`;
- cumulative accepted ledger: about `7.18e-13 cm`.

State remains finite and accepted accounting remains valid.

## Scientific interpretation

The fine-RUNOFF Z12 blocker is locally transaction-recoverable with the already qualified one-level subdivision policy.

No tolerance, forcing or physical threshold change is required.

## Consequence

A separately preregistered Z12C may continue this repaired fine-RUNOFF trajectory to the physical `11:16 -> 12:16` event and determine whether any further retry occurs.

## Production boundary

Research only. No production source/default change.
