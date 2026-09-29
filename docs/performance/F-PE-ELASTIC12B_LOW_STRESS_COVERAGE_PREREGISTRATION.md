# F-PE-ELASTIC12B — low-stress BHR-GT elastic-evidence coverage

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_OPENING_NONSELECTED_GRID_OBJECTS

Parents:
- F-PE-ELASTIC10D fixed 12-cell Dutch discovery;
- F-PE-ELASTIC10E/R1 qualified mechanical target extraction;
- F-PE-ELASTIC11D independent deep-mechanical holdout;
- F-PE-ELASTIC12A root-zone transfer result.

## Motivation

F-PE-ELASTIC12A established that the shallow, saturated root-zone stress regime
does not overlap the qualified M5 calibration stress range.

The existing 47-target BHR-GT corpus contains:

- minimum R2 target endpoint about `31.4 kPa`;
- minimum R3 target endpoint about `40.95 kPa`;
- no target midpoint <= `25 kPa`.

The already inspected 16-object target-ready sample does contain many loading
observations below 25 kPa, but no explicit unload/reload step at <=25 kPa.

Loading-only observations are not elastic-storage targets.

## Frozen discovery population

Do not define a new geographic search.

Reuse the exact 12 ELASTIC10D search responses from workflow run
`36529870974`, artifact:

`f-pe-elastic10d-bhrgt-grid`

artifact id:
`11016296681`

artifact digest:
`sha256:59c184e964b769589da58ec8e07f391ae6cf03c720425df586b800ca0c54c45e`.

The frozen search responses contain exactly 86 unique BRO IDs.

F-PE-ELASTIC12B opens **all 86 unique IDs** from those already-fixed responses,
including the 16 objects previously selected by the first-two-per-cell rule.

No:
- new search center;
- radius change;
- replacement object;
- result-dependent expansion;
- user-location information.

## Source acquisition

For each of the exact 86 IDs:

`GET /sr/bhrgt/v2/objects/{broId}`

from the official public BHR-GT service.

Persist:
- BRO ID;
- current raw response bytes;
- byte size;
- SHA-256;
- fetch status.

For the 16 previously frozen ELASTIC10D objects, current bytes may differ from
the historical dispatch wrapper. Mechanical identity must therefore be compared
semantically, not by requiring whole-response byte identity.

## Mechanical semantic authority

Use the already qualified BHR-GT definitions:

### R2

Load-controlled settlement determination.

An elastic candidate requires an explicit unload/reload step
(`ontlastingstap` / unload) and source-bound vertical stress endpoints.

Loading-only steps are not elastic candidates.

### R3

Rate-controlled/effective-stress settlement determination.

An elastic candidate requires an explicit unload step and a source-bound
`StressAtSpecificSettlement.xml` series containing vertical effective stress
and vertical strain.

Loading or relaxation rows alone do not qualify.

## Frozen low-stress definitions

### LS25-TOUCH

Diagnostic only.

An explicit unload path reaches effective/vertical stress <= `25 kPa`.

This is not sufficient to derive a root-zone target.

For R2:
- unload endpoint verticalStress <= 25 kPa.

For R3:
- at least one finite verticalEffectiveStress row during an explicit unload step
  is <= 25 kPa.

### LS25-LOCAL

Primary target-readiness criterion.

The available source data support an elastic/recompression slope localized to
the <=25 kPa regime.

R2 qualifies only if the frozen adjacent unload secant has:

`(stress_start + stress_end)/2 <= 25 kPa`.

No non-adjacent or loading-envelope points may be substituted.

R3 qualifies only if one explicit unload step contains:

- at least 3 finite rows with verticalEffectiveStress <= 25 kPa;
- at least 2 distinct positive effective stresses in that subset;
- finite vertical strain for those rows.

F-PE-ELASTIC12B does **not** calculate the slope even when these conditions are
met. It only freezes candidate identity for a successor target-extraction
workunit.

### LS50-TRANSITION

Diagnostic near-domain criterion, not root-zone qualification.

Same structural definitions as above, evaluated at <=50 kPa.

This quantifies how close the public data come to the low-stress regime without
silently redefining the root-zone threshold.

## Required outputs

For all 86 objects report:

- fetch success/failure;
- settlement determination count;
- R2/R3 determination count;
- loading-only low-stress observations;
- explicit unload step count;
- minimum unload stress;
- LS25-TOUCH count;
- LS25-LOCAL candidate count;
- LS50-TRANSITION candidate count.

Persist exact candidate identities:

- BRO ID;
- physical determination index;
- step index;
- route;
- stress-range evidence;
- series row counts where applicable.

## Success classes

### LOW_STRESS_TARGET_ROUTE_CONFIRMED

At least 3 distinct BRO objects satisfy LS25-LOCAL.

This is sufficient to preregister a separate low-stress mechanical target
extraction and object-grouped falsification study.

### LOW_STRESS_TARGET_ROUTE_SPARSE

One or two distinct BRO objects satisfy LS25-LOCAL.

Record as sparse evidence. No deterministic root-zone parameterization is
identified.

### LOW_STRESS_TOUCH_ONLY

No LS25-LOCAL object, but one or more LS25-TOUCH objects.

This means public BHR-GT reaches low stress but lacks enough local unload
resolution for the required elastic target.

### LOW_STRESS_MECHANICAL_BLOCKER

No LS25-TOUCH objects in the frozen 86-object population.

Record the negative result. Do not extrapolate M5 below its qualified stress
domain.

### INCOMPLETE

Any object fetch/parse failure that prevents complete 86-object accounting.

Do not treat incomplete as negative coverage.

## Prohibited

Do not:

- calculate or fit a new Ssk/ELAS relation in this workunit;
- relax 25 kPa after seeing results;
- use low-stress loading-only data as elastic targets;
- infer unload behavior from curve shape without source-bound stepType;
- merge rows across determination steps;
- change the frozen M5 coefficients;
- use SWAP runtime performance as target evidence;
- create a production ELAS value.

## Downstream rule

Only if at least one LS25-LOCAL candidate exists may a separate workunit derive
low-stress mechanical targets.

Three or more distinct objects are required before any object-grouped predictive
model or M5 low-stress falsification can be called more than exploratory.

Otherwise the physical line stops at a documented low-stress evidence limit.
