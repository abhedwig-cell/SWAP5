# F-PE-ELASTIC41 — RD-point end-to-end generated-prior qualification preregistration

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

## Purpose

Qualify the full already-admitted ELAS preprocessing/application chain from an
explicit EPSG:28992 RD point and an explicit generated-prior opt-in through to
the bound SWAP parameter postimage.

No new production source is admitted by ELASTIC41.

The qualification chain is:

`explicit RD point`
-> ELASTIC36 offline maparea/profile/row interchange
-> ELASTIC31 explicit generated-prior request
-> ELASTIC37 row-file application binding
-> bound `cofgen(24,:)` / active ELAS postimage.

## Source selection

Use the frozen BRO artifact already admitted by ELASTIC24/34/36.

The test must deterministically identify one real-source strict-interior RD probe
whose selected profile is fully eligible MINERAL for automatic generated-prior
binding:
- every horizon has non-null organic matter;
- organic matter <= 15%;
- peat type is null;
- ELASTIC36 composition succeeds.

The selected maparea/profile/point and source hash are persisted in test output.

No profile is selected by fuzzy soil matching.

## Grid construction

For the selected profile, construct one SWAP node per source horizon:
- node center = horizon midpoint;
- node thickness = horizon thickness;
- SWAP z/dz represented in centimetres with existing ELASTIC18 semantics.

This intentionally makes each node completely contained within exactly one
source horizon.

## Explicit application request

Create a local request file containing exactly:

`ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR`.

Pass that file as the explicit application path to ELASTIC31.

No environment or CLI source is used in the positive case.

## Qualification gates

A1. frozen source artifact/hash authority matches admitted ELASTIC36 authority.

A2. a deterministic real-source strict-interior RD probe resolves through
ELASTIC36 to a fully MINERAL eligible profile.

A3. ELASTIC36 row interchange equals direct ELASTIC24+33 materialization for the
selected profile.

A4. ELASTIC31 explicit config path yields exactly one ready generated-prior
request.

A5. ELASTIC37 binds the selected real profile successfully on the
horizon-aligned SWAP grid.

A6. every bound row-24 value is finite and positive; ELAS is active.

A7. request absent preserves exact default-off parameter identity and does not
require the row file.

A8. explicit/user ELAS in the base parameter set remains higher ownership and
the generated route fails closed without mutation.

A9. O0/O2 qualification output identity.

A10. source scope contains zero `src/**` changes; ELASTIC41 is
research/tests/workflow/docs only.

## Non-claims

ELASTIC41 does not admit:
- geographic lon/lat CRS transformation;
- automatic generated-prior request from location or profile identity;
- runtime GIS or GeoPackage I/O;
- live PDOK/BRO access;
- implicit config discovery or precedence;
- new ELAS physics or parameter fitting.

## Decision

If all gates pass:
`QUALIFIED_RD_POINT_END_TO_END_COMPOSITION`.

If a valid eligible real-source profile cannot be composed:
`ROUTE_FALSIFIED_RD_END_TO_END_COMPOSITION`.

The CRS dependency blocker remains independent and unchanged.
