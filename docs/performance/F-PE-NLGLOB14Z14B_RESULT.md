# F-PE-NLGLOB14Z14B result — three-fixture local retry recovery

Date: 2026-09-30

Status:

`QUALIFIED_Z14B_THREE_FIXTURE_LOCAL_RECOVERY`

Qualification authority:

- workflow run: `36681068364`;
- job: `109776412152`;
- conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Can the first retry-advised interval in each of the three Z14-blocked controls be crossed by the already qualified one-level transaction recovery:

`dt -> dt/2 + dt/2 -> dt`?

## Aggregate result

PASS.

All three fixtures classify:

`QUALIFIED_Z14B_LOCAL_RETRY_RECOVERY`.

Aggregate classification:

`QUALIFIED_Z14B_THREE_FIXTURE_LOCAL_RECOVERY`.

## HEAD, dt = 6.25e-5 d

- nominal retry step: 2,649,048;
- rollback exact;
- half 1 accepted;
- half 2 accepted;
- no half-step retry;
- nominal window recovered exactly;
- nominal dt restored;
- no recurrent retry through 170.0 d;
- trajectory completes 170.0 d;
- final solver status converged.

Physical mass:

- max interval ledger about `1.83e-14 cm`;
- cumulative accepted ledger about `6.02e-12 cm`.

## RUNOFF, dt = 1.25e-4 d

- nominal retry step: 1,659,714;
- rollback exact;
- both half intervals accepted;
- nominal window recovered exactly;
- no recurrent retry through 212.0 d;
- trajectory completes 212.0 d.

Physical mass:

- max interval ledger about `1.57e-14 cm`;
- cumulative accepted ledger about `2.65e-12 cm`.

## RUNOFF, dt = 6.25e-5 d

- nominal retry step: 1,138,915;
- rollback exact;
- both half intervals accepted;
- nominal window recovered exactly;
- no recurrent retry through 75.0 d;
- trajectory completes 75.0 d.

Physical mass:

- max interval ledger about `2.36e-14 cm`;
- cumulative accepted ledger about `7.18e-13 cm`.

## Scientific interpretation

All three Z14 pre-event blockers are local nonlinear interval-resolution events.

The accepted physical origins remain valid, and one exact transaction-safe `dt/2 + dt/2` subdivision is sufficient to restore progress in every fixture.

No tolerance, forcing or physical threshold change is required.

## Qualified claim boundary

Qualified:

`QUALIFIED_Z14B_THREE_FIXTURE_LOCAL_RECOVERY`.

Not yet qualified:

- repaired event exposure of `12:16 -> 13:16` in the three formerly blocked fixtures;
- aggregate four-fixture control authority for that event;
- split ownership beyond 12:16;
- disappearance;
- whole-column TG re-entry.

## Consequence

A separately preregistered Z14C may continue the three repaired trajectories toward the independently observed coarse-HEAD physical retreat near 260.961125 d.

The same one-time local recovery is permitted only at the already attributed first retry origin of each fixture.

No second recovery is permitted in Z14C unless separately preregistered.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
