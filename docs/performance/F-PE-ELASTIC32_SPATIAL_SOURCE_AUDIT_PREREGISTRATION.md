# F-PE-ELASTIC32 — BRO spatial source authority audit preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_SOURCE_ANALYSIS

Baseline:
`integration/f-ci-canonical@bcb727b27c3586accb5a481ec3eb5ce90b1e8cef`

Parent authority:
- `F-PE-ELASTIC31_CLOSURE.md`;
- `F-PE-ELASTIC24_CLOSURE.md`;
- admitted ELASTIC23 maparea-to-profile association.

Frozen source artifact:
- producer workflow run `36550782840`;
- artifact `f-pe-elastic12a4-pdok-atom`;
- artifact id `11024079961`;
- SHA-256 `f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`.

## Purpose

Audit the frozen BRO Bodemkaart GeoPackage before implementing any
coordinate/location -> `maparea_id` selection.

ELASTIC32 is source characterization only.

It must identify:
- authoritative feature table(s);
- geometry column(s);
- geometry type(s);
- SRS/CRS identifiers and definitions;
- exact `maparea_id` column and identity domain;
- feature count and distinct maparea count;
- whether one maparea ID occurs on one or multiple geometries;
- whether spatial indexing metadata exists;
- whether the relation to ELASTIC23's 48,025 maparea identities is exact.

## Required GeoPackage metadata

Audit:
- `gpkg_contents`;
- `gpkg_geometry_columns`;
- `gpkg_spatial_ref_sys`;
- candidate feature-table schema;
- row counts and distinct identifier counts;
- declared geometry type and SRS ID.

No fuzzy table/column matching is admitted in the result. Candidate discovery
may enumerate metadata, but any proposed authority must name exact table and
column identifiers.

## Qualification questions

A1. Frozen artifact digest matches the admitted source SHA-256.

A2. GeoPackage core metadata tables are present and internally consistent.

A3. Exactly one defensible feature-layer authority can be identified for
BRO mapareas, or the result explicitly reports ambiguity/blocker.

A4. The exact maparea identifier column is identified and can be joined
one-to-one in identity semantics with the ELASTIC23 relation domain.

A5. Feature row count and distinct maparea ID count are recorded.

A6. Geometry type and SRS ID are recorded from GeoPackage metadata, not guessed.

A7. Relevant SRS definition/organization/code are persisted.

A8. Duplicate maparea geometry membership, NULL identifiers/geometries and
other source anomalies are counted explicitly.

A9. Spatial-index metadata and available SQLite geometry extensions/functions
are characterized without making them a production dependency.

A10. No production `src/**` change; audit/tooling/docs only.

## Non-claims

A green ELASTIC32 does not admit:
- point-in-polygon selection;
- coordinate transformation;
- boundary-point policy;
- nearest polygon fallback;
- spatial index dependency;
- live PDOK/BRO access;
- runtime GIS ownership.

## Decision rule

Only if the frozen source exposes one exact feature-layer/CRS/maparea contract
may the next workunit preregister deterministic offline spatial selection.

If the source is ambiguous, malformed, or cannot be related exactly to
ELASTIC23 identities, record a blocker instead of guessing.
