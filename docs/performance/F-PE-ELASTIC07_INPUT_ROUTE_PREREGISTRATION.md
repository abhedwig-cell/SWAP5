# F-PE-ELASTIC07 — per-layer input-route restoration preregistration

Date: 2026-09-29

Status: PREREGISTERED_SOURCE_AUDIT_ONLY

## Motivation

The legacy constitutive authority already carries ELAS as supplied soil-hydraulic row 24 (`cofgen(24) -> elas`) and uses a separate explicit `sw_use_elas` activation switch.

The current SWAP5 production Task2 route already initializes the typed MvG authority from the legacy node-local `cofgen(:,1:n)` array. Therefore the numerical ELAS values are already located beside the MvG material parameters at the application seam.

The missing production seam is activation and explicit typed ownership, not invention of a global numerical coefficient.

## Current source facts

Current canonical production Task2 calls:

`initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen(:,1:n), enable_ksatexm_extension=m1_profile)`

and imports `cofgen` from `MOD_MvG`.

Exact corrected B1.10 provenance establishes:
- row 24 exact internal alias: `elas`;
- rows 22:24 copied for every parameterized hydraulic model;
- elasticity use controlled separately by `sw_use_elas`.

F-PE-ELASTIC05 qualifies a typed material-owned interface:
- explicit active switch;
- per-node `specific_elastic_storage(:)`;
- default OFF.

## Research question

How should the existing legacy/application input state expose the old elasticity activation semantics to the F-PE-ELASTIC05 typed material object while preserving the existing per-layer row-24 values exactly?

## Required source audit before any parser change

1. Reconstruct/read exact corrected B1.11 application/parser source.
2. Locate the producer and lifetime of `sw_use_elas`.
3. Identify the user-facing keyword or option that controls it, if one is present.
4. Identify how ELAS values reach `paramvg(24)` and then node-local `cofgen(24,:)`.
5. Establish units from source/manual evidence rather than inference.
6. Determine whether all parameterized hydraulic models share one activation switch or whether model-specific constraints exist.
7. Audit interaction with KSATEXM before permitting a combined active path.

## Candidate application mapping, not yet authorized

If source audit confirms the expected legacy semantics, the minimal mapping is expected to be conceptually:

`legacy elasticity switch -> enable_elastic_storage`

and

`cofgen(24,1:n) -> specific_elastic_storage_input(:)`.

This is a hypothesis only until source provenance closes.

## Explicit exclusions

This workunit must not:
- infer activation from `cofgen(24) /= 0`;
- hard-code `1e-6`;
- introduce a global ELAS numerical setting;
- derive ELAS from MvG parameters;
- change input grammar without exact parser authority;
- enable ELAS+KSATEXM before separate qualification;
- use solver speed to select a physical ELAS value.

## Closure condition

F-PE-ELASTIC07 closes when either:
- the exact legacy input/activation route is source-bound and a bounded typed adapter mapping is preregistered, or
- a concrete provenance gap is recorded as blocker.

Production extraction is a separate successor workunit.
