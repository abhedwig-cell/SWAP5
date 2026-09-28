# F-PE-TIMEARCH10 preregistration — numerical-profile configuration seam

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@7e1d296055b56e561d17c5cd1aa7b4c533a26710`

Parent authority:

- TIMEARCH09 — DTMAX target role is optional expert safety ceiling;
- TIMEARCH09 — DTMIN target role is internal solver failure floor with optional expert override;
- TIMEARCH06-08 — production decision services, trace and shadow memory are available.

## Purpose

Introduce an explicit numerical-profile configuration contract without changing timestep execution.

Profiles:

1. `LEGACY_NUMERICS`
2. `AUTO_REFERENCE`

TIMEARCH10 does not implement a new automatic timestep controller.

## LEGACY_NUMERICS

Must be able to carry the current user-controlled values exactly:

- dtmin;
- dtmax;
- initial dt;
- NUMBIT_CRIT;
- MAXIT;
- accepted-step increase factor;
- accepted-step decrease factor;
- solver-failure reduction factor.

This profile is executable in principle because it maps to already-qualified current behavior.

## AUTO_REFERENCE

Represents the future normal-user configuration.

Required semantics:

- ordinary user dtmin not required;
- ordinary user dtmax not required;
- internal minimum retry duration owned by solver profile;
- optional expert safety ceiling may be present;
- controller implementation identifier is explicit;
- controller must remain disabled/unavailable until separately qualified.

TIMEARCH10 must fail closed if AUTO_REFERENCE is requested for execution before a controller is admitted.

## Contract requirements

- pure validation;
- no module-global mutable state;
- no parser change;
- no TimeControl behavior change;
- no implicit numerical defaults that could silently alter current execution;
- exact round-trip of legacy values;
- deterministic O0/O2 tests.

## Advancement

Advance only if:

- LEGACY_NUMERICS preserves arbitrary valid legacy parameter sets exactly;
- invalid legacy bounds fail validation;
- AUTO_REFERENCE can be represented without dtmin/dtmax user fields;
- AUTO_REFERENCE execution-readiness is false by default;
- optional expert ceiling is independent from the future preferred-step controller;
- no current production timestep code reads the new profile.

Possible result:

`QUALIFIED_NUMERICAL_PROFILE_CONFIGURATION_SEAM`
