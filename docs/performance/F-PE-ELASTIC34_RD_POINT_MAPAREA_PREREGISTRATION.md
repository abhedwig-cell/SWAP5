# F-PE-ELASTIC34 — RD point to BRO maparea selection preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_SELECTION_IMPLEMENTATION

Baseline:
`integration/f-ci-canonical@ea44fa14a48c913e15b50039a7ebd89e95f74567`

Parent authority:
- `F-PE-ELASTIC32_SPATIAL_SOURCE_AUDIT_RESULT.md`;
- admitted ELASTIC23 maparea-to-profile association;
- admitted ELASTIC24 frozen-source retrieval.

Frozen spatial authority:
- GeoPackage table `soilarea`;
- geometry column `geom`;
- geometry type `POLYGON`;
- exact 48,025 `maparea_id` domain;
- SRS EPSG:28992, Amersfoort / RD New;
- frozen source artifact SHA-256
  `f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`.

## Purpose

Research and qualify deterministic offline selection of one BRO `maparea_id`
from one point already expressed in EPSG:28992.

The seam is:

`x_rd_m, y_rd_m + frozen local GeoPackage`
-> exact point-in-polygon selection on `soilarea.geom`
-> one `maparea_id` or explicit fail-closed status.

No coordinate transformation is performed.

## Spatial semantics

Input:
- finite X/Y in metres in EPSG:28992;
- caller-supplied frozen local GeoPackage.

Candidate geometry:
- only `soilarea.geom`;
- only rows with non-NULL `maparea_id` and geometry;
- no alternate polygon layer;
- no live service fallback.

Selection:
- point strictly inside exactly one polygon -> OK;
- point outside all polygons -> NOT_FOUND;
- point on any polygon exterior or hole boundary -> BOUNDARY, fail closed;
- point strictly inside more than one polygon -> AMBIGUOUS, fail closed.

No nearest-polygon, snapping, tolerance expansion or first-match rule is
admitted.

## Geometry decoding

The tool may decode the GeoPackage binary geometry header and WKB payload
offline.

The implementation must:
- verify GeoPackage magic;
- respect declared byte order;
- skip the declared envelope correctly;
- reject unsupported/invalid geometry payloads;
- support the actual admitted `POLYGON` source encoding only;
- preserve holes.

Unsupported geometry encoding fails closed.

## Qualification matrix

A1. frozen source metadata still matches ELASTIC32 authority:
`soilarea.geom`, POLYGON, EPSG:28992, 48,025 IDs.

A2. synthetic polygon oracle: interior/exterior/hole/boundary behavior matches
the preregistered policy.

A3. real-source geometry decoder can parse all 48,025 `soilarea.geom` rows
without silent repair.

A4. all real-source geometries retain exact non-NULL `maparea_id` identity.

A5. for a deterministic broad sample of real polygons, independently generated
strict-interior probe points resolve back to the source `maparea_id`.

A6. source exterior-boundary vertices are classified BOUNDARY rather than
arbitrarily assigned.

A7. a point demonstrably outside the source extent returns NOT_FOUND.

A8. any multi-match interior condition, if encountered in source probes, is
reported AMBIGUOUS and never first-match selected.

A9. repeated same-point selection is deterministic.

A10. no `src/**` production change; research/tooling/tests/docs only.

## Non-claims

A green ELASTIC34 does not admit:
- WGS84/latitude-longitude input;
- CRS transformation;
- runtime GIS ownership;
- live PDOK/BRO access;
- nearest-area fallback;
- automatic ELAS request;
- production application-host integration.

## Decision rule

If all source geometries decode and the deterministic probes support the strict
selection policy, ELASTIC34 may become a qualified offline preprocessing
candidate.

Any geometry encoding, boundary, overlap or CRS ambiguity must be persisted as
a blocker rather than normalized away.
