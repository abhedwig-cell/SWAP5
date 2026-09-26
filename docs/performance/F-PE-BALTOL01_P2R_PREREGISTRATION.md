# F-PE-BALTOL01 P2R — terminal-flux refinement exception

Date: 2026-09-26

Status: `PREREGISTERED_QUALIFICATION`

## Trigger

P2 recovered the independent fixed-substep oracle on all 32 points using the DEPTH_2P8E16 balance floor. One point failed only the terminal-flux monotonicity check.

## Target

B01 wet, dynamic history +0.1, prescribed-head offset -0.01 cm.

## Levels

Run N=16, 32 and 64 equal fixed substeps over the same 1e-4 day corrector window.

Use exactly:

`tol_rate=max(1e-12 cm/day, 2.8e-16 cm / dt_sub)`.

## Measurements

Compare 16→32 and 32→64 for:

- terminal max |dh|;
- terminal max |dtheta|;
- terminal bottom flux;
- integrated bottom exchange;
- aggregate and maximum per-substep mass residual.

## Decision

If 32→64 contracts relative to 16→32 for the principal state, exchange and terminal-flux metrics, the N=32 oracle may be treated as provisionally refined for the P2 matrix.

If terminal flux remains nonconvergent, retain the oracle blocker and continue flux-specific diagnosis.

No production source change is allowed.