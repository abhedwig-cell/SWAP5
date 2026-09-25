# F-AHL50 — controlled opt-in production admission

Date: 2026-09-25

Status: `PREREGISTERED_ADMISSION_RECONCILIATION`

Parent authority:
- F-AHL49 PR #619
- parent head: `491e5399ae09604341e3e3322eca8736d27b4f8e`
- F-AHL49 status: `READY_ADMISSION_CANDIDATE_OPT_IN`

## Purpose

F-AHL50 is an admission/integration work unit. It does not reopen the hydraulic representation design.

The candidate to preserve is the F-AHL49 direct-retention route:
- 128 intervals per decade over |h| = 1..1e6 cm;
- direct decade and interval indexing;
- cubic Hermite theta;
- C exactly from the derivative of the same interpolant;
- analytical K;
- analytical full-hydraulics route;
- analytical fallback outside the represented domain;
- shared immutable representation per exact homogeneous hydraulic authority;
- preprocessing acquire/build and prepared-slot solve binding;
- one active opt-in production application owner;
- default OFF.

## Admission envelope

Admission is bounded to:
- default B1.10 MvG;
- hydraulically homogeneous profile;
- bottom mode 5;
- SWKIMPL = 0;
- no tabulated hydraulics;
- no hysteresis;
- no KSATEXM.

Not admitted:
- prescribed qbot;
- mode 7;
- heterogeneous/layered authorities;
- SWKIMPL=1;
- KSATEXM;
- hysteresis;
- tabulated hydraulics;
- K lookup;
- default-on;
- practical/approximate tolerances.

## Admission invariants

F-AHL50 must preserve:
1. default-off behavior;
2. unsupported compositions fail closed;
3. F-AHL49 provider fidelity and derivative consistency;
4. accepted-trajectory directional response tangent consistency;
5. singleton application ownership and frozen immutable reads;
6. F-GC49D production application lifecycle;
7. inherited PPA-WU01 and FKT22 behavior;
8. no new physics and no tolerance relaxation.

## Repository reconciliation rule

The repository is authority.

The current canonical branch `integration/f-ci-canonical` is not assumed to be a valid direct merge target merely because it is named canonical. At preregistration it is an ancestor of the F-AHL49 line and is hundreds of commits behind the candidate production postimage.

Therefore F-AHL50 must first reconcile the actual integration authority before any canonical ref mutation or merge is attempted.

A wholesale 500+ commit admission under the name F-AHL50 is prohibited.

If the current canonical authority cannot accept the six-file F-AHL49 production delta without also requiring unadmitted intermediate production dependencies, F-AHL50 must stop at an explicit integration blocker rather than silently importing unrelated history.

## Candidate production delta

The F-AHL49 PR introduces or modifies these production files:
- `src/solver/mod_b110_direct_retention_core.f90`
- `src/solver/mod_b110_direct_retention_provider.f90`
- `src/runtime/mod_fmr_serialized_reference_backend.f90`
- `src/runtime/mod_fmr_production_application_bootstrap.f90`
- `src/solver/mod_reference_richards_temporal_indicator.f90`
- `src/adapter/mod_reference_richards_accepted_step_directional_service.f90`

F-AHL50 must determine whether these files form a self-contained admission delta against the actual integration authority. If not, the missing dependencies must be named and classified, not swept into the admission.

## Required gates before admission closure

At minimum:
- source-delta dependency reconciliation;
- default-off preservation;
- fail-closed envelope;
- provider extraction;
- 12-case production matrix;
- multi-application ownership;
- application scale;
- F-GC49D application opt-in including response tangent;
- PPA-WU01;
- FKT22 / parameter-configuration reuse;
- no unintended source-scope expansion.

## Decision states

Allowed outcomes:
- `READY_CANONICAL_OPT_IN_ADMISSION`
- `ADMITTED_OPT_IN_DEFAULT_OFF`
- `BLOCKED_INTEGRATION_AUTHORITY`
- `BLOCKED_ADMISSION_REGRESSION`

F-AHL50 must not use a successful F-AHL49 qualification run as proof that a different integration postimage is safe. Admission evidence must bind to the actual admission candidate.
