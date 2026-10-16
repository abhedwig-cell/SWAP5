# F-PE-SHORTSTEP01 — Reference Richards short-duration convergence pathology

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

Parent: `F-PE-TEMPORAL03` / PR #644

Parent head: `7fa02959ee414cdcb034a67c80ac1f0052d24ed1`

## Trigger

TEMPORAL03 attempted an independent certificate-free fixed-substep Reference oracle from physically constructed dynamic origins.

The oracle failed because reduced-duration Reference-floor solves returned:

`KERNEL_REFERENCE_FLOOR_STATUS_SOLVER_FAILED = 204`

usually on the first substep, even though the corresponding larger/full-window physical solve can converge.

This reproduces the short-duration failure already seen downstream of temporal-certificate retries in REPRO02.

## Purpose

Diagnose why reducing the Reference Richards step duration can degrade or destroy nonlinear convergence in difficult mode-5 prescribed-head cases.

Diagnostic-only.

No production repair is allowed until the mechanism is localized and a separate repair/qualification phase is explicitly opened.

## P0 — single-step duration ladder

Use the TEMPORAL03 physically constructed dynamic origins with nonzero predecessor history, but remove temporal acceptance entirely.

For each selected difficult origin/history/corrector target, snapshot the same dynamic physical origin into a plain committed state and execute exactly one Reference-floor physical step.

Vary only step duration:

- 1e-4 day;
- 7.5e-5 day;
- 5e-5 day;
- 3.75e-5 day;
- 2.5e-5 day;
- 1.875e-5 day;
- 1.25e-5 day;
- 6.25e-6 day;
- 3.125e-6 day.

Primary cases:

- B01 wet;
- O05 wet;
- O14 wet;
- O14 mid;

both +/-10% history directions, with prescribed-head offsets +/-0.001 and +/-0.01 cm.

## P0 measurements

Record:

- physical solver status;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- internal retries;
- terminal bottom flux when converged;
- mass completeness/residual when converged.

Every duration is run from an identical physical origin in a fresh process.

## P1 — first divergence localization

If P0 confirms a duration threshold, instrument the Reference solver around the first failing Newton/backtracking path.

Compare a nearest successful and failing duration for:

- initial residual norm;
- linear update norm;
- accepted/rejected line-search factors;
- equation residual after each Newton update;
- bottom-boundary contribution;
- storage/time coefficient terms proportional to dt or 1/dt;
- head and water-content changes.

## Interpretation

Do not assume that smaller dt should automatically be easier. The purpose is to identify the actual discrete nonlinear conditioning and implementation behavior.

## Stop / split rules

If a concrete implementation defect is found, open a separate repair workunit before modifying production `src/**`.

If the behavior is mathematically expected from the formulation, characterize the conditioning envelope and identify an alternative exact oracle strategy.

No production `src/**` change is allowed in SHORTSTEP01 diagnostic phases.