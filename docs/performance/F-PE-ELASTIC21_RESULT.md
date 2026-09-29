# F-PE-ELASTIC21 — BRO Staringreeks-block association result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic21-staringseriesblock-association`

Qualified postimage:
`5d684d186406a9522af0ee7cab0c0b80ce6e683d`

Workflow run:
`36564783608`

Job:
`109393945631`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/adapter/mod_fmr_elastic_storage_staringblock_association.f90`.

No existing production source is modified.

## Qualified mapping

Exact BRO `staringseriesblock` association:

- 101..118 -> B01..B18;
- 201..218 -> O01..O18.

The adapter also returns:
- topsoil/subsoil family;
- 1..18 family index;
- exact ELASTIC20 catalog index.

## Qualification

- A1 all topsoil blocks 101..118 -> B01..B18: PASS.
- A2 all subsoil blocks 201..218 -> O01..O18: PASS.
- A3 endpoint identity 101/B01, 118/B18, 201/O01, 218/O18: PASS.
- A4 unsupported blocks fail closed with empty code/index: PASS.
- A5 all mapped codes resolve through admitted ELASTIC20: PASS.
- A6 representative mapped B/O codes compose through ELASTIC19: PASS.
- A7 O0/O2 identity: PASS.
- A8 source scope: PASS.

## Ownership boundary

ELASTIC21 performs no:
- external I/O;
- profile selection;
- horizon selection;
- retention fitting;
- alternate-year lookup;
- ELAS computation;
- runtime activation.

It only preserves the already source-bound BRO-to-Staringreeks association.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
