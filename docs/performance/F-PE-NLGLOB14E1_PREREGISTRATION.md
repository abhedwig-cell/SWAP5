# F-PE-NLGLOB14E1 preregistration — saturation-root observability correction

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent authority:

- NLGLOB14D: `QUALIFIED_PERSISTENT_SATURATED_TEMPORAL_MODE_RESEARCH`;
- NLGLOB14E numerical full-bank outcome: 96/96 complete, mass/finite/smooth gates pass;
- NLGLOB14E current blocker: `BLOCKED_NLGLOB14E_DIAGNOSTIC_OBSERVABILITY`.

Parent branch authority:

`research/f-pe-nlglob14e-full-dynamic-policy@93187c49d4f28147e202bbe3986dccecdda495aa`

Current canonical checked before preregistration:

`integration/f-ci-canonical@7b34fb5a980b647423d8c5062d0ec64f0568e0f7`

## Purpose

NLGLOB14E1 corrects only the observability defect in the NLGLOB14E qualification harness.

The assembled NLGLOB14C materializer replaces the successful NLGLOB14A root-success log with the later switch diagnostic. Therefore `root_count == 1` is not observable in the final assembled executable even when exactly one successful saturation event occurred.

NLGLOB14E1 must prove the frozen semantic gate directly:

**after persistent saturated-mode entry, no trajectory may start saturation-event root localization again.**

No solver, state-machine, mass, timestep, provider, route, acceptance or temporal behavior may change.

## Frozen instrumentation

In the assembled research driver, emit a diagnostic exactly when a saturation-root localization attempt starts, after the ordinary TG trial has detected accepted-state saturation crossing and immediately before bracket construction:

`F_PE_NLGLOB14E1_ROOT_ATTEMPT|STEP=<n>`

This diagnostic must be placed downstream of the NLGLOB14D persistent-mode early return.

Therefore a root-attempt diagnostic emitted on a step later than saturated-mode entry would directly demonstrate semantic re-entry.

No diagnostic may modify state.

## Frozen bank

Reuse the exact NLGLOB14E postimage and full 96-case bank unchanged.

Also rerun the original smooth TIMEINT16C bank unchanged.

## Frozen diagnostic gate

For every trajectory:

1. saturated-mode entry count is either 0 or 1;
2. each successful saturated-mode entry has exactly one successful NLGLOB14C switch;
3. all persistent saturated-mode interval diagnostics report successful KLAG execution;
4. if an entry occurs at step `s_entry`, every root-attempt diagnostic satisfies:
   `step <= s_entry`;
5. no root-attempt diagnostic occurs on any later persistent saturated-mode interval;
6. no trajectory without saturation entry is required to emit a root-attempt diagnostic.

No count of the replaced NLGLOB14A root-success log is used.

## Full qualification gates

Classify:

`QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY`

only if:

- the unchanged NLGLOB14E numerical gates still pass:
  - 96/96 process execution;
  - 96/96 horizon completion;
  - finite states;
  - route/state admissibility;
  - physical interval and cumulative ledgers <= `5e-8 cm`;
  - no predictor-domain, root-bracket, event-remainder or persistent-mode terminal failure;
- smooth second-order gates still pass;
- the corrected diagnostic gate above passes for all 96 trajectories.

If numerical gates pass but corrected observability does not:

`BLOCKED_NLGLOB14E1_ROOT_OBSERVABILITY`.

If any numerical/safety gate regresses:

use the corresponding frozen NLGLOB14E negative classification.

## Consequence

A positive result closes the frozen same-route dynamic-top endpoint blocker at research level.

It authorizes reopening TIMEINT17 same-route qualification with the assembled policy and then proceeding to explicit saturated-mode release semantics.

No production admission follows automatically.

## Stop rule

Do not alter the state machine to make the diagnostic pass.

Do not infer root attempts from missing/replaced logs.

Do not change any physical or numerical threshold.

## Production boundary

Diagnostic-only research qualification.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
