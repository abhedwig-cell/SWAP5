# F-PE-NLGLOB14Z17D result — fine-RUNOFF second-retry attribution

Date: 2026-09-30

Status:

`QUALIFIED_Z17D_SECOND_RETRY_ATTRIBUTION`

Qualification authority:

- workflow run: `36693965854`;
- job: `109817407750`;
- conclusion: SUCCESS.

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

The intervening canonical change adds bottom mode 7 to the temporal-indicator gate. This NLGLOB line uses bottom mode 2, so the exercised solver/retry path is unchanged.

## Frozen question

What is the second terminal interval on the fine-RUNOFF trajectory after the already-qualified first local retry recovery?

## Result

The second terminal interval is:

- step: `5,568,677`;
- time: `348.0423125 d`;
- terminal reason: `ENDPOINT_SOLVE_FAILURE`;
- solver status: `2`;
- retry advised: true;
- accepted saturated tail at origin: `13:16`;
- target `13:16 -> 14:16`: not yet accepted.

The already-qualified first retry is reproduced and repaired exactly before this second retry occurs.

## Transaction and state

At the second retry origin:

- first-retry rollback remains exact;
- both first-retry halfsteps were accepted;
- accepted state is finite;
- accepted geometry is contiguous;
- no reverse or skipped node is observed;
- physical mass remains clean;
- max interval ledger about `2.36e-14 cm`;
- cumulative accepted ledger about `2.11e-11 cm`.

## Scientific interpretation

The second fine-RUNOFF boundary is again a local nonlinear temporal-resolution request, not a hard physical-state failure.

It occurs hundreds of simulated days after the first local recovery and before the target retreat.

Thus the one-repair-only Z17C policy is insufficient for this trajectory, but the second terminal origin itself remains transactionally and physically admissible for a separately preregistered bounded local-recovery test.

## Consequence

A successor may test exactly one additional local recovery at the second retry origin:

`dt -> dt/2 + dt/2 -> dt`.

No recursive subdivision, tolerance tuning, forcing change or physical-threshold change is authorized.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
