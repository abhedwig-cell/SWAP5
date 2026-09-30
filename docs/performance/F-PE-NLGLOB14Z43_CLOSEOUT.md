# F-PE-NLGLOB14Z43 closeout — moving-interface manager production-admission candidate preparation

Date: 2026-09-30

Final status:

`Z43_HOLDOUT_PHYSICAL_MISMATCH`

Qualification authority:

- workflow run `36775798082`;
- job `110093253754`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z43 does not qualify a production-admission candidate.

The configuration seam passes and H1 remains strongly positive, but the frozen H2 holdout fails in the full 64-node reference solve before adaptive-manager evaluation.

Therefore the heterogeneous admission set is not a valid 4/4 comparison set under the frozen Z43 configuration.

## Preserved positive evidence

Z43 preserves:

- explicit non-default moving-interface profile;
- unchanged legacy/default behavior;
- H1 O05/N64 physical equivalence;
- H1 100% reduced-route usage;
- zero H1 fallback/bypass;
- H1 work ratio 0.765625;
- H1 wall ratio about 0.9183.

Nothing in Z43 falsifies the positive Z42 trajectory result.

## Blocker

The immediate blocker is reference solvability of the heterogeneous holdout geometry/configuration.

H2 O14/N64/T49 cannot currently provide a valid full-reference authority.

## Direct successor

Open:

`F-PE-NLGLOB14Z43A — heterogeneous holdout reference-solvability attribution`.

Freeze initial diagnostics for:

- O14_N64_T49;
- B12_N64_T49;
- O05_N32_T25.

The successor must first determine:

- full-reference status;
- retry advice;
- nonlinear iterations;
- Jacobian builds;
- route;
- whether failure occurs on the first interval or accumulates during the trajectory.

Do not alter Z43 gates, forcing, or manager physics inside the attribution workunit.

If the full reference is solvable under an already-admitted production numerical configuration, a separately preregistered revised admission holdout may follow.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z43

BRANCH: `research/f-pe-nlglob14z43-production-admission-candidate`

RESULT POSTIMAGE BEFORE CLOSEOUT: `9dbbb5a9d11ec01fe4300bac1828763b43628358`

QUALIFICATION STATUS: `Z43_HOLDOUT_PHYSICAL_MISMATCH`

NEXT SAFE STEP: Z43A reference-solvability attribution.

## Production boundary

No canonical admission.

No production default change.

`LEGACY_NUMERICS` remains production default.
