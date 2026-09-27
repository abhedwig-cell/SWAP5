# F-PE-TEMPORAL03 closeout — dynamic-history and refined-oracle qualification

Date: 2026-09-26

Status: `CLOSED_ORACLE_BLOCKED_BY_SHORTSTEP_SOLVER_PATHOLOGY`

## Purpose

Extend TEMPORAL02 beyond stationary zero-history origins and qualify temporal-budget candidates against an independent refined Reference oracle.

## What was established

### P0 — dynamic-origin authority

All six difficult PROFILE06 origins were converted into deterministic, mass-conservative dynamic histories in both +/-10% forcing directions.

Predecessor head-rate magnitudes were materially nonzero, ranging from roughly 20 cm/day to more than 1500 cm/day.

### P1A-P1C — dynamic temporal-budget frontier

The stationary TEMPORAL02 frontier does not transfer to dynamic histories.

For |dh| = 0.001 cm:

- 0.1 cm budget completes 23/24 dynamic signed-history points;
- 0.2 cm completes 24/24 and is the first tested common frontier.

For |dh| = 0.01 cm:

- 0.05 cm completes 20/24;
- 0.1 cm completes 24/24 and is the first tested common frontier.

These boundaries were replicated deterministically in three fresh processes per point.

The required dynamic budgets are vastly larger than the stationary frontiers, demonstrating that predecessor temporal history strongly controls the current certificate scale.

Local completion is also not perfectly monotone in budget because changed accept/retry paths can move the subsequent physical solver into different nonlinear regimes.

### P2 — independent refined oracle attempt

A certificate-free Reference-floor oracle was preregistered using fixed 8, 16 and 32 equal substeps over the same 1e-4 day corrector window.

The oracle could not be formed.

Reference-floor substeps fail with `KERNEL_REFERENCE_FLOOR_STATUS_SOLVER_FAILED (204)`, usually at the first reduced-duration physical solve.

This reproduces the short-duration nonlinear pathology outside the canonical transaction wrapper.

## Scientific conclusion

Two conclusions are now supported:

1. The current temporal certificate budget is not portable from stationary to dynamic origins; predecessor derivative history dominates the acceptance scale in the tested dynamic cases.
2. The exact Reference Richards path is not currently suitable as an independent fixed-substep oracle because decreasing the step duration can make the nonlinear solve fail even when the larger full-window solve converges.

The second finding prevents temporal-policy admission. A larger temporal budget may improve completion and runtime, but without an independent refined oracle its physical temporal error cannot be certified.

## Decision

TEMPORAL03 closes at a real blocker.

No production `src/**` change is admitted.

No fixed temporal budget, scaled budget or coupling-specific temporal policy is admitted.

No APPROX04 surrogate is reopened.

## Required successor

`F-PE-SHORTSTEP01 — Reference Richards short-duration convergence pathology`

The successor should diagnose why reduced step duration degrades nonlinear convergence in the difficult mode-5 prescribed-head cases, including:

- first failed Newton/backtracking state;
- residual and update scaling versus dt;
- Jacobian/forcing terms containing dt or 1/dt;
- convergence tolerances and line-search behavior as dt shrinks;
- whether the pathology is a solver defect, formulation/initialization issue, or intended but poorly conditioned limit;
- a certificate-free fixed-substep convergence ladder after any qualified repair.

Only after SHORTSTEP01 closure should temporal-oracle qualification resume.