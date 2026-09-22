# GC-RZM06C02 native-cm F-GC carrier result

Date: 2026-09-22  
Preregistration: `337d32821a25aaebf5eddc9d84f5724c94d249e9`  
Qualified evidence workflow: `35736355085`, job `106774650222`  
Production changes: none

## Decision

C02 is closed as:

`QUALIFIED_FROZEN_INITIALIZATION_NO_GO__H2_NOT_PROBED`.

The workflow is green because the frozen scientific no-go is now recorded as evidence rather than escaping as an unclassified test crash.

## Failure location

The synthetic 17-node native-centimetre carrier does not pass the inherited F-GC44 predictor initialization at the frozen point:

- predictor duration: `1e-4 d`;
- predictor qbot: `1e-6 cm d^-1`.

Diagnostics:

- 9 attempts;
- 8 transaction retries;
- 9 solver rejections;
- 9 internal retries;
- 0 accepted substeps;
- 0 temporal rejections;
- 0 mass rejections.

Initialization returns status `104`, meaning the predictor result never completed.

This is therefore a solver-admissibility failure under the frozen synthetic carrier, not a temporal-certificate or mass-accounting failure.

## Consequence

The preregistered baseline zero-top interval and forcing map are not reached. H2 is not probed.

No predictor qbot, duration, solver tolerance, retry budget, temporal budget or grid is retuned after seeing the result.

C02's own activation rule for a subsequent native-cm H2 construction is therefore not satisfied.

## Relationship to C01

This no-go does not block the program. C01 independently qualified the existing F-ROM1A-I0 16x10 cm Reference carrier, which has stronger pre-existing transaction authority and an existing 768-state accepted-state library.

The synthetic C02 route is retained as useful negative evidence and as a warning that simply transplanting F-GC44 predictor initialization onto a richer vertical grid is not automatic.

The shared research bridge changes were regression-checked by RZM06A workflow run `35735102668`, which passed after the C02 unit-support changes.

No production claim follows from C02.
