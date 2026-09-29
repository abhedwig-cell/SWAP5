# F-PE-ELASTIC10C — service-valid 10-km BHR-GT settlement pilot

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_10KM_SEARCH

Parents:
- F-PE-ELASTIC10 Phase-A schema authority;
- F-PE-ELASTIC10B attempt-1 invalid-parser adjudication;
- F-PE-ELASTIC10B attempt-2 service-radius result.

## Purpose

Complete the bounded settlement-target pilot at the largest search radius
accepted by the current official BHR-GT characteristics service.

No ELAS value or mechanical slope is fitted here.

## Frozen query

Endpoint:

`POST /sr/bhrgt/v2/characteristics/searches`.

Criteria:

- `analysisType = "zetting"`;
- enclosing-circle center:
  - latitude `52.038297852`;
  - longitude `5.31447958948`;
- radius: exactly `10.0 km`.

The center remains the official OpenAPI example location and is unrelated to
user location.

The 10-km radius is source-bound by the official rejection from attempt 2:

`radius ... mag niet groter zijn dan 10`.

## Frozen object selection

If the 10-km response contains objects:

1. extract only parsed XML elements with local name `broId`;
2. deduplicate;
3. sort lexicographically;
4. select at most the first five;
5. retrieve exactly those objects through
   `GET /sr/bhrgt/v2/objects/{broId}`.

No replacement after inspection.

If the response is empty, record a valid negative for this single 10-km pilot
cell. Do not expand the geography in this workunit.

## Frozen target-readiness classes

Retain the F-PE-ELASTIC10B classes unchanged:

- R0: no usable settlement payload;
- R1: loading-only mechanical curve;
- R2: explicit unload/reload target candidate;
- R3: effective-stress target candidate.

R2/R3 qualify a successor corpus-design workunit.

R0/R1-only is a valid negative target-readiness result for the fixed selected
objects.

## SWE interpretation

Catalogue-bound SWE references are recognized as mechanical-field authority:

- `HeightAtSpecificState.xml` supplies settlement-state strain semantics;
- `StressAtSpecificSettlement.xml` supplies stress/effective-stress settlement
  semantics where present.

Categorical `stepType` may be represented through text or xlink reference; both
are source-bound before classification.

## Success condition

At least one fixed selected object is R2 or R3.

A zero-object result is a valid local coverage negative and must not be
generalized to national BHR-GT availability.
