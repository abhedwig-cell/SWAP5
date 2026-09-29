# F-PE-ELASTIC12A4 — PDOK Bodemkaart ATOM bridge preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_ATOM_SCHEMA_RESULTS

Parent:
`F-PE-ELASTIC12_BOFEK_TRANSFER_PREREGISTRATION.md`.

Current canonical reconciliation:
`integration/f-ci-canonical@3fe1e5e6f908f819509f8c1b5ab7438b40267a37`.

The canonical delta since the previous ELASTIC12 reconciliation contains only
F-PE-NLGLOB09 documentation, tests and workflow files and does not intersect
the ELASTIC12 dependency surface.

## Motivation

The official WUR soilphysics coordinate route returns the source-compatible
derived-profile identifier, soil-map-unit code, dry bulk density and
Staringreeks building block.

Direct queries by profile id and by soil-map-unit code are not supported by the
documented service.

PDOK currently publishes BRO Bodemkaart (SGM) as WMS and ATOM downloadservice,
not as a current WFS on its service catalogue.

Official ATOM feed:

`https://service.pdok.nl/tno/bro-bodemkaart/atom/index.xml`

The bounded question is whether that official download source exposes a vector
Bodemkaart package with source-bound soil code and geometry suitable for
constructing deterministic interior coordinates.

## Phase A4a only

This phase does NOT yet call the WUR soilphysics service for the 368 profiles.

It only:

1. fetches the exact PDOK ATOM feed;
2. records URL, HTTP response metadata, bytes and SHA-256;
3. parses ATOM entries and downloadable links without guessing filenames;
4. downloads only links explicitly advertised by the feed as dataset/package
   downloads;
5. inventories archive/container formats and vector layer schemas;
6. identifies a candidate polygon layer only if its explicit field schema
   contains a soil-map-unit/bodemcode attribute;
7. records CRS, feature count when cheaply available, geometry type and exact
   soil-code field name.

No layer is accepted based on visual appearance or filename alone.

## Geometry requirement

A later bridge may advance only if the accepted layer provides polygon or
multipolygon geometry and an explicit soil-code field that can be matched to
the BOFEK2020 `bodemcode`.

For a later 368-profile retrieval, a representative coordinate must be an
interior point of the selected geometry, not a bounding-box centre and not a
polygon centroid that may fall outside the polygon.

The later implementation may use a deterministic point-on-surface algorithm
after its exact geometry dependency is frozen.

## Schema success

Classification:

`PDOK_SOILCODE_GEOMETRY_ROUTE_CONFIRMED`

only if the official ATOM package yields:
- a polygon/multipolygon layer;
- explicit soil-code attribute;
- at least one feature whose code can be matched to the known
  `Rn47C` example.

## Failure

If the ATOM source does not provide a machine-bindable soil-code geometry
route:

`TRANSFER_SOURCE_INCOMPLETE`.

No coordinate-grid sampling, map-image interpretation or undocumented service
parameter probing is authorized as a substitute.
