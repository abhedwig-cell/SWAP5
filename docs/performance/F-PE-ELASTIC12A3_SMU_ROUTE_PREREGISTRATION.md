# F-PE-ELASTIC12A3 — WUR soil-map-unit route preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_SMU_ROUTE_PROBE

Parent:
`F-PE-ELASTIC12A2_PROFILE_SERVICE_PREREGISTRATION.md`.

## Motivation

The documented coordinate query at latitude 52, longitude 5 returns:

- profile `id=16160`;
- `smu=Rn47C`;
- five horizons with dry bulk density and Staringreeks code.

The official BOFEK2020 profile table contains the same profile:

- `iprofile=16160`;
- `bodemcode=Rn47C`;
- the same five-layer Staringreeks sequence and depths.

Thus the WUR profile service and BOFEK source are source-consistent for this
known example.

## Frozen route probe

For the exact known soil-map-unit code `Rn47C`, probe only:

1. `soil.php?smu=Rn47C`
2. `soil.php?bodemcode=Rn47C`

A route passes only if:
- HTTP 200;
- valid JSON object;
- returned `id=16160`;
- returned `smu=Rn47C`;
- non-empty horizon array;
- horizon sequence contains source-bound density and Staringreeks codes.

No additional query-key discovery is allowed after results are observed.

## Decision

If either route passes:

`DIRECT_SMU_ROUTE_CONFIRMED`.

Then exact retrieval of all 368 BOFEK2020 rows may be preregistered by their
source `bodemcode`.

If neither route passes:

`NO_DIRECT_SMU_ROUTE_CONFIRMED`.

Then ELASTIC12 must not replace full-profile retrieval with an ad hoc coordinate
grid. A separately sourced 368-profile property table is required.
