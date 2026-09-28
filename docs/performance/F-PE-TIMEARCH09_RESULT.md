# F-PE-TIMEARCH09 result — user DTMIN/DTMAX semantics

Date: 2026-09-28

Final status:

`QUALIFIED_USER_BOUND_DEMOTION_DESIGN`

Canonical authority:

`integration/f-ci-canonical@71b15a81a77c7e301fd6221bce990d85cd24b43f`

## Decision

DTMIN and DTMAX should not remain equal-status required numerical-tuning inputs for ordinary SWAP5 use.

They have different future roles.

## DTMAX

Recommended target semantics:

`OPTIONAL_EXPERT_SAFETY_CEILING`

not:

`PRIMARY_TIMESTEP_CONTROLLER`.

Reasoning:

- current DTMAX materially limits normal operation;
- Hupsel demonstrates that it can impose most of the daily step count structurally;
- safe local timestep size is state/process dependent;
- BOFEK work shows one static ceiling cannot represent wet-transition accuracy;
- the target architecture now has a separate proposal controller and hard-event scheduler seam.

A modern default should therefore select preferred dt automatically.

An optional DTMAX may remain during migration as:

- expert/debug safety ceiling;
- reproducibility control;
- legacy-profile parameter.

It should not be the main mechanism by which users achieve temporal accuracy.

## DTMIN

Recommended target semantics:

`INTERNAL_SOLVER_FAILURE_FLOOR_WITH_OPTIONAL_EXPERT_OVERRIDE`.

Reasoning:

- DTMIN is primarily used in retry/failure handling;
- it is rarely an active normal-step selector in the current BOFEK attribution bank;
- Hupsel uses a value four orders of magnitude below DTMAX;
- smaller steps are not guaranteed to improve convergence;
- the relevant policy is what to do when retry duration becomes numerically pathological, not a scientific minimum timestep chosen by the user.

The solver profile should own the normal floor and the action when it is reached:

- escalate/reject;
- report typed failure;
- optionally switch strategy;
- never silently interpret reaching DTMIN as acceptable accuracy.

## Ordinary user configuration target

Normal SWAP5 users should eventually select something closer to:

- accuracy / robustness profile;
- coupling/practical profile where explicitly supported;

rather than:

- DTMIN;
- DTMAX;
- NUMBIT_CRIT;
- growth factor;
- shrink factor;
- failure divisor.

Those remain advanced/legacy controls until replacement algorithms are qualified.

## Compatibility

Backward-compatible legacy inputs must remain readable for a transition period.

Proposed modes:

### LEGACY_NUMERICS

- existing DTMIN/DTMAX and legacy factors honored exactly;
- current behavior reproducible.

### AUTO_REFERENCE

- controller owns preferred dt;
- solver profile owns minimum retry duration;
- DTMAX is absent by default or treated only as optional ceiling;
- hard events remain exact and independent.

### PRACTICAL_COUPLING

Not admitted here.

May later use looser qualified temporal objectives without changing the architecture.

## What is not yet qualified

TIMEARCH09 does not provide the automatic controller itself.

Therefore it does not authorize removing DTMIN/DTMAX from the parser today.

The design is ready for a migration workunit that introduces explicit numerical profiles while keeping LEGACY_NUMERICS exact.

## Required successor

`F-PE-TIMEARCH10 — numerical-profile configuration seam`

TIMEARCH10 should:

1. define explicit LEGACY_NUMERICS and AUTO_REFERENCE configuration contracts;
2. keep AUTO_REFERENCE disabled/default-off until a controller is qualified;
3. prove legacy input maps exactly to current runtime values;
4. prove ordinary automatic mode can exist without requiring user DTMIN/DTMAX fields at the internal contract level;
5. keep current parser backward-compatible.

No automatic timestep algorithm should be invented inside the configuration workunit.
