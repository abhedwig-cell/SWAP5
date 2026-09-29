# F-PE-ELASTIC36 — RD point to BRO profile-row interchange preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_COMPOSITION_IMPLEMENTATION

Baseline:
`integration/f-ci-canonical@0e5a23f298fea93f7ec545ce8cbd1d49dfa0bbbb`

Parent authority:
- `F-PE-ELASTIC34_CLOSURE.md`;
- `F-PE-ELASTIC33_CLOSURE.md`;
- `F-PE-ELASTIC24_CLOSURE.md`;
- admitted ELASTIC23 maparea-to-profile association semantics.

Frozen source authority:
- GeoPackage artifact SHA-256
  `f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`;
- spatial feature authority `soilarea.geom`, EPSG:28992;
- relation authority `soilarea_normalsoilprofile`;
- profile/horizon authority from ELASTIC24.

## Purpose

Compose already admitted offline preprocessing seams into one reproducible
pipeline:

`RD point`
-> ELASTIC34 strict maparea selection
-> exact `soilarea_normalsoilprofile` association
-> ELASTIC24 explicit profile retrieval
-> ELASTIC33 row interchange.

The output is the canonical `SWAP5_ELASTIC33_BRO_ROWS_V1` file plus provenance
for selected maparea/profile identity.

## Maparea-to-profile composition contract

After ELASTIC34 returns exactly one `maparea_id`:
- query only `soilarea_normalsoilprofile`;
- require exactly one row for that exact maparea identity;
- require one positive integer `normalsoilprofile_id`;
- no fallback, nearest maparea, soilunit inference or profile reselection.

Missing or duplicate relation rows fail closed.

## Output contract

On success:
- exact selected `maparea_id`;
- exact selected `normalsoilprofile_id`;
- source artifact SHA-256;
- RD input point;
- ELASTIC33 interchange text.

The interchange content must equal direct composition of ELASTIC24 + ELASTIC33
for the selected profile.

## Qualification matrix

A1. parent source metadata/hash contracts are unchanged.

A2. deterministic real-source strict-interior probes select one maparea through
ELASTIC34 and one exact profile through the relation table.

A3. selected profile identity equals a direct SQL oracle for each probe.

A4. ELASTIC24 output for the selected profile matches direct explicit retrieval.

A5. ELASTIC33 interchange is byte-identical to independent direct
ELASTIC24->ELASTIC33 composition for the same profile.

A6. broad deterministic sample covers at least 64 successful real-source
points and multiple distinct profiles.

A7. boundary, outside and ambiguous ELASTIC34 outcomes propagate fail closed
without relation/profile lookup.

A8. missing/duplicate relation conditions are fail-closed in isolated synthetic
relation tests.

A9. repeated same point is byte-identical and provenance-identical.

A10. no `src/**` change; tooling/tests/docs only.

## Non-claims

A green ELASTIC36 does not admit:
- latitude/longitude input or CRS transformation;
- runtime GeoPackage/file I/O;
- automatic ELAS request;
- generated-prior activation;
- live PDOK/BRO access;
- application-host invocation.

## Decision rule

Only exact single-maparea/single-profile composition may emit an interchange.

Any spatial, relational or profile ambiguity fails closed.
