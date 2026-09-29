# F-PE-ELASTIC21 — BRO Staringreeks-block association result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic21-bro-block-association`

Qualified postimage:
`b8d29dad07e6b8f03f4898e2c65040e195d72642`

Workflow run:
`36564543066`

Job:
`109393164069`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/adapter/mod_fmr_elastic_storage_bro_block_association.f90`.

No existing production source is modified.

The adapter performs only the qualified source association:

- BRO 101..118 -> Staringreeks B01..B18;
- BRO 201..218 -> Staringreeks O01..O18.

The exact final three-character code is obtained from admitted ELASTIC20.

## Source authority

ELASTIC12A5 qualified:
- 368 / 368 BOFEK profiles;
- 1568 / 1568 source layers;
- identical BOFEK layer sequence/depth and BRO horizon sequence/depth;
- identical BOFEK Staringreeks coding and BRO `staringseriesblock`.

Frozen encoding:
- 101..118 -> B01..B18;
- 201..218 -> O01..O18.

## A1 topsoil B family

All 18 source blocks 101..118 map exactly to B01..B18.

PASS.

## A2 subsoil O family

All 18 source blocks 201..218 map exactly to O01..O18.

PASS.

## A3 catalog index identity

Returned ELASTIC20 catalog indices are exactly:
- B family -> 1..18;
- O family -> 19..36.

PASS.

## A4 invalid block fail closed

Rejected with blank/zero outputs:
- 0;
- 100;
- 119;
- 120;
- 199;
- 200;
- 219;
- negative integer;
- unrelated large integer.

No nearest-block, modulo or range-wrapping fallback occurs.

PASS.

## A5 ELASTIC20 composition

Every valid source block maps to a code that resolves successfully through the
admitted immutable Staringreeks 2018 catalog at the exact corresponding catalog
index.

PASS.

## A6 ELASTIC19 composition

Representative endpoints:
- 101 -> B01;
- 218 -> O18;

produce retention records and source-horizon descriptors bit-identical to
direct lookup of B01 and O18.

PASS.

## A7 family separation

The B/O family boundary is preserved exactly:
- 118 remains B18;
- 201 remains O01.

No family collapse occurs.

PASS.

## A8 O0/O2 identity

Focused oracle output is identical at O0 and O2.

PASS.

## A9 source scope

Production delta is exactly:

`src/adapter/mod_fmr_elastic_storage_bro_block_association.f90`.

No existing runtime/kernel/solver/legacy source changes.

PASS.

## Admission meaning

A green ELASTIC21 admits only already-resolved BRO
`staringseriesblock` -> Staringreeks 2018 material-code association.

Still outside scope:
- BOFEK/BRO profile retrieval;
- source horizon selection;
- location/profile selection;
- GeoPackage/database I/O;
- file syntax;
- automatic generated-prior request.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
