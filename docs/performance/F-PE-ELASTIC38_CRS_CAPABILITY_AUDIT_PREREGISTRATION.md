# F-PE-ELASTIC38 — CRS transformation capability audit preregistration

Date: 2026-09-29

Status: PREREGISTERED_RESEARCH_ONLY

Baseline:
`integration/f-ci-canonical@8c20e27c44340dd159ddd839fcf24b0f1f5bf1d1`

Parent authority:
- `F-PE-ELASTIC34_CLOSURE.md`;
- `F-PE-ELASTIC36_CLOSURE.md`;
- `F-PE-ELASTIC37_CLOSURE.md`.

## Purpose

Characterize whether the current SWAP5 execution environment has a defensible,
offline and reproducible CRS transformation route from geographic WGS84
coordinates into the already admitted ELASTIC34 EPSG:28992 point-selection
contract.

This is a research audit only.

No production CRS adapter, dependency addition or automatic spatial selection is
admitted by ELASTIC38.

## Candidate capability

Primary candidate:

- Python package `pyproj`;
- source CRS EPSG:4326;
- target CRS EPSG:28992;
- explicit longitude/latitude input order using `always_xy=True`;
- offline local PROJ/EPSG database only.

Secondary characterization where available:

- `projinfo` executable;
- `cs2cs` executable.

No network lookup or remote grid download is allowed.

## Audit questions

Q1. Is `pyproj` already available on the standard GitHub runner without adding
a repository dependency?

Q2. Which pyproj/PROJ versions and data directory are used?

Q3. Can EPSG:4326 and EPSG:28992 be resolved fully offline?

Q4. Is the selected transformer definition deterministic across repeated
construction in one run?

Q5. Does explicit lon/lat axis order avoid the EPSG axis-order ambiguity?

Q6. Do forward and inverse transforms remain finite and numerically stable for
a preregistered Netherlands test envelope?

Q7. Do forward/inverse round trips remain within:
- 1e-8 degrees for longitude/latitude;
- 1e-3 m for RD coordinates?

Q8. Do transformed geographic test points fall in plausible RD New coordinate
ranges:
- x in [0, 300000] m;
- y in [250000, 650000] m?

Q9. If `projinfo` / `cs2cs` are available, do they identify the same CRS
authority pair without network access?

Q10. Does the audit introduce zero `src/**` production changes?

## Test envelope

Use explicit WGS84 longitude/latitude pairs only:

- (5.6631, 51.9851) Wageningen-region probe;
- (4.8952, 52.3702) Amsterdam-region probe;
- (5.1214, 52.0907) Utrecht-region probe;
- (6.5665, 53.2194) Groningen-region probe;
- (3.6100, 51.4400) Zeeland-region probe.

These are capability probes, not geodetic control points. Therefore ELASTIC38
may qualify transformation availability and numerical consistency, but it may
not claim independent survey-grade absolute accuracy from these coordinates.

## Fail-closed decision

Classify as BLOCKED_FOR_PRODUCTION if:
- pyproj is unavailable;
- required CRS authority cannot resolve offline;
- transformation produces non-finite values;
- round-trip gates fail;
- axis semantics cannot be made explicit;
- the route requires network access.

A green result means only:

`QUALIFIED_CRS_CAPABILITY_READY_FOR_SEPARATE_PRODUCTION_PREREGISTRATION`.

It does not admit production use.
