# F-PE-ELASTIC21 — BRO Staringreeks-block association result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic21-clean-admission`

Qualified clean postimage:
`3f934972b58a06e48de892a2b3ecc3075c248203`

Current-canonical extraction base:
`integration/f-ci-canonical@e46985908b19f83cf2f17f86507aa3495df971a2`

Workflow run:
`36564835618`

Job:
`109394115847`

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

## Qualification

- A1 all 18 B-family blocks map exactly: PASS.
- A2 all 18 O-family blocks map exactly: PASS.
- A3 ELASTIC20 catalog indices are exactly 1..36: PASS.
- A4 invalid block values fail closed with blank/zero outputs: PASS.
- A5 all valid mapped codes resolve through admitted ELASTIC20: PASS.
- A6 representative 101/B01 and 218/O18 compose through admitted ELASTIC19 with bit identity: PASS.
- A7 B/O family separation is preserved exactly: PASS.
- A8 O0/O2 identity: PASS.
- A9 production source scope: PASS.

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
