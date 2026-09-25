# F-AHL50 — canonical integration handoff

Date: 2026-09-25

F-AHL50 technical status: `READY_CANONICAL_OPT_IN_ADMISSION`

Candidate PR: #620

Candidate head: `2173a05d4a008e86a8b2eea0b0a5022b5d68dbe5`

Qualification evidence head: `d59f05167486b73573360246c546ccc795069fd2`

## Handoff decision

F-AHL50 is technically closed. No further hydraulic representation work is required for admission.

The remaining action is canonical governance reconciliation.

Do not merge PR #620 directly into `integration/f-ci-canonical` in its current form.

Repository comparison shows the F-AHL50 branch is 425 commits ahead of `integration/f-ci-canonical`, with merge base `506c36aab6f84b74dffdf5c37fe572c1e0b46610`. A direct merge would therefore carry the entire intervening production/performance lineage, not merely the bounded F-AHL50 capability.

## Why the six-file candidate is still valid

Relative to its production authority `work/f-pe-planvalid01@df664f56cf09ee8479701f15fe10ee02d31a9536`, F-AHL50 changes exactly six production files:

- `src/solver/mod_b110_direct_retention_core.f90`;
- `src/solver/mod_b110_direct_retention_provider.f90`;
- `src/runtime/mod_fmr_serialized_reference_backend.f90`;
- `src/runtime/mod_fmr_production_application_bootstrap.f90`;
- `src/solver/mod_reference_richards_temporal_indicator.f90`;
- `src/adapter/mod_reference_richards_accepted_step_directional_service.f90`.

All bounded F-AHL50 admission gates pass on the clean admission postimage.

## Canonical authority discrepancy

PR #598 records that PR #593 was merged into `integration/f-ci-canonical` and identifies merge commit `506c36aab6f84b74dffdf5c37fe572c1e0b46610`.

The performance lineage used by F-AHL50 starts after that authority and is itself hundreds of commits ahead. The generic current-restricted canonical preservation job also reports admitted-postimage drift in `src/transaction/mod_transaction_reference.f90`, which F-AHL50 does not modify.

This is a canonical-governance lineage issue, not an F-AHL50 numerical or production defect.

## Required canonical-governance action

The canonical governance owner should:

1. identify the current intended production integration authority after `506c36a...`;
2. reconcile which intervening exact performance admissions, including F-PE-ZERO-WASTE01 and F-PE-PLANVALID01, are intended to become canonical;
3. recompose the six-file F-AHL50 delta on that authority rather than merging the 425-commit branch wholesale;
4. replay the F-AHL50 admission suite on the recomposed canonical candidate;
5. preserve default OFF and the exact bounded envelope;
6. only then merge/admit the candidate to `integration/f-ci-canonical`.

## Frozen F-AHL50 contract

Admission must remain opt-in and default OFF.

Qualified envelope:
- default B1.10 MvG;
- homogeneous hydraulic profile;
- bottom mode 5;
- SWKIMPL=0;
- no tabulated hydraulics;
- no hysteresis;
- no KSATEXM.

No qbot, mode 7, layered authorities, SWKIMPL=1, KSATEXM, hysteresis, tabulated hydraulics, K lookup, default-on behavior or approximate tolerances may be introduced by the canonical recomposition.

## Closure

`F-AHL50 = READY_CANONICAL_OPT_IN_ADMISSION`

`CANONICAL_REF_MUTATION = DEFERRED_TO_CANONICAL_GOVERNANCE_RECOMPOSITION`

The next work unit is not F-AHL51 representation research. It is a canonical-governance recomposition/admission unit consuming this handoff.
