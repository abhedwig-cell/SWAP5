# F-PE-SHORTSTEP01 P2 — convergence-gate attribution

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

P1 showed failed neighboring durations reaching near-tolerance residuals while exhausting Newton/backtracking iterations.

## Purpose

Identify which exact convergence criterion remains active at the terminal failed iterations.

## Method

Use a test-only copy of `headcalc.f90`. For the same P1 target contrasts, after the existing convergence checks record:

- number of nodes failing compartment-balance tolerance;
- maximum absolute compartment residual;
- number of nodes failing head-change tolerance;
- maximum normalized head-change metric using the existing absolute/relative criterion split;
- total residual sum and whether it fails total-balance tolerance;
- `flnonconv` state;
- iteration number and dt.

Do not alter any convergence, line-search or update logic.

## Decision

If a single convergence gate systematically remains active after balance residuals have collapsed, localize the pathology to that gate and open a separate repair/qualification workunit before changing production code.

If multiple gates remain active, continue diagnostic decomposition.

No production source change is allowed.