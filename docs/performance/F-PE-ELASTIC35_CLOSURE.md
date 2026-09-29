# F-PE-ELASTIC35 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@1d1913723626a4a6c5ae4092c477502e6ad0e434`

Merged PR:
`#868`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_row_interchange_file_adapter.f90`

Admitted production blob:
`43af25ce1333fb00137e888c1cc0b55582491c78`

## Admission summary

F-PE-ELASTIC35 admits bounded application-side Fortran parsing of the admitted
ELASTIC33 interchange into exact ELASTIC22
`fmr_elastic_storage_bro_horizon_row_t(:)` values.

The Richards runtime does not discover or open this file.

## Qualification authority

Qualified branch:
`work/f-pe-elastic35-row-interchange-parser`.

Qualified postimage:
`e47de147122425bb0bcf2314ed82424559805557`.

Result-document head:
`c4ea2cb095635766efd786bc2f1c3ff2671c4728`.

Qualification:
- workflow run `36589424009`;
- job `109478308930`;
- conclusion SUCCESS.

Passed:
- all 368 frozen profile interchanges parsed in Fortran;
- 1568 total rows;
- binary64 identity;
- logical flag identity;
- wrong magic/hash/columns/count fail closed;
- malformed width/profile/layer/geometry/density/flag fail closed;
- unexpected extra record fail closed;
- all valid parsed profiles compose through ELASTIC22;
- O0/O2 identity;
- exact production source scope.

## Ownership semantics

ELASTIC35 owns only parsing of an already selected/materialized interchange file.

It does not:
- discover the interchange path from the solver;
- parse the source GeoPackage;
- select a maparea or profile;
- derive ELAS;
- activate generated priors.

## Current source chain

frozen BRO GeoPackage
-> ELASTIC24 explicit-profile retrieval
-> ELASTIC33 deterministic row interchange
-> ELASTIC35 bounded Fortran row parser
-> ELASTIC22 exact profile/source-horizon assembly
-> ELASTIC21/20/19 descriptor source chain
-> ELASTIC18/17 grid mapping
-> ELASTIC16 generated-prior assembly
-> ELASTIC25/15 explicit request and binding
-> existing ELAS runtime.

Spatial selection remains a separate preprocessing concern.

## Remaining boundary

Still external:
- coordinate/location -> maparea selection;
- automatic maparea/profile orchestration;
- selection policy when spatial input is ambiguous or outside the source domain;
- runtime/solver source-file discovery.

## Closure

F-PE-ELASTIC35 is canonically admitted and closed.
