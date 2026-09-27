# F-PE-BALTOL01 — Reference Richards balance-tolerance qualification

Date: 2026-09-26

Status: `PREREGISTERED_QUALIFICATION`

Parent: `F-PE-SHORTSTEP01` / PR #645

Parent head: `0f398e68fa74d7f02283eb0bd5ea98c8567df2c8`

## Trigger

SHORTSTEP01 established that representative certificate-free short-duration Reference failures at 1e-12 are balance-tolerance-floor artifacts:

- head-change convergence is already satisfied;
- terminal residuals are at O(1e-12);
- changing only compartment and total balance tolerances from 1e-12 to 2e-12 converts all three fail targets into fast successful solves;
- accepted state and terminal-flux differences across successful tolerance arms are at floating-point/negligible scale.

This does not yet authorize a production tolerance change.

## Purpose

Qualify whether a minimally relaxed Reference balance tolerance can serve as a numerically robust reference authority without materially weakening physical or mass accuracy.

## Scope

Qualification-first.

No production `src/**` change in P0-P2.

Any production/default change requires a later explicit admission phase.

## Candidate tolerances

Vary compartment and total balance tolerances together:

- 1e-12, current strict control;
- 2e-12, minimal SHORTSTEP01 recovery candidate;
- 5e-12;
- 1e-11;
- 1e-10.

Head tolerances and every other numerical/physical control remain unchanged.

## P0 — broad difficult Reference matrix

Use the difficult hydraulic states already exercised by PROFILE06/TEMPORAL03, including:

- B01 wet and mid;
- B12 wet;
- O05 wet;
- O14 wet and mid;
- stationary and accepted dynamic-history origins where applicable;
- prescribed-head corrector offsets spanning at least +/-0.001 and +/-0.01 cm;
- duration ladder including full 1e-4 day and the known difficult short-step bands.

Measure:

- convergence/pass set;
- nonlinear iterations;
- backtracking;
- terminal state;
- terminal bottom flux;
- integrated mass residual.

## P1 — reference-equivalence envelope

For every point where both the 1e-12 control and a candidate tolerance converge, compare:

- max |dh|;
- max |dtheta|;
- terminal flux difference;
- integrated bottom exchange difference where available;
- mass residual.

The candidate is not admitted merely because it converges more cases.

## P2 — recovered refined oracle

Re-run the TEMPORAL03 fixed-substep Reference oracle using the smallest candidate tolerance that passes P0-P1.

Require 8, 16 and 32 equal-substep levels where feasible.

Demonstrate:

- successful fixed-substep execution;
- refinement convergence of terminal state and integrated exchange;
- no material mass degradation.

## Decision boundary

A candidate balance tolerance can advance only if:

- it removes the documented tolerance-floor failure bands;
- overlapping strict-control solutions remain physically equivalent at negligible scale;
- mass accounting remains complete and bounded;
- the refined temporal oracle becomes measurable and convergent.

## Stop conditions

Do not broaden tolerance further merely to obtain completion.

Stop or split if:

- state/flux differences become material;
- mass residual scales materially with tolerance;
- oracle refinement is nonconvergent after the tolerance-floor blocker is removed;
- another solver defect is exposed.

## Production boundary

No production default or hard-coded Reference tolerance is changed in this qualification workunit.