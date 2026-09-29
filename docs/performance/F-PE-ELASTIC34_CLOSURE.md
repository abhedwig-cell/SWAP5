# F-PE-ELASTIC34 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@c7bcff9634791bdf1a58a698bd4d94cb030e49e4`

Merged PR:
`#865`

Admitted preprocessing file:
`tools/fpe_elastic34_rd_point_maparea.py`

Admitted file blob:
`ed0a71a951be083e18aa877afa2d5f4cac2f9367`

## Admission summary

F-PE-ELASTIC34 admits deterministic offline EPSG:28992 point-to-BRO-maparea
selection against the frozen `soilarea.geom` polygon authority.

Selection semantics:
- strict interior of exactly one polygon -> OK;
- outside all polygons -> NOT_FOUND;
- point on exterior or hole boundary -> BOUNDARY;
- strict interior of multiple polygons -> AMBIGUOUS.

No nearest-area, snapping, tolerance expansion or first-match fallback is used.

## Qualification authority

Qualified branch:
`research/f-pe-elastic34-rd-point-maparea`.

Qualified postimage:
`15303003bc94fc84b47d7147beaa5b764956548a`.

Result-document head:
`dfda5488985f4521283a46e300a16b1446a0b330`.

Qualification:
- workflow run `36588716420`;
- job `109475863303`;
- conclusion SUCCESS.

Passed:
- ELASTIC32 source authority preservation;
- synthetic interior/outside/hole/boundary semantics;
- all 48,025 real polygons decoded;
- all 48,025 maparea identities preserved;
- 64/64 deterministic real-source strict-interior probes selected the exact
  source maparea;
- sampled source boundary vertices failed closed as BOUNDARY;
- outside-source probe returned NOT_FOUND;
- synthetic overlap returned AMBIGUOUS;
- repeated selection was deterministic;
- zero production `src/**` change.

## Ownership semantics

ELASTIC34 owns only offline point-in-polygon selection in already-resolved
EPSG:28992 coordinates.

It does not:
- transform CRS;
- accept latitude/longitude semantics;
- perform runtime GIS I/O;
- access live PDOK/BRO services;
- select a soil profile directly;
- derive or activate ELAS.

ELASTIC23 remains maparea-to-profile authority.
ELASTIC24 remains source-profile retrieval authority.
ELASTIC33 remains profile-row interchange authority.

## Remaining boundary

Still external:
- explicit CRS transformation into EPSG:28992;
- end-to-end location -> maparea -> profile -> source rows composition;
- application-host integration of that offline preprocessing result.

## Closure

F-PE-ELASTIC34 is canonically admitted and closed.
