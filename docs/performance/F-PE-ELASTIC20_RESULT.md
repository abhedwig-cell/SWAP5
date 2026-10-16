# F-PE-ELASTIC20 — immutable Staringreeks 2018 catalog result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic20-current-clean-admission-v2`

Qualified clean postimage:
`883575d55b0e2574b10cade028cb5dc5a011337b`

Current-canonical extraction base:
`integration/f-ci-canonical@69f10afaff5781ee4980dee3f1e63c898a0f4b4b`

Workflow run:
`36563658270`

Job:
`109390268359`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/adapter/mod_fmr_elastic_storage_staringreeks_catalog.f90`.

No existing production source is modified.

The adapter performs immutable lookup only:

`B01..B18/O01..O18`
-> exact frozen 2018 `wcr,wcs,alpha,npar`
-> admitted ELASTIC19 retention type.

No runtime file I/O, profile selection, BOFEK/BRO lookup, ELAS computation or
solver policy is introduced.

## Source authority

Official source:
`https://nhi.nu/documents/224/staringreeks_1.0.0.zip`

Official zip SHA-256:
`9d06dff19392111dad110802058e3894c30355f553842ce32d89eed005071cd5`

Exact member:
`staringreeks/Data/staringreeks_2018.csv`

Member SHA-256:
`ed2e47bcacdbb6e5fe18eb4f712c3ead996f26f97d647fa550dafd8683d64494`

Exact material set:
36 records, ordered `B01..B18,O01..O18`.

## Qualification

- A1 all 36 exact codes resolve successfully in frozen order: PASS.
- A2 all returned `wcr,wcs,alpha,npar` values are bit-identical to the independent oracle table: PASS.
- A3 B01 and O18 endpoint values/indices: PASS.
- A4 malformed/unsupported codes fail closed with no fallback: PASS.
- A5 admitted ELASTIC19 composition identity: PASS.
- A6 all 36 records produce finite ELASTIC19 theta(-100 cm) within [wcr,wcs]: PASS.
- A7 O0/O2 identity: PASS.
- A8 production source scope: PASS.

## Admission meaning

A green ELASTIC20 admits only immutable Staringreeks 2018 code-to-retention
lookup.

Still outside scope:
- BOFEK/BRO profile retrieval;
- source horizon to Staringreeks-code association;
- location/profile selection;
- input-file syntax;
- alternate Staringreeks years;
- automatic generated-prior request.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
