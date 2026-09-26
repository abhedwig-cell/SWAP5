# F-PE-REPRO01 D7 — directional scratch-group localization

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

D6 produced a deterministic equivalence failure on the exact mode-5 accepted-direction seam:

- CLEAN: 100/100 PASS;
- fully POISONED prior scratch: 0/100 PASS;
- poisoned failure signature exactly matched the spontaneous status-6 failure.

The ordinary poison gate does not cover this route.

## Purpose

Localize which Reference scratch family can influence the physical solve before being fully overwritten.

## Method

Use one test-only backend.

Immediately before the mode-5 call to `solve_with_accepted_step_direction`:

1. ensure workspace shape;
2. fully zero/reset the workspace;
3. poison exactly one scratch family with quiet NaN;
4. execute the unchanged accepted-direction service.

The ZERO arm performs steps 1-2 only.

Test groups:

- ZERO;
- DFDH: lower/main/upper Jacobian diagonals;
- RESIDUAL_DELTA: residual and Newton delta;
- SOURCE_SINK: source and sink vectors;
- PROVIDER: provider theta/K/capacity/dKdh/root-sink scratch;
- DCON_OLD: conductivity derivative and old-head scratch;
- FLUX_GRAD: vertical-flux and head-gradient scratch;
- BAND: band matrix, aux and RHS.

TRIDAG gamma is not included in this first split because D6 poisoning occurs before factorization-capture expansion, which replaces the compact gamma allocation.

## Execution

Run 40 fresh exact first-corrector processes per group.

## Decision

Any single poisoned group that deterministically or materially increases status-6 failures identifies a read-before-write defect family.

If multiple groups fail, recursively split those groups.

If no individual group fails, test interactions between groups before opening a repair.

No production code is changed by D7.
