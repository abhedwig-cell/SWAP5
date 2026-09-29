# F-PE-ELASTIC10B — bounded BHR-GT mechanical pilot

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_OBJECT_SEARCH

Parent authorities:
- F-PE-ELASTIC10 BHR-GT target acquisition preregistration;
- schema audit run `36526529454`, PASS;
- OpenAPI SHA-256
  `c47e290b1fcf447f3e766e115c08598e4a888e3f38e9814fbbafaaf01f31795d`.

## Purpose

Determine whether current public BHR-GT objects actually populate enough
settlement/compression data to recover an unload/reload or recompression
mechanical target for SWAP ELAS.

No ELAS value is fitted in this pilot.

## Frozen analysis types

Use only the current official BHR-GT analysis-type values:

- `zetting`;
- `zettingWaterdoorlatendheid`.

These values are bound from current official BHR-GT catalogue/refcode
documentation. No guessed synonyms are permitted.

## Frozen search geometry

Run both analysis types on each of these fixed WGS84 circles, radius 20 km:

1. Utrecht: lat 52.09, lon 5.12;
2. Rotterdam: lat 51.92, lon 4.48;
3. Lelystad: lat 52.52, lon 5.47;
4. Zwolle: lat 52.52, lon 6.09;
5. Arnhem: lat 51.98, lon 5.91;
6. Breda: lat 51.59, lon 4.78.

These are fixed research sampling cells and are unrelated to user location.

## Frozen object-selection rule

1. Execute all 12 searches.
2. Extract every returned BRO-ID.
3. Deduplicate across analysis types and overlapping circles.
4. Sort BRO-ID strings lexicographically.
5. Select exactly the first 5 unique IDs.
6. If fewer than 5 unique IDs exist, fetch all available IDs and classify the
   pilot as coverage-limited.
7. Do not replace an object because its mechanical record is sparse or
   inconvenient.

This rule is frozen before any object XML is inspected.

## Object evidence to record

For each selected object:

- raw XML SHA-256 and byte size;
- BRO-ID;
- bore/sample depth information relevant to analyzed specimens;
- analysis/determination type;
- presence and values of `stepType`;
- loading/unloading step counts;
- `verticalStress` values and units;
- presence of `heightChangeDuringSettlement`;
- SWE DataArray/DataRecord field names;
- number of time/stress/strain observations;
- vertical-strain unit and values where parseable;
- effective/grain-stress fields for CRS where present;
- water-content and volumetric-mass-density fields where present;
- sampling/quality metadata where present.

## Mechanical-target classification

Each object/determination is classified, without fitting:

A. `UNLOAD_RELOAD_TARGET_RECOVERABLE`
   - explicit unload/reload/recompression stress path and sufficient
     stress-strain observations;

B. `CRS_EFFECTIVE_STRESS_TARGET_RECOVERABLE`
   - effective/grain stress and strain path sufficient for local tangent
     compressibility;

C. `VIRGIN_COMPRESSION_ONLY`
   - compression data present but no defensible elastic/recompression branch;

D. `SETTLEMENT_METADATA_ONLY`
   - settlement analysis exists but public object lacks usable series;

E. `NO_SETTLEMENT_TARGET`.

No class is changed after seeing derived ELAS magnitude because no magnitude is
derived in this pilot.

## Success gate

Phase B succeeds if at least one of the five fixed objects is class A or B.

A successful pilot authorizes a corpus-design workunit, not a production
pedotransfer relation.

If no A/B object is found, record the negative result and expand only through a
new preregistered sampling design.
