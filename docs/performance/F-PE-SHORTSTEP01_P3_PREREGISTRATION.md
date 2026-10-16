# F-PE-SHORTSTEP01 P3 — balance-tolerance floor qualification

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

P2 localized failed short-duration solves to near-tolerance balance stagnation. The head-change gate is already satisfied in all representative failures.

## Purpose

Test whether the non-monotone dt pass/fail bands are caused by an absolute 1e-12 balance-tolerance floor rather than materially different physical solutions.

## Targets

Use the same P1/P2 representative contrasts:

- B01 wet, +0.1 history, +0.001 cm at dt 5e-5;
- O05 wet, -0.1 history, +0.001 cm at dt 1.25e-5;
- O14 wet, +0.1 history, -0.001 cm at dt 3.75e-5.

Include their nearest successful neighboring durations as controls.

## Arms

Change only compartment and total balance tolerances together:

- 1e-12, current qualification setting;
- 2e-12;
- 5e-12;
- 1e-11;
- 1e-10.

Keep head tolerances, solver caps, physical state, forcing, dt and all other numerical settings unchanged.

## Measurements

- floor status;
- nonlinear iterations;
- backtracking attempts;
- terminal state and bottom flux for successful arms;
- mass residual;
- state/flux differences versus the strictest successful arm for the same target.

## Decision

If a small tolerance relaxation removes the pass/fail pathology while changing state and flux only at negligible scale, classify the blocker as a convergence-tolerance floor and open a separate repair/qualification workunit for a principled tolerance policy.

If materially different states appear, continue solver diagnosis instead.

No production `src/**` change is allowed.