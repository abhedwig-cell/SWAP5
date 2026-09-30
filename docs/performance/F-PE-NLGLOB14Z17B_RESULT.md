# F-PE-NLGLOB14Z17B result — three-fixture local retry recovery

Date: 2026-09-30

Status:

`QUALIFIED_Z17B_THREE_FIXTURE_LOCAL_RECOVERY`

Qualification authority:

- workflow run: `36691927302`;
- job: `109810890226`;
- conclusion: SUCCESS.

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`

The intervening canonical change adds typed mass-residual publication only for bottom mode 7. This NLGLOB line uses bottom mode 2, so the solver/retry path exercised here is unchanged.

## Frozen question

Can the first retry-advised interval in each of the three Z17-blocked controls be crossed by the already qualified one-level transaction recovery:

`dt -> dt/2 + dt/2 -> dt`?

## Aggregate result

PASS.

All three fixtures classify:

`QUALIFIED_Z17B_LOCAL_RETRY_RECOVERY`.

Aggregate classification:

`QUALIFIED_Z17B_THREE_FIXTURE_LOCAL_RECOVERY`.

## HEAD, dt = 6.25e-5 d

- nominal retry step: 2,649,048;
- rollback exact;
- half 1 accepted;
- half 2 accepted;
- no half-step retry;
- nominal window recovered exactly;
- nominal dt restored;
- no recurrent retry through 170.0 d;
- complete 170.0 d trajectory;
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
- complete 212.0 d trajectory.

Physical mass:

- max interval ledger about `1.57e-14 cm`;
- cumulative accepted ledger about `2.65e-12 cm`.

## RUNOFF, dt = 6.25e-5 d

- nominal retry step: 1,138,915;
- rollback exact;
- both half intervals accepted;
- nominal window recovered exactly;
- no recurrent retry through 75.0 d;
- complete 75.0 d trajectory.

Physical mass:

- max interval ledger about `2.36e-14 cm`;
- cumulative accepted ledger about `7.18e-13 cm`.

## Scientific interpretation

All three Z17 pre-event blockers are local nonlinear interval-resolution events.

A single transaction-safe temporal subdivision at the known retry origin restores nominal progress in every fixture without:

- tolerance changes;
- forcing changes;
- physical threshold changes;
- recursive subdivision.

## Qualified claim boundary

Qualified:

`QUALIFIED_Z17B_THREE_FIXTURE_LOCAL_RECOVERY`.

Not yet qualified:

- repaired event exposure of `13:16 -> 14:16` in the three formerly blocked controls;
- four-fixture control authority for that event;
- split ownership beyond 13:16;
- disappearance;
- whole-column TG re-entry.

## Consequence

A separately preregistered Z17C may continue the three repaired trajectories toward the independently observed coarse-HEAD physical retreat at 514.664625 d.

Only the already attributed first retry in each fixture may be repaired.

No second recovery is permitted without separate qualification.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
