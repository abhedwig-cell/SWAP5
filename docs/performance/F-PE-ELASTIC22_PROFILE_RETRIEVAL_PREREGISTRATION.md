# F-PE-ELASTIC22 — explicit BRO profile retrieval preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_TOOL_CHANGE

Baseline:
`integration/f-ci-canonical@fed1d42a3f95b2396c071f6f9e76ec8cb66943cd`

Parent authority:
- `F-PE-ELASTIC12A5_RESULT.md`;
- `F-PE-ELASTIC19_CLOSURE.md`;
- `F-PE-ELASTIC20_CLOSURE.md`;
- `F-PE-ELASTIC21_CLOSURE.md`.

Frozen source artifact:
- PDOK BRO Bodemkaart GeoPackage workflow run `36550782840`;
- artifact `11024079961`.

## Purpose

Add a deterministic **offline preprocessing tool** that retrieves one already
selected BRO `normalsoilprofile_id` from a local GeoPackage and emits its
ordered source horizons.

The seam is:

`explicit profile id + local frozen GeoPackage`
-> exact source profile metadata
-> exact ordered source horizon records.

No physical ELAS calculation occurs in ELASTIC22.

## Ownership boundary

ELASTIC22 may:
- open a caller-supplied local SQLite/GeoPackage file read-only;
- retrieve exactly one explicit integer `normalsoilprofile_id`;
- retrieve that profile's ordered `soilhorizon` rows;
- validate source shape and deterministic ordering;
- serialize source fields to JSON.

ELASTIC22 may not:
- use latitude/longitude;
- inspect polygon geometry for profile selection;
- choose a profile from soilunit/bodemcode;
- query a network service;
- evaluate Staringreeks retention;
- map `staringseriesblock` to a material code;
- classify MINERAL/PEAT;
- compute ELAS;
- activate generated priors.

## Required source schema

Required table `normalsoilprofiles`:
- `normalsoilprofile_id`;
- `soilunit`.

Required table `soilhorizon`:
- `normalsoilprofile_id`;
- `layernumber`;
- `lowervalue`;
- `uppervalue`;
- `staringseriesblock`;
- `organicmattercontent`;
- `peattype`;
- `density`.

No alternate field names or fuzzy schema matching are authorized.

## Profile identity

Input profile ID must:
- be an integer;
- occur exactly once in `normalsoilprofiles`.

Missing or duplicate profile identity fails closed.

The tool does not accept a nearest or fallback profile.

## Horizon ordering and validity

For the selected profile, horizons are ordered strictly by `layernumber`.

Require:
- at least one horizon;
- layernumber sequence exactly `1..N`;
- finite `lowervalue` and `uppervalue`;
- `uppervalue > lowervalue`;
- first `lowervalue = 0` within `1e-10 m`;
- adjacent horizons contiguous within `1e-10 m`;
- finite positive `density`;
- integer `staringseriesblock`;
- organic matter either NULL or finite in [0,100];
- peat type retained exactly as source text/NULL.

No horizon sorting by depth may substitute for invalid layer numbering.

## Output contract

JSON object:

`schema = "swap5.elastic22.bro-profile.v1"`

Top-level fields:
- `normalsoilprofile_id`;
- `soilunit`;
- `horizon_count`;
- `horizons`.

Each horizon contains only source-bound values:
- layernumber;
- top_depth_m = lowervalue;
- bottom_depth_m = uppervalue;
- staringseriesblock;
- dry_density_g_cm3 = density;
- organic_matter_pct = source value or null;
- peat_type = source value or null.

No derived theta, regime or ELAS field is permitted.

## Determinism

For the same GeoPackage bytes and profile ID:
- JSON semantic content must be identical;
- horizon order must be identical;
- source numeric values must be serialized without intentional rounding.

## Qualification matrix

A1. schema audit finds exactly the required source columns.

A2. all 368 source `normalsoilprofile_id` values can be retrieved explicitly.

A3. across all 368 profiles, retrieved horizons total exactly 1568 records.

A4. every retrieved profile is independently compared with a direct SQL oracle:
profile ID, soilunit, horizon count, layer order and every source field match.

A5. known profile `16160` returns its exact source profile/horizon identity.

A6. missing profile ID fails closed.

A7. malformed database/schema fails closed.

A8. repeated retrieval of the same profile is semantically identical.

A9. no network, coordinate, geometry-selection, Staringreeks-retention or ELAS
logic appears in the preprocessing tool.

A10. repository source scope contains no `src/**` change; ELASTIC22 is tooling
and evidence only.

## Admission boundary

A green ELASTIC22 admits explicit offline BRO profile retrieval only.

Still outside scope:
- location-to-profile selection;
- BOFEK unit/profile policy;
- automatic profile choice;
- full source-horizon -> node ELAS orchestration;
- file syntax for user-facing SWAP runs;
- automatic generated-prior request.
