# F-PE-ELASTIC42 — RD-point end-to-end generated-prior qualification result

Date: 2026-09-29

Status: QUALIFIED_RESULT

Branch:
`research/f-pe-elastic42-rd-end-to-end`

Qualified postimage:
`8178eeb4703ba8e096fe78498a7e349782232a0d`

Workflow run:
`36595018035`

Job:
`109497569153`

Conclusion:
SUCCESS.

## Result

The already-admitted ELAS chain composes successfully from an explicit
EPSG:28992 RD point and an explicit generated-prior opt-in through to a bound
SWAP parameter postimage.

Qualified chain:

`explicit RD point`
-> ELASTIC36 offline spatial/profile/interchange composition
-> ELASTIC31 explicit application request
-> ELASTIC37 row-file application binding
-> active ELAS with finite positive node-local generated priors.

## Frozen source authority

Source artifact SHA-256:

`f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`.

The deterministic source scan found:

`260`

real-source profiles satisfying the preregistered mineral prefilter
(non-null organic matter <=15% and no peat type).

ELASTIC37 remained final eligibility authority.

## Selected qualified real profile

Both O0 and O2 selected the same first successfully bound candidate:

- normalsoilprofile_id: `90116260`;
- maparea_id: `V2025-1..soilarea.0000003954`;
- RD x: `179362.75550490862 m`;
- RD y: `418659.84937244334 m`.

The selected row interchange was produced by ELASTIC36 and was byte-identical
to direct ELASTIC24 + ELASTIC33 materialization.

## Qualification

- A1 frozen source authority: PASS.
- A2 deterministic real mineral candidates: PASS, 260 candidates.
- A3 ELASTIC36 versus direct ELASTIC24+33 interchange identity: PASS.
- A4 ELASTIC31 explicit generated-prior request: PASS.
- A5 real-source profile binding through ELASTIC37: PASS.
- A6 all bound row-24 priors finite and positive, ELAS active: PASS.
- A7 absent request exact default-off identity with no required row file: PASS.
- A8 explicit/user ELAS ownership preserved and generated route rejected
  without mutation: PASS.
- A9 O0/O2 output identity: PASS.
- A10 zero `src/**` source change: PASS.

## Interpretation

The remaining inability to start from geographic longitude/latitude is not an
ELAS composition failure.

The admitted/qualified route from already-resolved EPSG:28992 coordinates is
complete enough to reach the generated ELAS parameter postimage under explicit
application opt-in.

CRS transformation remains blocked independently by ELASTIC38/39/40 because
the standard runner provides none of the three preregistered dependency-free
routes:
- pyproj;
- cs2cs;
- gdaltransform.

## Non-claims

ELASTIC42 does not admit:
- lon/lat -> RD transformation;
- automatic request from location/profile identity;
- live PDOK/BRO access;
- runtime GIS or GeoPackage I/O;
- new ELAS physics or fitting.

## Decision

Classification:

`QUALIFIED_RD_POINT_END_TO_END_COMPOSITION`.

The CRS dependency decision remains the only blocker for extending this
qualified route from geographic coordinates.
