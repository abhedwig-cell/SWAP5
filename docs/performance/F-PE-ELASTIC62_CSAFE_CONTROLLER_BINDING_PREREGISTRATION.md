# F-PE-ELASTIC62 — mode-7 C-SAFE runtime binding preregistration

Date: 2026-09-30

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Canonical baseline:
`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

Parent production authority:
- F-PE-ELASTIC59: mode-7 typed mass publication admitted;
- F-PE-ELASTIC60: mode-7 swkimpl=0 Richards defect indicator admitted;
- F-PE-ELASTIC61: conservative mode-7 head-error envelope admitted.

Research authority:
- ELASTIC55: frozen global envelope survived 801 multi-profile paired cases;
- ELASTIC56: localized indicator nonmonotonicity;
- ELASTIC57: refine-until-passing controller pattern remains correct without
  monotonicity assumptions.

## Purpose

Bind the admitted mode-7 conservative head-error envelope to the already
existing model-certificate transaction path.

This workunit does not add a new transaction algorithm.

The generic transaction core already owns:
- mass-first acceptance;
- model-certificate validation;
- rollback;
- retry with caller-configured retry scale;
- retry exhaustion;
- commit only after mass and temporal acceptance.

ELASTIC62 changes only how a qualified mode-7 defect indicator is normalized
against the explicit caller-owned budget.

## Current gap

The serialized Reference runtime currently computes:

`normalized_indicator = head_inf_bound / model_temporal_indicator_budget`

for every model-certificate route.

For admitted mode 7 this bypasses the canonically admitted ELASTIC61 physical
mapping:

`estimated_head_error = alpha * head_inf_bound`

with

`alpha = 0.17320259355765216`.

## Frozen binding

For:
- Reference solver;
- bottom mode 7;
- swkimpl=0;
- available admitted defect indicator;
- explicit positive finite caller budget;

the runtime must call the admitted
`assess_fmr_mode7_temporal_head_envelope` adapter and publish its
`normalized_error` as the transaction temporal indicator.

Modes 2 and 5 preserve the existing direct raw-indicator/budget semantics.

No default budget is introduced.

## Fail-closed behavior

For mode 7:
- absent budget: certificate unavailable, reason remains
  `budget-not-supplied`;
- invalid/nonpositive budget: certificate unavailable, reason remains
  `budget-invalid`;
- unavailable/invalid indicator: certificate unavailable;
- swkimpl=1: indicator remains unavailable through the existing solver gate;
- incomplete/invalid envelope assessment: certificate unavailable.

The transaction core then performs its existing rollback/retry behavior.

## Mass ownership

Hard mass acceptance remains before temporal certificate acceptance.

ELASTIC62 must not:
- change mass tolerance;
- change typed mass publication;
- change missing-contribution semantics;
- permit temporal acceptance to bypass a mass rejection.

## Architecture invariants

Preserved:
- invariant 7: transactional timesteps;
- invariant 13: mass conservation;
- invariant 23: physical options separate from numerical/execution policy;
- invariant 25: Full Richards Reference remains available;
- invariant 26: diagnostics remain observational.

## Expected production scope

Exactly one existing production file:

`src/runtime/mod_fmr_serialized_reference_backend.f90`.

No solver, HeadCalc, transaction-core, canonical-config, constitutive or
boundary source may change.

## Qualification

A1. Exact production source scope is the serialized Reference runtime only.

A2. Mode 7 uses exact ELASTIC61 alpha normalization:
`normalized = alpha * Binf / explicit_head_budget`.

A3. Below/equal/above threshold behavior matches the admitted ELASTIC61 adapter.

A4. Missing budget fails closed and cannot commit through the model-certificate
route.

A5. Invalid/nonpositive budget fails closed.

A6. Hard mass rejection occurs before temporal acceptance and remains
unmodified.

A7. Retry semantics use only the observed current certificate and existing
transaction retry policy; no monotonicity prediction is introduced.

A8. Mode-7 swkimpl=1 remains unavailable.

A9. Mode 2 and mode 5 existing model-certificate normalization semantics are
preserved.

A10. Accepted mode-7 certificate route commits only after both mass and
normalized temporal acceptance pass.

A11. O0/O2 semantic identity.

A12. Existing ELASTIC59/60/61 production preservation gates remain green.

## Admission boundary

A green ELASTIC62 admits only:

`mode7 admitted defect indicator
 + admitted conservative alpha envelope
 + explicit caller-owned positive head budget
 -> existing mass-first model-certificate retry/accept transaction path`.

It does not admit:
- a default physical head budget;
- a complete F-CI14 numeric profile;
- swkimpl=1;
- default-on temporal control;
- mass-gate relaxation;
- a new timestep-control algorithm.
