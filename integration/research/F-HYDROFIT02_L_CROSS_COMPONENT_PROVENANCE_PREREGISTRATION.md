# F-HYDROFIT02 P-LPRIOR02 — cross-component depth provenance preregistration

Authority before write: `integration/f-ci-canonical` observed moving under parallel work.
Research evidence: structural audit run `36436168311`.

## Evidence entering this workunit

The exact hydrophysical target interval itself does not contain most desired soil-composition descriptors.

The structural audit established:
- clayContent: 25 values, all nearest depth-bearing ancestor `soilLayer`;
- sandContent: 15, all `soilLayer`;
- siltContent: 2, all `soilLayer`;
- organicMatterContent: 98, split between `InvestigatedInterval` (72) and `soilLayer` (26);
- dryBulkDensity: 117, mostly `InvestigatedInterval` (107), with 10 inside a specific water-retention determination;
- textureClass: 7, under `boreholeSampleDescription`.

No relationship with lambda has been inspected.

## Purpose

Determine whether non-hydraulic descriptors elsewhere in the same BHR-P object can be assigned to a target hydrophysical interval by explicit depth provenance, without using source hydraulic-fit information.

## Frozen matching rule

For each target interval [a,b], candidate source components must expose their own interpretable depth interval [c,d].

Compute overlap length `max(0,min(b,d)-max(a,c))` and target coverage fraction overlap/(b-a).

Classify:
- EXACT: source boundaries equal target boundaries within numerical tolerance;
- CONTAINS_TARGET: one source interval contains the full target;
- TARGET_CONTAINS_SOURCE: target contains one source interval;
- PARTIAL: positive overlap but neither contains the other;
- NONE: no positive overlap.

Do not use nearest depth without overlap.

## Scalar assignment gate

A descriptor is unambiguous for a target only if:
1. at least one structurally admissible source overlaps;
2. all highest-priority admissible sources imply the same scalar/category value, or one source has a uniquely stronger provenance class;
3. no source-fit hydraulic characteristic is used.

Priority is structural, not outcome-based:
EXACT > CONTAINS_TARGET > TARGET_CONTAINS_SOURCE > PARTIAL.

Within equal provenance class, conflicting values make the descriptor AMBIGUOUS. Do not average conflicting values in this workunit.

For PARTIAL matches, report coverage fraction and do not promote to an assigned scalar unless a later workunit preregisters aggregation.

## Source-family restrictions

Composition descriptors (clay, sand, silt) may be sourced from `soilLayer`.
Organic matter must retain source-family identity; do not merge `soilLayer` and unrelated `InvestigatedInterval` values silently.
Bulk density must distinguish direct target-interval values from values nested in a determination.
Texture class is diagnostic only until its depth semantics under `boreholeSampleDescription` are demonstrated.

## Outputs

For every target and descriptor report:
- source component family;
- source depth interval;
- overlap and coverage;
- provenance class;
- candidate values;
- ASSIGNED / AMBIGUOUS / PARTIAL_ONLY / MISSING.

First report coverage and ambiguity. Do not fit or select a lambda prior in this workunit.
