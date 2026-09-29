# F-PE-ELASTIC24 — offline BRO profile retrieval preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_TOOL_CHANGE

Baseline:
`integration/f-ci-canonical@667c4b76768f760403e0b58383c386686baa3784`

Parent authority:
- `F-PE-ELASTIC23` canonical admission via PR #833 (`maparea_id -> normalsoilprofile_id` typed association);
- `F-PE-ELASTIC22_CLOSURE.md`;
- `F-PE-ELASTIC21_CLOSURE.md`;
- `F-PE-ELASTIC20_CLOSURE.md`;
- `F-PE-ELASTIC19_CLOSURE.md`.

Architecture decision:
ELASTIC22 owns the stateless typed in-memory profile-selection and source-horizon
assembly seam. ELASTIC24 is a separate offline preprocessing work unit and may
perform only local source acquisition for an already explicit profile identity.

## Frozen source authority

Qualified source artifact:
- producer workflow run: `36550782840`;
- producer branch: `research/f-pe-elastic12-bofek-transfer`;
- producer head: `6f81df17d74308fa423f75095cb3d448f95d773c`;
- artifact: `f-pe-elastic12a4-pdok-atom`;
- artifact id: `11024079961`;
- artifact archive SHA-256:
  `f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`.

No silent fallback to a live PDOK/BRO service is allowed.

## Purpose

Add one deterministic offline preprocessing tool that reads a caller-supplied
local frozen BRO Bodemkaart GeoPackage and retrieves exactly one already
selected `normalsoilprofile_id`.

The seam is:

`explicit profile id + frozen local GeoPackage`
-> exact source profile metadata
-> exact ordered source-horizon records.

The output is source-bound preprocessing data. ELASTIC24 does not evaluate
retention, classify material regime, calculate ELAS, map to the SWAP grid or
activate generated priors.

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

No alternate field names, fuzzy matching, coordinate sampling or inferred
profile identity are allowed.

## Profile identity and ordering

The requested profile identity:
- must be an exact positive integer;
- must occur exactly once in `normalsoilprofiles`;
- is never replaced by a nearest/fallback profile.

Selected horizons:
- are ordered by exact integer `layernumber`;
- must be exactly `1..N`;
- start at 0 m within `1e-10 m`;
- are contiguous within `1e-10 m`;
- preserve source depth, block, density, organic-matter and peat values without
  averaging or intentional rounding.

## Required fields and missing-data policy

Per selected horizon:
- top/bottom depth are required finite values;
- `staringseriesblock` is required and integral;
- density is required, finite and positive;
- organic matter may be NULL, otherwise must be finite in [0,100];
- peat type may be NULL and is preserved as source text when present.

Missing required fields fail closed. Optional NULL values remain explicit NULL;
they are not imputed.

## Output and provenance contract

JSON schema:
`swap5.elastic24.bro-profile.v1`.

Top-level output:
- source schema identifier;
- source artifact SHA-256;
- `normalsoilprofile_id`;
- `soilunit`;
- horizon count;
- ordered source horizons.

Each horizon contains only source-bound fields:
- layer number;
- top/bottom depth [m];
- `staringseriesblock`;
- dry density [g/cm3];
- organic matter [%] or null;
- peat type or null.

No derived theta, material regime or ELAS value is permitted.

## Fail-closed and source-scope gate

Fail closed on:
- missing or unreadable file;
- missing required schema;
- missing/duplicate requested profile;
- invalid layer sequence;
- gap/overlap or invalid geometry;
- invalid density/block/organic-matter value.

Source-scope gate:
- no `src/**` change;
- no runtime/kernel/solver/legacy change;
- no network client;
- no latitude/longitude or polygon selection;
- no Staringreeks/ELAS derivation.

## Qualification matrix

A1. required schema exactly supports the declared columns.

A2. all 368 frozen `normalsoilprofile_id` values retrieve explicitly.

A3. all retrieved profiles together contain exactly 1568 source horizons.

A4. every emitted field for every horizon matches an independent direct-SQL
oracle from the same frozen artifact.

A5. known profile `16160` reproduces its exact source identity.

A6. missing and invalid requested profile identity fail closed.

A7. malformed/missing schema and malformed profile geometry fail closed.

A8. repeated retrieval is semantically deterministic.

A9. emitted provenance includes the frozen source artifact SHA-256 exactly.

A10. boundary-hygiene/source-scope checks confirm no network, coordinate
selection, physical derivation or `src/**` mutation.

## Admission boundary

A green ELASTIC24 admits offline acquisition of an already explicit BRO profile
from the frozen local source artifact.

Still outside scope:
- location-to-profile selection;
- BOFEK unit/profile choice policy;
- automatic profile selection;
- user-facing SWAP input syntax;
- parsing ELASTIC24 JSON inside the Richards runtime;
- automatic generated-prior request.

## Precursor evidence

A same-semantics precursor, before the ELASTIC23 naming collision was resolved,
passed workflow run `36567392350` / job `109402603786` on commit
`7c9e77a839f060f0370c7e35b2b5ac3382df2249`. It is supporting evidence only;
ELASTIC24 requires a clean rerun on this branch before admission.
