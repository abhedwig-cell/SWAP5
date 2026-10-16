# F-PE-ELASTIC22 — explicit BRO profile-source result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic22-explicit-profile-source`

Qualified postimage:
`d4ed35864331dc099b5b5ad8a6897b4657dab490`

Workflow run:
`36565679361`

Job:
`109396878836`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/adapter/mod_fmr_elastic_storage_explicit_profile_source.f90`.

No existing production source is modified.

## Qualified seam

The adapter accepts already loaded BRO horizon rows and one explicit
`normalsoilprofile_id`.

It performs:

`explicit profile ID`
-> selected source rows
-> admitted ELASTIC21 block mapping
-> admitted ELASTIC20 retention lookup
-> admitted ELASTIC19 horizon construction.

No file, database, spatial or network lookup is performed.

## Qualification

- A1 explicit profile selection from mixed multi-profile rows: PASS.
- A2 selected source geometry/dry-density identity: PASS.
- A3 nested ELASTIC21+20+19 composition: PASS.
- A4 absent profile ID fail closed: PASS.
- A5 nonpositive requested profile ID fail closed: PASS.
- A6 layer-number/geometry structure fail closed: PASS.
- A7 nested block/descriptor failure is atomic: PASS.
- A8 downstream ELASTIC17/16 composition: PASS.
- A9 PEAT provenance preserved and rejected downstream: PASS.
- A10 O0/O2 identity: PASS.
- A11 production source scope: PASS.

## Structural semantics

The adapter does not sort the selected profile.

Selected rows must already appear as:
- layer 1 first;
- then exactly 2,3,...;
- contiguous source geometry;
- first horizon top at soil surface.

This makes source ordering caller-owned and prevents silent repair of malformed
input.

Rows belonging to other profile IDs are ignored.

## Ownership boundary

ELASTIC22 owns only explicit in-memory profile selection and source-horizon
assembly.

Still external:
- GeoPackage/file/database loading;
- location-to-profile selection;
- spatial polygon lookup;
- choosing profile ID automatically;
- automatic generated-prior request.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
