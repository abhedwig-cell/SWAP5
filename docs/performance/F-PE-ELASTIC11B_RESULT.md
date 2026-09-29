# F-PE-ELASTIC11B — BHR-GT predictor corpus result

Date: 2026-09-29

Status: PREDICTOR_CORPUS_QUALIFIED_HOLDOUTS_CLOSED

Workflow:
`F-PE-ELASTIC11B BHR-GT predictor corpus`

Run:
`36533233002`

Job:
`109291397728`

Qualified head:
`759fb1ab1cc172d8d832485e1eb1c61c676e721c`

Artifact:
`f-pe-elastic11b-predictor-corpus`

Artifact id:
`11016877418`

Artifact digest:
`sha256:c0f88aeba6f77d0aebc11ef16eaec6ecb13aa2df7c45dc479c45daa87a891691`

Parent target authority:
F-PE-ELASTIC10E-R1, 47 numerical targets with exact physical-determination
provenance.

## Object grouping

The preregistered object-level split is preserved exactly.

Calibration:
8 BRO objects, 22 predictor rows.

Holdout:
8 BRO objects, 25 predictor rows.

No BRO object occurs in both groups.

Multiple target rows from one physical object remain one statistical group.

Marker:
`F_PE_ELASTIC11B_T1_OBJECT_GROUPING=PASS`.

## Target-blind extraction

The predictor extractor reads only the target identity and mechanical stress
context required to address the same physical determination/step.

It does not copy or inspect:
- `mv`;
- `Ssk`;
- target strain endpoints or strain deltas.

The predictor output contains no target-magnitude field.

Marker:
`F_PE_ELASTIC11B_T4_NO_TARGET_LEAKAGE=PASS`.

## Source scope

All material/specimen descriptors are taken only from the nearest enclosing
`investigatedInterval` of the physical settlement determination.

Determination method/procedure are read only from the physical
`SettlementCharacteristicsDetermination`.

Rules:
- zero source values -> MISSING;
- one unique source value -> ASSIGNED;
- repeated identical values -> ASSIGNED;
- distinct equal-scope values -> AMBIGUOUS;
- unexpected units/codelists -> fail closed.

Marker:
`F_PE_ELASTIC11B_T2_SOURCE_SCOPE=PASS`.

## Determinism

The corpus was extracted twice independently.

The complete output trees were byte-identical.

Marker:
`F_PE_ELASTIC11B_T3_DETERMINISM=PASS`.

## Coverage

Across all 47 predictor rows:

Fully assigned:
- begin depth: 47/47;
- end depth: 47/47;
- source-bound midpoint depth: 47/47;
- volumetric mass density: 47/47;
- water content: 47/47;
- sample quality: 47/47;
- sample moistness: 47/47;
- determination method: 47/47;
- determination procedure: 47/47.

Partly assigned:
- solids density: 38/47;
- geotechnical soil name: 8/47;
- organic-matter class: 4/47;
- measured organic matter: 2/47.

There are no ambiguous values in this frozen corpus for the selected fields.

### Calibration coverage

22 rows from 8 objects:

- depth bounds/midpoint: 22/22;
- volumetric mass density: 22/22;
- water content: 22/22;
- sample quality/moistness: 22/22;
- determination method/procedure: 22/22;
- solids density: 17/22;
- geotechnical soil name: 4/22;
- organic-matter class: 2/22;
- measured organic matter: 1/22.

### Holdout coverage

25 rows from 8 objects:

- depth bounds/midpoint: 25/25;
- volumetric mass density: 25/25;
- water content: 25/25;
- sample quality/moistness: 25/25;
- determination method/procedure: 25/25;
- solids density: 21/25;
- geotechnical soil name: 4/25;
- organic-matter class: 2/25;
- measured organic matter: 1/25.

The comparable coverage structure between calibration and holdout is useful,
but holdout target magnitudes remain closed.

## Predictor implications

The corpus does not support a rich multivariate pedological model.

The complete candidate core is:

- depth;
- volumetric mass density;
- water content;
- representative unload/effective-stress level;
- unload stress span;
- R2/R3 route;
- determination method/procedure;
- sample quality/moistness.

Solids density may be studied only in a reduced complete-case sensitivity
analysis or with an explicitly preregistered missingness treatment.

Organic matter and detailed soil classification are too sparse in this 16-object
mechanical corpus to support fitted coefficients.

No porosity is derived because the source-bound
`volumetricMassDensity` is not silently reinterpreted as dry bulk density.

## Population boundary

This remains a geotechnical subsurface corpus.

The predictor records inherit the F-PE-ELASTIC10E depth boundary and are not
direct BOFEK/root-zone calibration authority.

## Decision

F-PE-ELASTIC11B succeeds.

Classification:

`BHR_GT_TARGET_BLIND_PREDICTOR_CORPUS_QUALIFIED`.

A successor model-selection workunit may now be preregistered, but it must:

- use calibration objects only for predictor/model selection;
- use object-grouped validation;
- freeze target transformation, predictor subset, model families and holdout
  metrics before opening any holdout target value;
- retain depth/stress applicability;
- not use MvG or SWAP runtime performance as physical predictors.
