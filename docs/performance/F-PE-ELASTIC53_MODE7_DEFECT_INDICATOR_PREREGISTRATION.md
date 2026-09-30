# F-PE-ELASTIC53 — bottom-mode-7 defect-indicator feasibility preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent:
`F-PE-ELASTIC52 — QUALIFIED_ACTIVE_ELAS_INTERNAL_FLUX_TRAJECTORY_SPLIT`

Parent postimage:
`research/f-pe-elastic52-top-node-mechanism@c0f120e60e9b9ae914d567e784be196f300bead2`

Canonical at start:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Question

Can the existing Reference Richards defect-based temporal indicator be extended
mathematically to the qualified bottom-mode-7, swkimpl=0 route without changing
production source or acceptance policy?

## Existing authority

F-SI38 establishes:
- bottom mode 2 prescribed-qbot uses a Neumann defect operator with no bottom
  stiffness;
- bottom mode 5 prescribed-head adds the Dirichlet bottom stiffness;
- all other bottom modes currently fail closed.

For production HeadCalc:
- bottom mode 7 uses free drainage `qbot=-K_N`;
- with `swkimpl=0`, the production Jacobian does not add a dK/dh bottom
  stiffness term.

## Research hypothesis

For the specific envelope:
- bottom mode 7;
- swkimpl=0;
- fixed-flux top boundary;
- no macropores;
- admitted default-MvG provider;

a defect operator with zero added bottom stiffness is consistent with the
production linearization.

This is not an admission claim for swkimpl=1 or other bottom modes.

## Tests

1. Materialize a research-only copy of
   `mod_reference_richards_temporal_indicator.f90` that admits bottom mode 7
   while preserving the mode-5-only stiffness addition.
2. Verify source patch scope is exactly the boundary-envelope condition and a
   research route label.
3. Run an independent mode-7 oracle analogous to F-SI38:
   - principal solve converges;
   - indicator uses one tridiagonal defect solve and no extra nonlinear solve;
   - independent zero-bottom-stiffness operator reproduces raw, defect, bounded
     and Binf outputs.
4. Apply the research indicator to the frozen ELASTIC50/52 real-profile bank
   with previous-right-derivative fixed to zero, representing the perturbation
   from the preceding equilibrium state.
5. Compare indicator Binf against actual full-versus-two-half H_INF where all
   three trajectories converge.

## Falsification criteria

Falsify this extension if any of the following occurs:
- independent oracle mismatch;
- nonfinite or negative indicator;
- candidate mutation;
- O0/O2 semantic drift;
- indicator unavailable/failed in the declared envelope;
- mode-7 operator requires an unmodeled bottom stiffness under swkimpl=0.

## Non-claims

ELASTIC53 does not:
- modify production source;
- change the current identity temporal gate;
- choose a tolerance;
- admit mode 7;
- cover swkimpl=1;
- claim Binf is already a calibrated acceptance threshold.

## Decision

A positive result qualifies only a research candidate for subsequent
calibration/falsification.
