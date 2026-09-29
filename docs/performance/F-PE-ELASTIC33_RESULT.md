# F-PE-ELASTIC33 — profile-row interchange result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic33-profile-row-interchange`

Qualified postimage:
`de2e86e0f42d514e23c88aa2a7c34ed09b6b33ef`

Workflow run:
`36588014529`

Job:
`109473420341`

Conclusion:
SUCCESS.

## Qualified seam

`swap5.elastic24.bro-profile.v1`
-> validated frozen source profile
-> exact ELASTIC22-shaped source rows
-> line-oriented `SWAP5_ELASTIC33_BRO_ROWS_V1` interchange.

No `src/**` production source changes are part of ELASTIC33.

## Qualification

- A1 exact ELASTIC24 schema/source-hash gate: PASS;
- A2 field-for-field ELASTIC22 row mapping: PASS;
- A3 binary64 round-trip identity through 17-digit serialization: PASS;
- A4 organic-matter availability/null projection: PASS;
- A5 peat-type presence projection: PASS;
- A6 wrong schema/source/count fail closed: PASS;
- A7 malformed order/geometry/source data fail closed: PASS;
- A8 repeated materialization byte-identical: PASS;
- A9 all 368 frozen profiles materialize: PASS;
- A9 total transformed rows = 1568: PASS;
- A9 generated Fortran fixture composes through admitted ELASTIC22 at O0 and O2: PASS;
- A9 O0/O2 output identity: PASS;
- A10 zero `src/**` production-source scope: PASS.

## First-run adjudication

The first qualification run failed only because the test incorrectly required
the frozen dataset itself to contain both NULL and non-NULL organic-matter
examples.

That requirement was not preregistered and is not a source-contract property.
The test was corrected to exercise both NULL semantics with synthetic
ELASTIC24-valid records while all frozen source rows remain tested unchanged.

No production/tool semantics changed in that repair.

## Current canonical reconciliation

Current canonical:
`ea44fa14a48c913e15b50039a7ebd89e95f74567`.

The delta since the ELASTIC33 baseline contains only the separately owned
ELASTIC32 spatial-source audit tooling/tests/docs and does not intersect the
ELASTIC33 interchange surface.

## Admission boundary

A green ELASTIC33 admits only deterministic offline interchange materialization.

Still outside:
- Fortran file parsing of the interchange into
  `fmr_elastic_storage_bro_horizon_row_t(:)`;
- spatial location -> maparea selection;
- automatic profile choice;
- runtime source I/O.

## Decision

Classification:
`QUALIFIED_ADMISSION_CANDIDATE`.
