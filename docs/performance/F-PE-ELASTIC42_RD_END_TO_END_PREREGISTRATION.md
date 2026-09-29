# F-PE-ELASTIC42 — RD-point end-to-end generated-prior qualification preregistration

Date: 2026-09-29

Status: PREREGISTERED_RESEARCH_ONLY

Baseline:
`integration/f-ci-canonical@b1ab94eb2940203f3a4564d72383247d71bb4fad`

Parent authority:
- `F-PE-ELASTIC31_CLOSURE.md`;
- `F-PE-ELASTIC34_CLOSURE.md`;
- `F-PE-ELASTIC36_CLOSURE.md`;
- `F-PE-ELASTIC37_CLOSURE.md`;
- negative CRS authority from ELASTIC38/39/40.

Parallel ownership:
- ELASTIC41 owns request-gated offline RD preprocessing handoff.
- ELASTIC42 adds no production source and does not alter ELASTIC41.

## Purpose

Qualify the already-admitted chain from an explicit EPSG:28992 RD point and an
explicit generated-prior opt-in through to the bound SWAP parameter postimage.

Chain:

`explicit RD point`
-> ELASTIC36 offline maparea/profile/row interchange
-> ELASTIC31 explicit generated-prior request
-> ELASTIC37 row-file application binding
-> bound `cofgen(24,:)` / active ELAS postimage.

## Source and profile selection

Use the frozen BRO artifact admitted by ELASTIC24/34/36.

Deterministically enumerate real source polygons and retain candidate profiles
whose source horizons satisfy the existing automatic mineral-policy envelope:
- organic matter available for every horizon;
- organic matter <= 15%;
- no peat type.

ELASTIC37 remains final eligibility authority. The qualification may try
multiple deterministic candidates until one valid real profile binds
successfully; failures are not reclassified or repaired.

## Grid construction

For each candidate profile construct one SWAP node per source horizon:
- node center at horizon midpoint;
- node thickness equal to horizon thickness;
- z/dz in centimetres under admitted ELASTIC18 semantics.

Every node is therefore fully contained in one source horizon.

## Explicit application request

Create one request file:

`ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR`

and pass it explicitly to ELASTIC31.

No environment or CLI source is used.

## Qualification gates

A1. frozen source/hash authority matches admitted ELASTIC36.

A2. deterministic real-source mineral candidates can be materialized through
ELASTIC36.

A3. each candidate ELASTIC36 row interchange is byte-identical to direct
ELASTIC24+33 materialization.

A4. ELASTIC31 explicit config path yields one ready generated-prior request.

A5. at least one real candidate binds successfully through ELASTIC37 on the
horizon-aligned grid.

A6. successful bound row-24 values are all finite and positive and ELAS is
active.

A7. request absent preserves exact default-off identity and does not require a
row file.

A8. explicit/user ELAS remains higher ownership and rejects generated binding
without mutation.

A9. O0/O2 qualification output identity.

A10. zero `src/**` changes.

## Non-claims

ELASTIC42 does not admit:
- geographic CRS transformation;
- automatic request from location/profile identity;
- runtime GIS/GeoPackage I/O;
- live PDOK/BRO access;
- new ELAS physics or fitting.

## Decision

All gates pass:
`QUALIFIED_RD_POINT_END_TO_END_COMPOSITION`.

No successful eligible real profile:
`ROUTE_FALSIFIED_RD_END_TO_END_COMPOSITION`.

The CRS dependency blocker remains unchanged.
