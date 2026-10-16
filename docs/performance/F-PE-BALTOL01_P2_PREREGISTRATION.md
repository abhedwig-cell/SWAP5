# F-PE-BALTOL01 P2 — recovered fixed-substep oracle

Date: 2026-09-26

Status: `PREREGISTERED_QUALIFICATION`

## Trigger

P1 shows that the historically anchored integrated-depth floor

`tol_rate = max(1e-12 cm/day, 2.8e-16 cm / dt)`

recovers 240/240 difficult dynamic Reference-floor points, loses no strict successes and preserves state/flux to negligible numerical differences.

## Purpose

Test whether this minimal depth-scaled floor removes the SHORTSTEP01 blocker sufficiently to recover the independent TEMPORAL03 refined oracle.

## Oracle

Use the exact TEMPORAL03 P2 physical setup and qualification subset:

- B01 wet;
- O05 wet;
- O14 wet;
- O14 mid;
- both +/-10% accepted dynamic-history directions;
- corrector offsets +/-0.001 and +/-0.01 cm.

Integrate the same 1e-4 day corrector window with equal fixed Reference-floor substeps:

- N=8;
- N=16;
- N=32.

For every substep with duration `dt_sub`, set only compartment and total balance-rate tolerance to:

`max(1e-12, 2.8e-16 / dt_sub)`.

Head tolerances and every other physical/numerical control remain unchanged.

## Measurements

Require every substep to converge and remain mass-complete.

Compare:

- 8→16 terminal max |dh| and max |dtheta|;
- 16→32 terminal max |dh| and max |dtheta|;
- terminal bottom flux;
- integrated bottom exchange;
- aggregate and maximum per-substep mass residual;
- nonlinear/backtracking work where available.

## Advancement gate

N=32 can act as provisional refined authority only for points where:

- all 8/16/32 levels complete;
- 16→32 difference is no larger than 8→16 for the principal state/flux/exchange metrics;
- mass remains complete and bounded.

If the oracle still fails after removing the known balance floor, stop and localize the remaining blocker rather than broadening the floor.

No production source change is allowed.