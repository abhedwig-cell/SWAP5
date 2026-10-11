# F-PE-ELASTIC34 — RD point to BRO maparea selection result

Date: 2026-09-29

Status: QUALIFIED_OFFLINE_PREPROCESSING_CANDIDATE

Branch:
`research/f-pe-elastic34-rd-point-maparea`

Qualified postimage:
`15303003bc94fc84b47d7147beaa5b764956548a`

Workflow run:
`36588716420`

Job:
`109475863303`

Conclusion:
SUCCESS.

## Qualified seam

`x_rd_m, y_rd_m + frozen local BRO GeoPackage`
-> strict point-in-polygon on `soilarea.geom`
-> exact `maparea_id` or explicit fail-closed status.

Source authority:
- table `soilarea`;
- geometry `geom`;
- geometry type `POLYGON`;
- CRS EPSG:28992, Amersfoort / RD New;
- 48,025 exact maparea identities.

## Qualification

- A1 ELASTIC32 source authority preserved: PASS;
- A2 synthetic interior/outside/hole/boundary policy: PASS;
- A3 all 48,025 real geometries decoded: PASS;
- A4 all 48,025 maparea identities preserved: PASS;
- A5 64/64 deterministic real-source strict-interior probes selected their exact source maparea: PASS;
- A6 sampled source exterior vertices classified BOUNDARY: PASS;
- A7 outside-source probe returned NOT_FOUND: PASS;
- A8 synthetic multi-match classified AMBIGUOUS: PASS;
- A9 repeated selection deterministic: PASS;
- A10 zero production `src/**` change: PASS.

## Spatial policy

Admitted candidate semantics:
- strict interior of exactly one polygon -> OK;
- outside all polygons -> NOT_FOUND;
- point on exterior or hole boundary -> BOUNDARY;
- interior of more than one polygon -> AMBIGUOUS.

No nearest polygon, snapping, tolerance expansion or first-match fallback is
used.

## Implementation boundary

The qualified implementation is offline preprocessing tooling.

It does not:
- transform WGS84 or any other CRS;
- perform runtime GIS I/O;
- access live PDOK/BRO services;
- choose an ELAS profile directly;
- activate generated priors.

## Current canonical reconciliation

The canonical delta since ELASTIC34 baseline consists only of the independently
admitted ELASTIC33 profile-row interchange seam and does not intersect the
ELASTIC34 spatial-source/tooling surface.

Current observed canonical:
`4aad1752b07507e135057658faf0abdf6dbf8eb8`.

## Decision

Classification:
`QUALIFIED_OFFLINE_PREPROCESSING_CANDIDATE_READY_FOR_ADMISSION`.
