# SW-RIB-TOP02 — static preservation audit

Date: 2026-10-01

Status: STATIC_AUDIT_PASS_EXECUTION_PENDING

Candidate:
`work/sw-rib-top02-external-head-candidate@e536cbf7cf163c0197d20104648afa4664d15520`

Baseline:
`integration/f-ci-canonical@0bf4bc0aec1d1f5d157ba6b4a88f0117c854bf6b`

## Delta audit

Production delta is exactly one file:

`src/solver/mod_b110_dynamic_top_boundary_provider.f90`.

The candidate was rebuilt from the exact canonical blob after an earlier
research patch was rejected during self-review. No deleted canonical
atmospheric/flux/ponding route remains in the candidate.

## Caller preservation

The new request members have default values:

- external supplied = false;
- external head = 0;
- external sill = 0.

Existing binders that copy a base request preserve the new fields automatically:

- PMdirect net-rain binding;
- PMdirect SWINTER0 surface-flux binding;
- RFM matrix-share rebinding.

Existing solver adapter constructs a default request and assigns the historical
fields; therefore external flooding remains disabled for all current callers.

The TIMEINT12 wrapper binds the unchanged solver-adapter API and therefore also
remains external-head inactive.

## ABI observation

The Fortran derived type layout changes. This is a source ABI change, but the
repository builds from source and no C/interoperable binary layout contract for
`b110_dynamic_top_boundary_request_t` is admitted. No public procedure
signature is changed.

## Route preservation argument

When `external_surface_water_head_supplied=.false.`, the only new physical
branch condition is false. Validation adds no condition in that state.
Therefore all existing executable route statements are reached with the same
historical inputs.

Executable bitwise/O0/O2 preservation remains required before admission.

## Flooding branch

The first production candidate deliberately compares external head against
`previous_ponding_depth_cm`, i.e. accepted local ponding at the interval
origin. It does not compare against Newton scratch.

This is transactionally stable and avoids route switching with nonlinear
candidate state.

Whether legacy semantics require comparison against a within-step evolving
ponding value remains an independent parity question. The bounded first
admission is explicitly an accepted-origin classifier.

## Static decision

`STATIC_PRODUCTION_DELTA_ACCEPTABLE_FOR_EXECUTABLE_QUALIFICATION`.

No canonical admission claim.
