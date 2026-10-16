# F-PE-ELASTIC33 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@268be8cece54401945c092b8bce3a996b6499230`

Merged PR:
`#863`

Admitted preprocessing file:
`tools/fpe_elastic33_profile_row_interchange.py`

Admitted file blob:
`053a169e9a66c8224b9e3dcf7689a11e7db919dc`

## Admission summary

F-PE-ELASTIC33 admits deterministic offline conversion of one admitted
ELASTIC24 profile JSON artifact into the exact nine-field ELASTIC22 row
interchange:

`swap5.elastic24.bro-profile.v1`
-> `SWAP5_ELASTIC33_BRO_ROWS_V1`.

No `src/**` production source changes are part of ELASTIC33.

## Qualification authority

Qualified branch:
`work/f-pe-elastic33-profile-row-interchange`.

Qualified postimage:
`de2e86e0f42d514e23c88aa2a7c34ed09b6b33ef`.

Result-document head:
`aa61fb12499ebc0d8c50e1532581a5b201b58015`.

Qualification:
- workflow run `36588014529`;
- job `109473420341`;
- conclusion SUCCESS.

Passed:
- exact source schema/hash gate;
- all 368 frozen profiles;
- all 1568 transformed rows;
- field identity;
- binary64 round-trip identity;
- organic-matter availability projection;
- peat-type presence projection;
- malformed schema/source/order/geometry fail closed;
- byte-identical repeated materialization;
- generated Fortran fixture composition through ELASTIC22 at O0 and O2;
- zero production-source scope.

## Ownership semantics

ELASTIC33 owns only the offline interchange materialization.

It does not:
- parse the interchange into Fortran row objects;
- perform spatial selection;
- choose a profile;
- retrieve network data;
- derive ELAS;
- activate generated priors.

## Remaining boundary

Still external:
- bounded Fortran/application parsing of the interchange into
  `fmr_elastic_storage_bro_horizon_row_t(:)`;
- location/coordinate -> maparea selection;
- automatic profile choice;
- runtime source I/O.

## Closure

F-PE-ELASTIC33 is canonically admitted and closed.
