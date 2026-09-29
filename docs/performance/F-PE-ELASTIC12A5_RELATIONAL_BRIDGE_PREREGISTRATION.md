# F-PE-ELASTIC12A5 — relational BRO/BOFEK profile bridge preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_RELATIONAL_BRIDGE_RESULT

Parent:
`F-PE-ELASTIC12_BOFEK_TRANSFER_PREREGISTRATION.md`.

## Motivation

The PDOK BRO Bodemkaart GeoPackage advertised by the official ATOM feed does
not store `bodemcode` directly on the polygon geometry table.

It does expose relational source tables including:

- `soilarea`;
- `soilarea_normalsoilprofile`;
- `normalsoilprofiles`;
- `soilhorizon`.

The discovered `soilhorizon` schema contains:
- `normalsoilprofile_id`;
- horizon depth bounds;
- `staringseriesblock`;
- `density`.

This phase tests the relational profile bridge directly and does not require a
coordinate query to the WUR soilphysics service.

## Frozen source artifacts

BOFEK/Staringreeks source audit:
- run `36549054287`;
- artifact `11023058542`.

PDOK BRO Bodemkaart GeoPackage audit:
- run `36550782840`;
- artifact `11024079961`.

No newer external source may silently replace either artifact in A5.

## Exact BOFEK-to-BRO profile gate

From BOFEK `allprofiles368_2020.csv`:
- exactly 368 unique `iprofile` values are required.

From BRO GeoPackage `normalsoilprofiles`:
- the set of `normalsoilprofile_id` values must contain exactly the same 368
  BOFEK profile IDs.

No fuzzy or code-based matching is allowed.

## Horizon identity gate

For each BOFEK profile, every non-zero `isoilN` layer must correspond to one
BRO `soilhorizon` row with the same sequence and upper depth.

BOFEK `isoil` encoding is translated deterministically:

- 1..18 -> Staringreeks topsoil B01..B18 -> BRO block 101..118;
- 19..36 -> Staringreeks subsoil O01..O18 -> BRO block 201..218.

For every layer:
- `BRO staringseriesblock` must equal this encoded BOFEK layer;
- BOFEK `izN` in cm must equal BRO `uppervalue` in m after division by 100;
- BRO `density` must be finite and positive.

The bridge advances only if all 368 profiles and all source layers pass.

## Transfer calculation

After the exact bridge passes, evaluate the already preregistered ELASTIC12
state grid without refitting:

- h = -10 cm
- h = -33 cm
- h = -100 cm
- h = -330 cm
- h = -1000 cm

For each layer:
1. resolve exact Staringreeks 2018 B/O material;
2. evaluate van Genuchten water content using the source parameters;
3. reconstruct field-moist bulk density and gravimetric water content according
   to the parent preregistration;
4. evaluate the frozen ELASTIC11 M1 equation;
5. classify predictor-domain status from frozen z-score limits.

No clipping or preferred-head selection is allowed.

## Decision

Use the parent ELASTIC12 advancement rule unchanged.

This phase may classify:
- `BOFEK_LAYER_PRIOR_TRANSFER_FEASIBLE`;
- `TRANSFER_NOT_SUPPORTED_WITH_CURRENT_PREDICTOR_DOMAIN`;
- or `TRANSFER_SOURCE_INCOMPLETE`.

Even a feasible result does not select one pressure-head state for production.
