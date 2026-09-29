# F-PE-ELASTIC10B — bounded BHR-GT settlement-object pilot

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_OBJECT_SEARCH

Parent:
F-PE-ELASTIC10 Phase-A schema result.

## Purpose

Test whether real public BHR-GT objects populate the settlement stress/strain
structures sufficiently to recover an elastic/recompression target.

No fitted ELAS relation is allowed in this pilot.

## Frozen discovery query

Use only the official public endpoint:

`POST /sr/bhrgt/v2/characteristics/searches`.

Fixed criteria:

- `analysisType = "zetting"`;
- enclosing-circle center:
  - lat `52.038297852`;
  - lon `5.31447958948`;
- search radii, in order:
  - 0.5 km;
  - 5 km;
  - 10 km.

The center is the official OpenAPI example, not a user-derived location.

Stop at the first radius returning at least one BRO-ID.

If all three valid radii are empty, record a negative bounded pilot. Do not
expand the radius in the same workunit.

The originally preregistered third radius was 25 km. A valid service response
later established that the official BHR-GT endpoint rejects enclosing-circle
radius values greater than 10 km. Before any valid third-radius population
result, the third radius is therefore corrected to the largest API-admitted
value, 10 km. This is a service-contract correction, not a data-driven expansion
or changed success threshold.

## Frozen object sample

From the first non-empty search response:

1. extract unique BRO-IDs by XML local-name;
2. sort BRO-IDs lexicographically;
3. select at most the first five;
4. retrieve only those objects through
   `GET /sr/bhrgt/v2/objects/{broId}`.

Persist for each request:
- URL/query body;
- HTTP status;
- byte size;
- SHA-256;
- retrieval time.

No hand selection after inspecting mechanical results.

## Frozen object audit

For each selected object, record counts and source paths for:

- `SettlementCharacteristicsDetermination`;
- determination method/procedure;
- investigated interval begin/end depth;
- sample moisture;
- sample quality/disturbance metadata;
- volumetric mass density;
- solids density where present;
- water content;
- organic matter where present;
- determination steps;
- step number;
- step type;
- vertical stress;
- deformation rate;
- height/settlement time series;
- stress-during-settlement time series;
- SWE DataArray row/field metadata.

For rate-controlled settlement also record:

- vertical effective/grain stress;
- pore-water-pressure difference.

## Target-readiness classes

Each settlement determination is classified without calculating ELAS:

### R0 — no usable settlement payload
Determination exists but no recoverable stress/strain series.

### R1 — loading-only mechanical curve
Stress/strain data exist but no explicit unload/reload information.

### R2 — unload/reload target candidate
Explicit unload/reload step plus sufficient vertical stress and strain data to
estimate at least one constrained recompression slope.

### R3 — effective-stress target candidate
CRS/equivalent data provide vertical effective/grain stress and strain with
sufficient resolution for a local tangent.

R2/R3 are target-ready for a successor workunit. R1 is informative for
compression but not sufficient to identify legacy elastic storage by itself.

## Prohibited in this pilot

Do not:

- compute a production ELAS;
- fit a pedotransfer relation;
- use solver performance;
- substitute virgin loading slope for recompression;
- expand beyond five objects;
- expand beyond the service-valid 10 km maximum if no data;
- silently repair malformed SWE series.

## Success condition

Phase B succeeds if at least one selected object reaches R2 or R3.

A clean R0/R1-only result is a valid negative pilot and must be recorded.
