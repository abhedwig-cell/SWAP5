# F-PE-ELASTIC21 — BRO Staringreeks block-code mapping result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic21-current-clean-admission`

Qualified clean postimage:
`f078da158e831b73f00c399e13de00b8a7b44515`

Current-canonical extraction base:
`integration/f-ci-canonical@e46985908b19f83cf2f17f86507aa3495df971a2`

Workflow run:
`36564778634`

Job:
`109393929619`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/adapter/mod_fmr_elastic_storage_staringseriesblock_map.f90`.

No existing production source is modified.

The adapter performs only deterministic projection:
- `101..118 -> B01..B18`;
- `201..218 -> O01..O18`;

and delegates catalog ownership to admitted ELASTIC20.

## Qualification

- A1 all B blocks map exactly: PASS.
- A2 all O blocks map exactly: PASS.
- A3 all 36 mapped codes resolve through ELASTIC20: PASS.
- A4 invalid/out-of-range integers fail closed with blank code and index 0: PASS.
- A5 representative B01/O18 mappings compose through ELASTIC20 and ELASTIC19 identically to direct lookup: PASS.
- A6 O0/O2 identity: PASS.
- A7 production source scope: PASS.

## Admission meaning

A green ELASTIC21 admits only resolved BRO/BOFEK `staringseriesblock`
projection to the frozen 2018 Staringreeks catalog code.

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
