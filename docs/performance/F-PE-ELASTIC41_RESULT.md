# F-PE-ELASTIC41 — request-gated RD application handoff result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`research/f-pe-elastic41-rd-end-to-end`

Qualified postimage:
`0062c2934da638d58008aae181f04c3efc4c718b`

Workflow run:
`36595836774`

Job:
`109500386721`

Conclusion:
SUCCESS.

## Qualified seam

`generated_prior_requested + EPSG:28992 point + frozen BRO GeoPackage`
-> request=false: exact inactive/default-off behavior with no source access
-> request=true: ELASTIC36 RD spatial/profile preprocessing
-> exact ELASTIC33 row interchange
-> ELASTIC37 application binding
-> bound ELAS parameter postimage.

No CRS transformation is performed.

## Qualification

Offline preprocessing:
- inactive request creates no outputs and does not require source existence: PASS;
- ELASTIC36 row-byte identity: PASS;
- selection provenance identity: PASS;
- 64 real-source qualified RD points: PASS;
- ELASTIC37-consumable row files: PASS;
- spatial fail-closed propagation: PASS;
- missing-source fail closed: PASS;
- repeat byte/provenance identity: PASS.

Application composition:
- explicit generated-prior request discovery: PASS;
- request=false default-off identity: PASS;
- real source profile binding: PASS;
- generated priors finite/positive: PASS;
- explicit/user ELAS ownership preserved: PASS;
- O0/O2 identity: PASS;
- zero `src/**` source scope: PASS.

Selected qualified real-source composition included profile `90116260`,
maparea `V2025-1..soilarea.0000003954`, at an already resolved EPSG:28992 RD
point.

## Reconciliation

Current canonical:
`ba2ab6b015fe713c43b62d77ecc9fe1479a41f12`.

The work unit is tooling/tests/docs only and composes already admitted ELASTIC36
and ELASTIC37 semantics. It does not alter solver/runtime ownership.

## Boundary

Still outside scope:
- geographic CRS transformation into EPSG:28992;
- automatic request from location/profile identity;
- implicit source/output path discovery;
- live PDOK/BRO network access.

## Decision

Classification:
`QUALIFIED_ADMISSION_CANDIDATE`.
