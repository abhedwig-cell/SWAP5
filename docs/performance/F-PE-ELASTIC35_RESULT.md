# F-PE-ELASTIC35 — row-interchange parser result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic35-row-interchange-parser`

Qualified postimage:
`e47de147122425bb0bcf2314ed82424559805557`

Workflow run:
`36589424009`

Job:
`109478308930`

Conclusion:
SUCCESS.

## Qualified seam

`SWAP5_ELASTIC33_BRO_ROWS_V1`
-> bounded application-side Fortran parser
-> exact `fmr_elastic_storage_bro_horizon_row_t(:)`
-> admitted ELASTIC22 composition.

No solver/runtime file discovery is introduced.

## Qualification

- A1 known valid interchange/header identity: PASS;
- A2 all 368 frozen profile interchanges parse in Fortran: PASS;
- A3 parsed rows total exactly 1568: PASS;
- A4 parsed binary64 source fields bit-identical to interchange values: PASS;
- A5 organic/peat 0/1 flags map exactly to Fortran logical fields: PASS;
- A6 wrong magic/hash/columns/count fail closed: PASS;
- A7 malformed width/profile/layer/geometry/density/flag and extra-record cases fail closed: PASS;
- A8 every valid parsed profile composes through admitted ELASTIC22 with source/layer identity preserved: PASS;
- A9 O0/O2 identity: PASS;
- A10 exact production source scope: PASS.

## Current canonical reconciliation

Current canonical:
`0e5a23f298fea93f7ec545ce8cbd1d49dfa0bbbb`.

The delta since the ELASTIC35 baseline is exclusively the separately owned,
canonically closed ELASTIC34 RD-point -> maparea preprocessing line. It does not
intersect ELASTIC35 parser source/tests/docs.

## Ownership boundary

ELASTIC35 owns only application-side parsing of an already materialized
ELASTIC33 interchange file.

It does not:
- discover the file path in the Richards runtime;
- parse GeoPackage data;
- perform coordinate/maparea selection;
- choose a profile;
- derive ELAS;
- request or bind generated priors.

## Decision

Classification:
`QUALIFIED_ADMISSION_CANDIDATE`.
