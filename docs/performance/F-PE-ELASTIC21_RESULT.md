# F-PE-ELASTIC21 — BRO Staringreeks block-code mapping result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic21-staringseriesblock-map`

Qualified postimage:
`52ed56eba003c6a5d45f5a9a4fc7700c479a1021`

Workflow run:
`36564468210`

Job:
`109392925389`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/adapter/mod_fmr_elastic_storage_staringseriesblock_map.f90`.

No existing production source is modified.

The adapter performs only deterministic projection:

- `101..118 -> B01..B18`;
- `201..218 -> O01..O18`;

and delegates code ownership to the admitted ELASTIC20 catalog.

## Qualification

- A1 all 18 B blocks map to B01..B18 and indices 1..18: PASS.
- A2 all 18 O blocks map to O01..O18 and indices 19..36: PASS.
- A3 all 36 mapped codes resolve through admitted ELASTIC20: PASS.
- A4 invalid/out-of-range integers fail closed with blank code and index 0: PASS.
- A5 representative B01 and O18 mappings compose through ELASTIC20 and ELASTIC19 identically to direct code lookup: PASS.
- A6 O0/O2 identity: PASS.
- A7 production source scope: PASS.

## Admission meaning

A green ELASTIC21 admits only BRO/BOFEK `staringseriesblock` projection to the
frozen Staringreeks-2018 catalog code.

Still outside scope:
- BOFEK/BRO profile retrieval;
- location/profile selection;
- source-horizon retrieval;
- file/data-catalog syntax;
- alternate Staringreeks years;
- automatic generated-prior request.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
