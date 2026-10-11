# F-PE-ELASTIC32 — BRO spatial source authority audit result

Date: 2026-09-29

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic32-spatial-source-audit`

Qualified postimage:
`1cba41ff7a2f0cbbd2b6662b48003efd1101be6c`

Workflow run:
`36587651150`

Job:
`109472152728`

Conclusion:
SUCCESS.

## Frozen source authority

Artifact:
- producer workflow run `36550782840`;
- artifact id `11024079961`;
- SHA-256 `f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`.

The Actions download independently reported the same digest.

## Spatial feature authority

The frozen GeoPackage contains two polygon layers carrying `maparea_id`:

- `areaofpedologicalinterest`: 6,192 features / 6,192 distinct maparea IDs;
- `soilarea`: 48,025 features / 48,025 distinct maparea IDs.

Only `soilarea` has exact domain identity with the admitted relation table
`soilarea_normalsoilprofile`, which also contains 48,025 distinct
`maparea_id` values.

Therefore the qualified spatial authority is:

- feature table: `soilarea`;
- geometry column: `geom`;
- geometry type: `POLYGON`;
- SRS ID: `28992`;
- SRS: `Amersfoort RD New`;
- organization: `EPSG`;
- relation table: `soilarea_normalsoilprofile`.

## Qualification

- A1 frozen source authority: PASS;
- A2 GeoPackage core metadata: PASS;
- A3 unique defensible feature authority by exact maparea-domain identity: PASS;
- A4 exact ELASTIC23 maparea-domain identity: PASS;
- A5 feature/relation counts persisted: PASS;
- A6 geometry type and SRS from GeoPackage metadata: PASS;
- A7 SRS definition/organization persisted: PASS;
- A8 anomaly counts persisted: PASS;
- A9 spatial metadata/index/function availability characterized: PASS;
- A10 zero production `src/**` change: PASS.

## Decision

The source contract is sufficiently exact to preregister deterministic offline
point-in-polygon selection in a separate workunit.

ELASTIC32 itself admits no spatial selection algorithm.

Classification:
`QUALIFIED_SPATIAL_SOURCE_AUTHORITY_READY_FOR_SELECTION_RESEARCH`.
