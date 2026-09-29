# F-PE-NLGLOB14Z2 result — local persistent-KLAG retry recovery

Date: 2026-09-29

Status:

`QUALIFIED_LOCAL_PERSISTENT_KLAG_RETRY_RECOVERY`

Qualification authority:

- workflow run: `36613374725`;
- job: `109560136975`;
- conclusion: SUCCESS.

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

The intervening canonical delta is ELASTIC45-only and does not alter the TIMEINT17/NLGLOB dependency surface.

## Frozen question

At the first reproducible finest-dt persistent-KLAG `SW_SOLVE_RETRY_ADVISED` interval, can exact rollback plus two half-duration KLAG transactions recover the original nominal time window, after which the original fixed dt resumes?

## Coverage

PASS.

Both frozen O05 finest-dt fixtures qualify:

- HEAD;
- RUNOFF;
- nominal dt = `1.5625e-5 d`;
- horizon = `0.18 d`.

Aggregate classification:

`QUALIFIED_LOCAL_PERSISTENT_KLAG_RETRY_RECOVERY`.

## Nominal retry reproduction

HEAD:

- retry step: 10983;
- nominal dt: `1.5625e-5 d`;
- solver status: 2, `SW_SOLVE_RETRY_ADVISED`;
- accepted saturated count at origin: 12;
- terminal reason of rejected nominal trial: `ENDPOINT_SOLVE_FAILURE`.

RUNOFF:

- retry step: 10566;
- same nominal dt;
- same retry-advised solver status;
- accepted saturated count at origin: 12;
- same rejected nominal terminal reason.

Thus Z2 reproduces the Z1 local failure exactly.

## Transaction rollback

Before subdivision, the rejected nominal trial is rolled back exactly.

Both routes record:

- pressure-head restore difference = 0;
- water-content restore difference = 0;
- ponding restore difference = 0;
- cumulative-ledger restore difference = 0;
- runoff-accounting restore difference = 0.

The retry candidate is never accepted.

## Half-step recovery

Temporary half dt:

`7.8125e-6 d`.

For both HEAD and RUNOFF:

- half 1 converges;
- half 2 converges;
- neither half requests retry;
- both remain on valid accepted state;
- both preserve the 12-node saturated lower block over the repaired window.

The two half intervals exactly reconstruct one nominal time window.

## Resumption

After the repaired nominal window:

- global dt is restored to `1.5625e-5 d`;
- both trajectories complete the frozen 0.18 d horizon;
- no recurrent retry occurs before 0.18 d;
- terminal reason returns to `COMPLETE_SAME_ROUTE`.

This is therefore local recoverability, not immediate persistent retry behavior.

## Physical mass

Physical mass remains near roundoff.

Observed maxima:

- max accepted-interval ledger: about `2.65e-14 cm`;
- max cumulative ledger: about `1.53e-13 cm`.

No mass correction or redistribution is introduced.

## Scientific interpretation

The Z1 finest-dt failure is not a hard physical barrier and not evidence that the accepted state itself is invalid.

It is a local nonlinear interval-resolution event.

One transaction-safe `dt/2 + dt/2` subdivision crosses the interval and permits the original fixed dt to resume immediately.

This explains the previously non-monotone fixed-dt behavior more narrowly:

- a smaller nominal dt can still encounter a local nonlinear retry state;
- the state is recoverable by bounded temporal subdivision;
- smaller nominal dt is therefore not guaranteed to remove all local nonlinear resolution events.

## Qualified claim boundary

Qualified:

`QUALIFIED_LOCAL_PERSISTENT_KLAG_RETRY_RECOVERY`.

Not yet qualified:

- repeated or recursive retry recovery over the full late-horizon trajectory;
- adaptive production stepping;
- late-retreat event refinement at dt=1.5625e-5;
- saturated-block disappearance;
- production temporal ownership.

## Consequence

A separately preregistered continuation may now run the repaired finest-dt trajectory to the late `7:16 -> 8:16` event and test:

1. whether additional retry windows occur;
2. whether one-time local subdivision remains sufficient;
3. whether the late retreat is reached on the repaired trajectory;
4. whether accepted physical mass and geometry remain clean.

No tolerance tuning is authorized.

## Production boundary

Research only.

No production `src/**` change.

No production temporal ownership or numerical default changed.

`LEGACY_NUMERICS` remains production default.
