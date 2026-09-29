# F-PE-ELASTIC11B — BHR-GT predictor corpus and object holdout preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PREDICTOR_EXTRACTION_OR_MODEL_FIT

Parent authorities:
- F-PE-ELASTIC10D fixed 16-object national BHR-GT sample;
- F-PE-ELASTIC10E qualified 47-target mechanical Ssk corpus;
- F-PE-ELASTIC11A target schema binding;
- F-PE-ELASTIC06B physical storage/consolidation identity.

## Purpose

Prepare an independently source-bound predictor corpus for later physical
ELAS/Ssk modelling without target leakage.

This workunit may extract and qualify predictor metadata.
It may not fit a predictive model.

## Grouping unit

The irreducible statistical group is the BRO object.

All determinations and all mechanical targets from one BRO-ID remain in the same
calibration or holdout group.

No target row from one object may appear in calibration while another row from
the same object appears in holdout.

## Frozen geographic object split

The F-PE-ELASTIC10D sample contains exactly two frozen objects for each of eight
target-ready cells.

For every cell, sort its two BRO-IDs lexicographically.

- first BRO-ID -> characterization/calibration group;
- second BRO-ID -> frozen holdout group.

This rule is independent of target magnitude, target count and observed Ssk.

### Characterization / calibration objects

- Wageningen: BHR000000462600
- Utrecht: BHR000000456021
- Zwolle: BHR000000356939
- Assen: BHR000000453770
- Leeuwarden: BHR000000380280
- Alkmaar: BHR000000466468
- Rotterdam: BHR000000353613
- Lelystad: BHR000000470062

### Frozen object holdouts

- Wageningen: BHR000000462646
- Utrecht: BHR000000456023
- Zwolle: BHR000000356940
- Assen: BHR000000453775
- Leeuwarden: BHR000000380281
- Alkmaar: BHR000000466469
- Rotterdam: BHR000000353614
- Lelystad: BHR000000470064

The holdout target values already exist in the extraction artifact because
F-PE-ELASTIC10E established the target-extraction method on all 16 objects.
From this preregistration onward they must not be consulted for predictor,
transform, feature, threshold or model selection.

## Predictor source

Use only metadata already present in the frozen BHR-GT object bytes.

Candidate source-bound fields are restricted to mechanical/pedological variables
known from the official BHR-GT model and observed object inventory, including
where available:

- investigated interval begin/end depth;
- volumetric mass density / dry or wet bulk-density field when semantics are
  source-bound;
- solids density;
- water content;
- sample moisture state;
- organic matter;
- soil/material classification;
- sample quality/disturbance class;
- determination method;
- route R2/R3;
- source stress interval and representative stress level.

No BHR-P or spatial-neighbour join is allowed in this workunit.

## Descriptor extraction rules

1. Bind each metadata field to official BHR-GT schema/catalogue semantics and
   units before using the value.
2. Preserve raw value, unit and provenance path.
3. Do not impute a missing descriptor.
4. Do not average conflicting values across scopes.
5. Prefer the narrowest enclosing specimen/investigated-interval scope.
6. If multiple source-bound values exist at equal scope and cannot be
   disambiguated, mark the descriptor AMBIGUOUS.
7. Object-level constant metadata may be copied to multiple targets from that
   object but does not create additional independent samples.
8. Target Ssk values are not read by descriptor-selection code.

## Frozen initial predictor families

The first modelling phase, in a later workunit, may consider only:

### Mechanical state
- log10 representative effective/vertical stress;
- unload stress span;
- depth or midpoint depth.

### Structure / density
- source-bound bulk density;
- source-bound solids density;
- porosity only when both required density quantities have source-bound
  compatible semantics and the derivation is preregistered.

### Composition / state
- source-bound organic matter;
- source-bound water content or moisture state;
- source-bound material/classification terms;
- sample quality.

### Method
- R2 versus R3 route;
- determination method/procedure.

No MvG Alpha, N, Lambda, Ksat or SWAP solver-performance variable is an allowed
physical predictor in this workunit.

## Target used later

The primary future target is:

`log10(Ssk_cm_inv)`.

A later model may alternatively predict `log10(mv)`, but that choice must be
frozen before fitting.

No model may combine multiple target rows from one object as though they were
independent holdout objects.

## Predictor-corpus success criteria

F-PE-ELASTIC11B succeeds if it produces:

- one source-traceable predictor record per mechanical target;
- explicit MISSING/AMBIGUOUS states;
- object/group membership;
- field coverage counts for calibration and holdout separately;
- no target-dependent filtering or feature selection.

A sparse predictor corpus is a valid negative result.

## Modelling boundary

No regression, tree, neural network, soil-class lookup, fitted coefficient or
production ELAS rule is allowed until a successor workunit freezes:

- target transformation;
- predictor subset;
- model family;
- calibration objective;
- object-grouped cross-validation;
- holdout acceptance metrics.

## BOFEK / root-zone boundary

The BHR-GT sample depth range is predominantly below agricultural root-zone
depth.

Any later transfer to BOFEK/Staringreeks must therefore be a separate,
preregistered transportability study.

The 8 BHR-GT holdout objects validate a mechanical target model within the
BHR-GT population; they do not by themselves validate topsoil transfer.
