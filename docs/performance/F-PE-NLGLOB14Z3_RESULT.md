# F-PE-NLGLOB14Z3 result — repaired finest-dt continuation to late retreat

Date: 2026-09-29

Status:

`QUALIFIED_REPAIRED_FINEST_LATE_RETREAT_TRAJECTORY`

Qualification authority:

- workflow run: `36614000382`;
- job: `109562257039`;
- conclusion: SUCCESS.

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Can the finest fixed-dt persistent-KLAG trajectories be continued to the accepted physical late retreat using only the already qualified one-level transaction-safe local recovery mechanism at retry-advised nominal intervals?

## Coverage

PASS.

Both frozen O05 fixtures qualify:

- HEAD;
- RUNOFF;
- nominal dt = `1.5625e-5 d`;
- horizon = `2.80 d`.

Aggregate classification:

`QUALIFIED_REPAIRED_FINEST_LATE_RETREAT_TRAJECTORY`.

## Retry behavior

Each route encounters exactly one nominal persistent-KLAG retry over the complete 2.80 d trajectory.

HEAD:

- retry step 10983;
- one exact rollback;
- two accepted half steps;
- no half-step retry;
- no further nominal retry through 2.80 d.

RUNOFF:

- retry step 10566;
- one exact rollback;
- two accepted half steps;
- no half-step retry;
- no further nominal retry through 2.80 d.

Thus the Z2 local-recovery interpretation survives the full long-horizon continuation.

## Transaction authority

For both routes:

- rejected nominal retry candidate is never accepted;
- rollback differences for h, theta, ponding, ledger and runoff are zero;
- recovery count equals nominal retry count;
- each recovery contains exactly two accepted half-duration KLAG intervals;
- global nominal dt resumes immediately after the recovered window.

No recursive subdivision occurs.

## Late physical retreat

Both repaired finest-dt trajectories reach the exact accepted physical transition:

`nodes 7:16 -> nodes 8:16`.

HEAD:

- last accepted 7:16 state: 2.442875 d;
- first accepted 8:16 state: 2.442890625 d.

RUNOFF:

- last accepted 7:16 state: 2.4396875 d;
- first accepted 8:16 state: 2.439703125 d.

No reverse move, skipped node, noncontiguous saturated state or h/theta indicator inconsistency occurs.

## Physical mass

Mass remains near roundoff over the complete repaired trajectory.

Observed maxima:

- interval physical mass ledger: about `2.65e-14 cm`;
- cumulative physical mass ledger: about `2.04e-13 cm`.

No residual redistribution or mass correction is used.

## Scientific interpretation

The finest-dt Z1 blocker is now fully resolved mechanistically.

The previously blocked trajectory does not require:

- tolerance tuning;
- larger nonlinear work limits;
- forcing changes;
- physical threshold changes;
- persistent smaller dt;
- recursive subdivision.

A single local `dt/2 + dt/2` transaction at one retry-advised interval is sufficient, after which the nominal fixed dt remains valid all the way through the independently established late physical retreat.

This restores a complete finest-dt physical trajectory for the late-retreat event.

## Qualified claim boundary

Qualified:

`QUALIFIED_REPAIRED_FINEST_LATE_RETREAT_TRAJECTORY`.

Not yet qualified:

- generic production retry subdivision;
- recursive adaptive stepping;
- complete saturated-block disappearance;
- whole-column TG re-entry after disappearance.

## Consequence

The repaired finest event times can now be combined with the complete coarser Z1 control levels to reassess the frozen late-retreat refinement ladder.

A separately persisted refinement result may determine whether the accepted `7:16 -> 8:16` event now meets the original two-finest-level convergence gate.

## Production boundary

Research only.

No production `src/**` change.

No production temporal ownership or numerical default changed.

`LEGACY_NUMERICS` remains production default.
