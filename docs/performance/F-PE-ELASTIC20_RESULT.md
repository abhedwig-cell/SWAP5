# F-PE-ELASTIC20 — immutable Staringreeks 2018 catalog result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic20-staringreeks-catalog`

Qualified postimage:
`1bdcc8e6021a32de475a97f27056c10f6a8eb187`

Workflow run:
`36562991630`

Job:
`109388068907`

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

## A1 all-code resolution

All 36 exact codes resolve successfully and return their frozen catalog index.

PASS.

## A2 source value bit identity

For every catalog record:
- `wcr`;
- `wcs`;
- `alpha`;
- `npar`

are bit-identical to the independent oracle table transcribed from the
validated repository mirror.

PASS.

## A3 endpoint checks

B01 and O18 exact source values and indices match the frozen authority.

PASS.

## A4 invalid-code fail closed

Rejected without fallback:
- B00;
- B19;
- O00;
- O19;
- lowercase code;
- leading-space code;
- empty code;
- numeric-only code.

No nearest material, case folding or historical-series fallback occurs.

PASS.

## A5 ELASTIC19 composition identity

A catalog-resolved B01 retention record passed through the admitted ELASTIC19
horizon builder and produced the exact same reference-state theta/regime as a
manually constructed retention record containing the same source values.

PASS.

## A6 all-record reference-state validity

All 36 catalog records produce finite ELASTIC19 `theta(-100 cm)` values within
their own `[wcr,wcs]` interval.

PASS.

## A7 O0/O2 identity

The complete focused oracle output is identical at O0 and O2.

PASS.

## A8 source scope

Production delta is exactly:

`src/adapter/mod_fmr_elastic_storage_staringreeks_catalog.f90`.

No runtime/kernel/solver/legacy production source changes.

PASS.

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
