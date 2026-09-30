# F-PE-ELASTIC59 — bottom-mode-7 typed mass publication preregistration

Date: 2026-09-30

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Trigger:
`F-PE-ELASTIC58 — QUALIFIED_MODE7_TYPED_MASS_PUBLICATION_BLOCKER`.

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`.

## Purpose

Add the smallest missing Reference-binding publication seam for accepted
bottom-mode-7 free-drainage solves.

Current canonical publishes typed accepted-solve mass diagnostics for bottom
modes 2 and 5:

- `native_balance_rate_residual_available`;
- `native_balance_rate_residual_cm_per_day`;
- `integrated_mass_balance_residual_available`;
- `integrated_mass_balance_residual_cm`.

Bottom mode 7 currently leaves those typed fields unavailable even when the
Reference solve converges.

ELASTIC59 adds the same typed publication contract for bottom mode 7 only.

## Physical authority

For an accepted mode-7 HeadCalc solve:

- HeadCalc computes free-drainage bottom flux as
  `qbot = -K_N`;
- the final exact compartment residual vector is already present in
  Reference worker scratch;
- the native total balance-rate residual is the exact sum of that final
  compartment residual vector;
- the integrated equation-balance residual is
  `dt * native_balance_rate_residual`.

No residual is recomputed from rounded published state.

No flux sign is changed.

No bottom flux is prescribed by the caller.

## Production scope

Expected production delta:

`src/adapter/mod_reference_richards_legacy_binding.f90`

only.

No solver equation, HeadCalc, constitutive model, Jacobian, retry rule, temporal
policy, mass tolerance, or boundary semantics may change.

## Publication rule

When:

- `request%boundary%bottom_mode == 7`;
- HeadCalc has not requested dt reduction;
- worker control has not requested dt reduction;

publish:

`result%unrounded_mass_balance_residual = sum(ws%richards%residual(1:n))`

`result%native_balance_rate_residual_available = .true.`

`result%native_balance_rate_residual_cm_per_day =
 result%unrounded_mass_balance_residual`

`result%integrated_mass_balance_residual_available = .true.`

`result%integrated_mass_balance_residual_cm =
 request%step_duration * result%unrounded_mass_balance_residual`.

On retry/failure, preserve fail-closed unavailable semantics.

## Qualification matrix

A1. Mode-7 equilibrium and signed perturbation cases converge where expected and
publish both typed residuals.

A2. Typed native residual is bit-identical to the exact sum of the final
HeadCalc compartment residual vector captured by an independent research
oracle.

A3. Typed integrated residual is bit-identical to
`dt * native_balance_rate_residual`.

A4. Independent physical interval ledger using published start/end storage,
published top flux and published free-drainage bottom flux closes within the
hard mass tolerance on converged cases.

A5. Published mode-7 bottom flux remains the exact solver-owned free-drainage
output and is not overwritten by the caller request field.

A6. Retry/nonconverged mode-7 result does not claim typed mass availability.

A7. Existing F-SI38 mode-2 prescribed-qbot typed contract replays unchanged.

A8. Existing F-SI25/F-SI38 mode-5 prescribed-head temporal/mass semantics replay
unchanged.

A9. O0/O2 semantic identity.

A10. Production source scope is exactly one existing Reference binding file.

## Admission boundary

A green ELASTIC59 admits only typed mass publication for accepted
bottom-mode-7 Reference solves.

It does not admit:
- a mode-7 temporal budget;
- mode-7 defect-indicator production use;
- C-SAFE production integration;
- ELAS defaults;
- swkimpl=1 defect semantics;
- any new numerical tolerance.

After ELASTIC59 qualification, the unchanged ELASTIC58 Reference-only budget
calibration may be replayed as a separate workunit.
