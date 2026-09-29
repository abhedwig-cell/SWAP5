# F-PE-ELASTIC12A2 — WUR derived-profile service ID-route preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PROFILE_SERVICE_PROBE

Parent:
`F-PE-ELASTIC12_BOFEK_TRANSFER_PREREGISTRATION.md`.

## Purpose

Determine whether the official WUR soil-physics service can retrieve the same
derived soil profile directly by profile identifier, so the 368 BOFEK2020
profiles can be joined reproducibly to source-bound dry bulk density without
spatial sampling.

## Known documented route

Documented endpoint:

`https://www.soilphysics.wur.nl/soil.php?latitude=<lat>&longitude=<lon>`

A documented example at latitude 52, longitude 5 returns a JSON object with:
- a profile `id`;
- soil-map unit `smu`;
- horizon array;
- per-horizon `density`;
- `spu` Staringreeks code.

The WUR documentation describes these as 368 derived/modal soil profiles and
states that BOFEK2020 clusters those profiles.

## Frozen discovery probe

Use the documented example coordinate first and record its returned profile ID.

Then issue exactly these direct-ID candidate requests for that same ID:

1. `soil.php?id=<id>`
2. `soil.php?iprofile=<id>`
3. `soil.php?profile=<id>`
4. `soil.php?normalsoilprofile_id=<id>`

For every request record:
- HTTP status;
- content type;
- bytes;
- SHA-256;
- whether response is valid JSON;
- returned top-level keys;
- returned `id` when present.

A candidate direct-ID route is accepted only if:
- HTTP 200;
- valid JSON object;
- returned id equals the documented-coordinate id;
- horizon array is present and non-empty;
- at least one horizon carries both finite `density` and `spu`.

No other parameter names may be tried after seeing these results in this phase.

## Outcomes

If one candidate passes:

`DIRECT_PROFILE_ID_ROUTE_CONFIRMED`.

Then a later phase may preregister deterministic retrieval of the exact 368
BOFEK profile IDs.

If none passes:

`NO_DIRECT_PROFILE_ID_ROUTE_CONFIRMED`.

Then the transfer must either:
- use another explicitly documented bulk/profile source;
- or close as source-incomplete.

No coordinate-grid sampling is authorized by this preregistration.
