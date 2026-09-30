# F-PE-NLGLOB14Z43 closeout — moving-interface manager production-admission candidate preparation

Date: 2026-09-30

Final status:

`Z43_HOLDOUT_PHYSICAL_FAILURE`

Qualification authority:

- workflow run `36775559850`;
- job `110092451445`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z43 does not qualify the production-admission candidate because one frozen heterogeneous trajectory is not reference-valid.

The default-off configuration seam passes.

O05 passes all physical, operational and timing gates with about 6.7% wall-clock gain.

The frozen O14 N=64 reference trajectory fails before an adaptive comparison can be made.

Therefore the admission evidence is incomplete.

## Scientific interpretation

This closeout does not falsify the moving-interface manager.

The failure is upstream of manager comparison: the selected full-reference O14 trajectory is itself invalid under the exact frozen initial state / forcing / dt combination.

Prior O14 and B12 same-origin reduced-physics/service evidence remains valid.

## Direct successor

Open:

`F-PE-NLGLOB14Z44 — heterogeneous reference-validity fixture selection`.

Z44 must be reference-only.

It should:

1. freeze a small candidate grid for O14 and B12;
2. run only the full N=64 Heritage/reference trajectory;
3. use a preregistered deterministic selection order;
4. identify at most one valid trajectory fixture per material;
5. persist the selected fixtures before any new adaptive-manager comparison.

Do not repair Z43 in place.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z43

BRANCH: `research/f-pe-nlglob14z43-admission-candidate`

RESULT POSTIMAGE BEFORE CLOSEOUT: `307db101a0ff4ba024a9ae7afb2730d21f315977`

QUALIFICATION STATUS: `Z43_HOLDOUT_PHYSICAL_FAILURE`

NEXT SAFE STEP: Z44 reference-only heterogeneous fixture selection.

## Production boundary

No admission.

The moving-interface configuration remains default-off.

`LEGACY_NUMERICS` remains production default.
