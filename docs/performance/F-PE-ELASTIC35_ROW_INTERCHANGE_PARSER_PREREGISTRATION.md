# F-PE-ELASTIC35 — ELASTIC33 row-interchange parser preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@4aad1752b07507e135057658faf0abdf6dbf8eb8`

Parent authority:
- `F-PE-ELASTIC33_CLOSURE.md`;
- `F-PE-ELASTIC22_CLOSURE.md`.

Parallel ownership:
- F-PE-ELASTIC34 owns the separate RD-point -> maparea spatial-selection line;
- ELASTIC35 performs no coordinate, polygon, CRS or maparea selection.

## Purpose

Add one bounded application/file adapter that parses the admitted
`SWAP5_ELASTIC33_BRO_ROWS_V1` interchange into the exact admitted ELASTIC22
type:

`fmr_elastic_storage_bro_horizon_row_t(:)`.

The seam is:

`ELASTIC33 interchange file`
-> exact header/provenance/schema validation
-> typed ELASTIC22 source rows
-> optional downstream call to admitted ELASTIC22.

This is application-side file I/O only. The Richards solver/runtime does not
open or discover this file.

## Accepted interchange

Required exact lines:

1. `SWAP5_ELASTIC33_BRO_ROWS_V1`
2. `source_artifact_sha256=f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`
3. `normalsoilprofile_id=<positive integer>`
4. `row_count=<positive integer>`
5. `columns=normalsoilprofile_id|layer_number|top_depth_m|bottom_depth_m|staringseriesblock|rho_dry_g_cm3|organic_matter_available|organic_matter_pct|peat_type_present`

Exactly `row_count` row lines follow.

No extra records after the final row are admitted.

## Row parsing contract

Each row must contain exactly nine pipe-delimited fields in the admitted order.

Require:
- row profile ID equals the header profile ID;
- layer sequence exactly 1..N;
- finite top/bottom depths;
- positive thickness;
- first top depth within 1e-10 m of 0;
- adjacent horizons contiguous within 1e-10 m;
- integral `staringseriesblock`;
- finite positive dry density;
- availability/presence fields exactly 0 or 1;
- finite organic-matter value;
- when availability=1, organic matter in [0,100].

The parser does not sort, average, repair or reselect rows.

## Typed projection

Output fields map exactly to ELASTIC22:

- profile ID -> `normalsoilprofile_id`;
- layer number -> `layer_number`;
- top/bottom depth unchanged;
- block unchanged;
- density unchanged;
- 0/1 organic flag -> logical;
- organic value unchanged;
- 0/1 peat flag -> logical.

The parser itself does not classify MINERAL/PEAT/UNKNOWN. ELASTIC19 retains
that ownership downstream.

## Fail-closed behavior

Fail closed and return no allocated row array on:
- missing/blank path;
- open/read failure;
- wrong magic/hash/header/column schema;
- invalid row count;
- malformed row width;
- invalid row field;
- profile/layer mismatch;
- invalid geometry/data;
- unexpected extra record.

No partial row array survives failure.

## Qualification matrix

A1. one known ELASTIC33 interchange parses to exact row/header identity.

A2. all 368 frozen ELASTIC33 profile interchanges parse successfully.

A3. parsed rows total exactly 1568.

A4. binary64 row values reconstructed by the Fortran parser are bit-identical
to the ELASTIC33 serialized values.

A5. organic availability and peat presence 0/1 flags project exactly to
Fortran logical fields.

A6. wrong magic/hash/columns/count and malformed rows fail closed.

A7. profile/layer/geometry/data violations fail closed.

A8. valid parsed rows compose through admitted ELASTIC22 and preserve selected
row/layer/source identity.

A9. O0/O2 identity.

A10. production source scope is exactly one new adapter module plus tests/docs;
no runtime, solver, kernel or legacy source changes.

## Admission boundary

A green ELASTIC35 admits only bounded application parsing of the already
materialized ELASTIC33 interchange.

Still outside:
- runtime/solver file discovery;
- location/coordinate -> maparea selection;
- automatic profile choice;
- direct GeoPackage parsing in Fortran;
- automatic generated-prior request.
