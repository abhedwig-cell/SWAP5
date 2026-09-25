# F-AHL50 — controlled opt-in production admission closeout

Date: 2026-09-25

Status: `READY_CANONICAL_OPT_IN_ADMISSION`

PR: #620

Qualification head: `d59f05167486b73573360246c546ccc795069fd2`

Production base: `work/f-pe-planvalid01@df664f56cf09ee8479701f15fe10ee02d31a9536`

Qualified source authority: F-AHL49 PR #619.

## Verdict

The F-AHL49 direct-retention architecture has been re-extracted as a bounded production admission delta and independently requalified on the clean admission postimage.

`F-AHL50 = READY_CANONICAL_OPT_IN_ADMISSION`

This does not make the feature default-on.

## Source scope

Relative to the production base, the production delta is limited to six files:

- `src/solver/mod_b110_direct_retention_core.f90`;
- `src/solver/mod_b110_direct_retention_provider.f90`;
- `src/runtime/mod_fmr_serialized_reference_backend.f90`;
- `src/runtime/mod_fmr_production_application_bootstrap.f90`;
- `src/solver/mod_reference_richards_temporal_indicator.f90`;
- `src/adapter/mod_reference_richards_accepted_step_directional_service.f90`.

No wholesale F-AHL47/F-AHL48/F-AHL49 research history is part of the admission delta.

## Preserved architecture

- 128 intervals per decade over |h| = 1..1e6 cm;
- direct decade and interval indexing;
- cubic Hermite theta;
- C is the exact derivative of the same interpolant;
- K remains analytical;
- full-hydraulics evaluation remains analytical;
- analytical fallback outside the represented domain;
- one shared immutable representation per exact homogeneous hydraulic authority;
- acquire/build during preprocessing;
- prepared slot only in the solve hot path;
- one active opt-in production application owner;
- pool frozen before execution;
- second simultaneous opt-in owner fails closed;
- default OFF.

## Admission qualification

On the qualification head:

- provider admission: PASS;
- 12-case B01/B12/O05/O14 x wet/mid/dry fidelity/path matrix: PASS 12/12;
- production provider timing matrix: PASS, 12/12 speed-positive;
- median candidate/analytical solver ratio: `0.850510209`;
- minimum case ratio: `0.812673399`;
- maximum case ratio: `0.875859184`;
- median solver reduction on this admission run: approximately 14.95%;
- application scale: PASS;
- N=10,000 median initialization ratio: `1.027460134`, approximately 2.75% setup overhead;
- multi-application ownership: PASS;
- fail-closed envelope: PASS;
- default-off preservation: PASS;
- F-GC49D application opt-in including directional response tangent: PASS;
- inherited PPA-WU01 production application bootstrap: PASS;
- inherited parameter-configuration reuse / FKT22 serialized runtime: PASS.

The first F-AHL50 matrix run failed only because the clean extraction omitted the F-AHL47 timing fixture consumed by the matrix runner. The fixture was added without production-code changes; the rerun passed.

## Envelope

Admitted candidate envelope remains:

- default B1.10 MvG;
- hydraulically homogeneous profile;
- bottom mode 5;
- SWKIMPL = 0;
- no tabulated hydraulics;
- no hysteresis;
- no KSATEXM.

Still excluded:

- prescribed qbot;
- mode 7;
- heterogeneous/layered hydraulic authorities;
- SWKIMPL=1;
- KSATEXM;
- hysteresis;
- tabulated hydraulics;
- K lookup;
- default-on activation;
- practical/approximate tolerances.

## Canonical governance boundary

The repository branch named `integration/f-ci-canonical` is an ancestor hundreds of commits behind the production postimage used for F-AHL49/F-AHL50.

The generic F-CI current-restricted preservation gate fails on the clean admission candidate because it detects pre-existing admitted-postimage drift in `src/transaction/mod_transaction_reference.f90`. That file is not changed by F-AHL50.

Therefore F-AHL50 does not move or merge the canonical ref itself. Doing so from this work unit would either admit hundreds of unrelated commits or require choosing a newer integration authority that is outside F-AHL50 ownership.

The correct status is readiness for bounded canonical integration, with the actual canonical/integration authority to be reconciled by the canonical governance line.

## Decision

`F-AHL50 = READY_CANONICAL_OPT_IN_ADMISSION`

The candidate is technically qualified for opt-in, default-OFF admission. Canonical ref mutation is a separate governance action, not a remaining hydraulic or production-qualification task.
