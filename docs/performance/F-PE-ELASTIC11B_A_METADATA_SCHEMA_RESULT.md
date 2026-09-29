# F-PE-ELASTIC11B-A — BHR-GT predictor metadata schema result

Date: 2026-09-29

Status: PREDICTOR_METADATA_SOURCE_BOUND

Parent:
- F-PE-ELASTIC10D frozen 16-object BHR-GT corpus;
- F-PE-ELASTIC10E-R1 reconciled 47-target identity;
- F-PE-ELASTIC11B predictor-corpus preregistration.

## Purpose

Bind the metadata fields allowed for the predictor corpus before any predictor
record is generated or any model is fit.

The predictor workunit uses the frozen BHR-GT object bytes. The current objects
are BHR-GT XML with `bhrgtcommon/2.1` / `dsbhr-gt/2.1` namespaces.

## Source-bound predictor fields

The official BHR-GT catalogue and the frozen object XML jointly bind:

### Interval geometry

- `beginDepth` / `endDepth`
- physical meaning: investigated interval depth bounds;
- frozen-object unit: `m`.

Derived midpoint depth is permitted as:
`0.5 * (beginDepth + endDepth)`
only when both bounds are individually ASSIGNED.

### Sample quality

- `sampleQuality`
- code space: `urn:bro:bhrgt:SampleQuality`.

### Moisture state

- `sampleMoistness`
- code space: `urn:bro:bhrgt:SampleMoistness`.

The same investigated interval may contain repeated identical values from
multiple determinations. Identical repetitions collapse to one ASSIGNED value;
different values at equal scope are AMBIGUOUS.

### Water content

- `waterContent`
- physical meaning: measured water content;
- frozen-object unit: `%`.

### Volumetric mass density

- `volumetricMassDensity`
- physical meaning: volumetric mass density;
- frozen-object unit: `g/cm3`.

This field is not relabelled as dry bulk density.

### Solids density

- `volumetricMassDensitySolids`
- physical meaning: volumetric mass density of solids;
- frozen-object unit: `g/cm3`.

No porosity is derived in F-PE-ELASTIC11B because a porosity conversion rule was
not preregistered and the available volumetric mass density is not automatically
equivalent to dry density.

### Organic matter

- `organicMatterContent`
- frozen-object unit: `%`, when measured;
- `organicMatterContentClass`
- code space: `urn:bro:bhrgt:OrganicMatterContentClass`, when only a class is
  available.

Measured percentage and class remain separate predictors.

### Material classification

- `geotechnicalSoilName`
- code space: `urn:bro:bhrgt:GeotechnicalSoilName`.

### Settlement test method/procedure

At the physical `SettlementCharacteristicsDetermination` scope:

- `determinationMethod`
  code space `urn:bro:bhrgt:DeterminationMethod`;
- `determinationProcedure`
  code space `urn:bro:bhrgt:DeterminationProcedure`.

### Mechanical-state predictors

Mechanical stress predictors are reconstructed from the same raw source records
used to identify the frozen target, without reading `mv` or `Ssk`.

R2:
- previous usable step `verticalStress`, kPa;
- unload step `verticalStress`, kPa;
- unload stress span and midpoint are allowed deterministic derivations.

R3:
- first and last finite `verticalEffectiveStress` in the frozen unload
  `StressAtSpecificSettlement.xml` step, kPa;
- unload effective-stress span and midpoint are allowed deterministic
  derivations.

The R3 SWE column order/unit authority remains F-PE-ELASTIC11A.

## Scope rule

For interval/material descriptors use the nearest enclosing
`investigatedInterval` of the physical settlement determination.

Within that scope:

- zero source values -> MISSING;
- one unique source-bound value -> ASSIGNED;
- repeated identical values -> ASSIGNED;
- multiple distinct values -> AMBIGUOUS;
- unexpected unit or code space -> INVALID and fail the extraction.

No nearest-neighbour, object-level fallback or imputation is allowed.

## Frozen pre-extraction coverage observation

A bounded read-only audit of the 47 reconciled target identities found:

- begin/end depth: 47/47 ASSIGNED;
- sample quality: 47/47 ASSIGNED;
- sample moistness: 47/47 ASSIGNED;
- water content: 47/47 ASSIGNED;
- volumetric mass density: 47/47 ASSIGNED;
- solids density: 38/47 ASSIGNED;
- measured organic matter: 2/47 ASSIGNED;
- geotechnical soil name: 8/47 ASSIGNED;
- organic-matter class: 4/47 ASSIGNED;
- determination method/procedure: 47/47 ASSIGNED.

These observations are frozen before predictor-corpus extraction. They are
coverage expectations, not model-selection criteria.

## Statistical boundary

The object-level 8/8 calibration/holdout split in
F-PE-ELASTIC11B remains unchanged.

This schema result does not:
- inspect holdout target magnitudes for model selection;
- fit a model;
- define a production ELAS rule;
- derive porosity;
- import MvG parameters;
- use SWAP runtime performance.

## Decision

Classification:

`BHR_GT_PREDICTOR_METADATA_SCHEMA_BOUND`.

F-PE-ELASTIC11B may now extract the preregistered source-traceable predictor
corpus.
