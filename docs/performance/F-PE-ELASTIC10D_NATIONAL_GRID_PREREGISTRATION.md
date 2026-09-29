# F-PE-ELASTIC10D — fixed 12-cell Dutch BHR-GT settlement discovery

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_NATIONAL_GRID_SEARCH

Parents:
- F-PE-ELASTIC10 Phase-A schema authority;
- F-PE-ELASTIC10B parser/service-contract adjudications;
- F-PE-ELASTIC10C valid local 10-km coverage negative.

## Purpose

Test whether public BHR-GT settlement registrations with source-bound mechanical
payloads are discoverable across a geographically distributed, deterministic
Dutch pilot grid.

This is still target discovery. No ELAS value, mechanical slope or pedotransfer
relation is fitted.

## Geographic authority

The 12 search centers are not selected from F-PE-ELASTIC10 results.

They are copied unchanged from the bounded national BHR-P discovery grid that
already existed in:
`.github/workflows/f-hydrofit02-bro.yml`
before the ELASTIC10C result.

Fixed center order:

1. Wageningen: 51.97, 5.67
2. Utrecht: 52.09, 5.12
3. Zwolle: 52.52, 6.09
4. Assen: 52.99, 6.56
5. Leeuwarden: 53.20, 5.80
6. Alkmaar: 52.63, 4.75
7. Rotterdam: 51.92, 4.48
8. Breda: 51.59, 4.78
9. Eindhoven: 51.44, 5.48
10. Venlo: 51.37, 6.17
11. Arnhem: 51.98, 5.91
12. Lelystad: 52.52, 5.47

The grid is a pre-existing research sampling frame, not a user-location-derived
design.

## Frozen search contract

For every one of the 12 centers, execute exactly one:

`POST /sr/bhrgt/v2/characteristics/searches`

with:

- `analysisType = "zetting"`;
- enclosing-circle radius exactly `10.0 km`.

All 12 cells are queried even after a non-empty result is found.

No center replacement, radius expansion or additional cell is allowed in this
workunit.

## Frozen object selection

For each center independently:

1. parse only XML local-name `broId`;
2. deduplicate;
3. lexicographically sort;
4. take at most the first two BRO-IDs.

Then process centers in the fixed order above.

If an object appears in more than one cell:
- first center in the frozen order owns the object;
- later duplicates are skipped;
- they are not replaced by a third object from the later cell.

Maximum unique object sample:
`24`.

This rule is frozen before any ELASTIC10D search response is inspected.

## Object acquisition

Retrieve each fixed selected unique object only through:

`GET /sr/bhrgt/v2/objects/{broId}`.

Persist:
- center/cell name;
- search request body;
- HTTP status;
- response byte size;
- SHA-256;
- retrieval time;
- full raw search response;
- raw object response and manifest.

Any search HTTP error or selected-object fetch error makes the pilot incomplete.
It is not interpreted as an empty/negative cell.

## Mechanical readiness authority

Reuse the F-PE-ELASTIC10C determination-scoped parser and frozen classes.

Each `SettlementCharacteristicsDetermination` is classified independently.

### R0
No source-bound usable settlement mechanical payload.

### R1
Loading-only mechanical curve or mechanical evidence insufficient for
unload/reload/effective-stress target extraction.

### R2
One settlement determination contains all of:

- at least two determination steps;
- at least two step-local finite vertical stresses;
- at least two distinct vertical stresses;
- non-empty step-local
  `heightChangeDuringSettlement` bound to
  `HeightAtSpecificState.xml` for at least two usable stress states;
- at least one usable step explicitly unload/reload through source-bound
  `stepType`.

### R3
One settlement determination contains a non-empty
`stressChangeDuringSettlement` series bound to
`StressAtSpecificSettlement.xml`, providing the catalogue-authorized
effective/grain-stress + strain semantics.

If step-local association is ambiguous, classify downward.

## Frozen outputs

Report:

- 12 per-cell BRO-ID counts;
- total unique BRO-ID count returned across cells;
- selected unique object IDs and owning cells;
- selected object fetch success;
- per-object settlement-determination count;
- per-determination R0/R1/R2/R3;
- object-level maximum readiness;
- number of R2/R3 target-ready objects;
- coverage of depth, density, moisture, water content and organic-matter
  metadata.

## Success / negative outcomes

### TARGET_READY
At least one fixed selected object is R2 or R3.

### COVERAGE_PRESENT_R0_R1_ONLY
At least one object is selected and fetched, but no selected object is R2/R3.

### NATIONAL_GRID_NO_OBJECTS
All 12 valid 10-km searches return HTTP 200 and zero BRO-IDs.

This is a negative for this 12-cell pilot only, not proof of national absence.

### INCOMPLETE
Any search service error, XML search parse error or selected-object fetch/parse
error.

## Prohibited

Do not:

- add or move centers;
- use any user's location;
- expand beyond 10 km;
- stop after the first non-empty cell;
- inspect objects outside the fixed first-two-per-cell rule;
- replace duplicate selections with extra objects;
- alter R2/R3 thresholds after observing objects;
- compute a production ELAS;
- fit mechanical or hydraulic pedotransfer functions;
- use SWAP solver performance as target evidence.

## Downstream rule

If TARGET_READY:
preregister a separate target-extraction workunit before calculating any
compressibility or ELAS quantity.

If COVERAGE_PRESENT_R0_R1_ONLY or NATIONAL_GRID_NO_OBJECTS:
record the negative result before considering another source or sampling frame.
