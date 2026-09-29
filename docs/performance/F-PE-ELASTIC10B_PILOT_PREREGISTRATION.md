# F-PE-ELASTIC10B — bounded BHR-GT mechanical-object pilot preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_OBJECT_RESULTS

Parent:
`F-PE-ELASTIC10_PHASE_A_RESULT.md`.

## Purpose

Verify that current public BHR-GT objects with `analysisType="zetting"` contain
recoverable mechanical load/unload or effective-stress observations sufficient
to construct a future elastic/recompression target.

No fitting or ELAS estimation is allowed in this pilot.

## Frozen search

Use:

`POST /sr/bhrgt/v2/characteristics/searches`

with exactly:

- `analysisType = "zetting"`;
- Netherlands bounding box:
  - lower corner: latitude 50.70, longitude 3.20;
  - upper corner: latitude 53.60, longitude 7.30.

No date, source-holder, density or moisture filter is added.

## Frozen object selection

1. Parse all returned `broId` values.
2. Deduplicate.
3. Sort lexicographically.
4. Select exactly the first three BRO IDs.
5. Fetch those three objects through:
   `GET /sr/bhrgt/v2/objects/{broId}`.

If fewer than three unique ids are returned, fetch all returned ids and classify
the pilot as `LOW_COVERAGE`; do not widen the search after inspecting results.

If zero ids are returned, record `NO_OBJECTS_FOR_FROZEN_QUERY`; do not alter the
query in the same phase.

## Frozen raw evidence

For the search response and each fetched object, record:

- URL/method;
- HTTP status;
- content type;
- byte size;
- SHA-256;
- selected BRO ID.

Preserve raw XML in the workflow artifact.

## Frozen semantic inventory

For each selected object, inventory by XML local name:

- `SettlementCharacteristicsDetermination`;
- `stepType`;
- `verticalStress`;
- `heightChangeDuringSettlement`;
- `verticalStrain`;
- effective/grain-stress fields;
- elapsed-time/time fields;
- volumetric mass density;
- solids density;
- water content;
- organic matter;
- depth/interval fields;
- sampling-quality and determination-method fields.

Also inventory every SWE `DataArray`:

- field names;
- units;
- element count when recoverable;
- raw encoded values length.

No numeric slope is computed in this phase.

## Pilot success classes

### TARGET_PATH_CONFIRMED

At least one object contains:

- a settlement determination; and
- either:
  - explicit load/unload step semantics with stress plus strain/height response,
    or
  - a rate-controlled series with strain plus vertical effective/grain stress.

### TARGET_PATH_PARTIAL

Settlement determinations are present, but the public object lacks enough
stress-path or response information to isolate an elastic/recompression target.

### TARGET_PATH_NOT_POPULATED

The frozen query returns qualifying objects but the selected objects do not
contain populated settlement determinations despite the characteristics filter.

### LOW_COVERAGE / NO_OBJECTS_FOR_FROZEN_QUERY

As defined above.

## Prohibited analysis

Do not:

- compute ELAS;
- fit compression/recompression indices;
- select a value near 1e-6 because it improves SWAP;
- infer missing mechanical quantities from MvG parameters;
- change the frozen query after seeing results;
- open more than the preregistered three objects.

## Next gate

Only `TARGET_PATH_CONFIRMED` authorizes a parser/target-extraction preregistration.

All other outcomes require an explicit negative/partial result before any new
search design.
