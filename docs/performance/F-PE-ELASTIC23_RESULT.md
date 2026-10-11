# F-PE-ELASTIC23 — BRO maparea-to-profile association result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic23-maparea-profile-association`

Qualified postimage:
`76f2cc6f60f4d2a94265194e452201e3cb4ae26f`

Workflow run:
`36567046856`

Job:
`109401427807`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/adapter/mod_fmr_elastic_storage_maparea_profile_association.f90`.

No existing production source is modified.

## Source relation

Frozen BRO GeoPackage relation:

`soilarea_normalsoilprofile(maparea_id, normalsoilprofile_id)`

contains:
- 48,025 rows;
- 48,025 distinct maparea IDs;
- 368 distinct normal soil profiles.

Thus the frozen source association is one maparea -> one profile.

## Qualification

- A1 exact explicit maparea selection: PASS.
- A2 trailing Fortran padding tolerated: PASS.
- A3 leading-space/case-changed/missing/empty request fail closed: PASS.
- A4 duplicate matching rows are ambiguous, even with identical profile IDs: PASS.
- A5 exact matching row with invalid profile ID reports invalid source: PASS.
- A6 returned profile ID composes through admitted ELASTIC22 identically to direct profile-ID selection: PASS.
- A7 unrelated relation rows do not affect the selected association: PASS.
- A8 O0/O2 identity: PASS.
- A9 source scope: PASS.

## Ownership boundary

ELASTIC23 accepts an already selected opaque `maparea_id`.

It performs no:
- spatial geometry;
- point-in-polygon selection;
- coordinate transformation;
- GeoPackage/file/database parsing;
- network lookup;
- automatic maparea selection.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
