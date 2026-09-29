# F-PE-ELASTIC10D2 — source-bound descriptor extension result

Date: 2026-09-29

Status: DESCRIPTOR_COVERAGE_FROZEN_NO_MODEL_SELECTED

Frozen input:
- Phase-D workflow run `36540905498`;
- artifact `11021065518`;
- artifact digest `sha256:0c0a6c44367966e291cf15177989d2abe8f25f6192259f0e6029bd4aabd3a903`;
- exact 36-object calibration set;
- exact 18-object holdout set, unopened by D2.

D2 workflow run:
`36543951520`

Job:
`109325733769`

Evidence artifact:
`11021327530`

Conclusion:
PASS.

## Offline authority gates

The D2 runner downloaded only the frozen Phase-D artifact.

It verified:
- calibration count = 36;
- calibration-list SHA-256 =
  `7b42fee42b2b05e2f788e13317b90d574b1039cf240e57fb3f2c35fe994dd45e`;
- holdout count = 18;
- holdout-list SHA-256 =
  `bfbb1fdefaef57ea3e6a0d2e077fa8efee5b17f101a92da04f0f75603b94e5df`;
- valid unload targets = 77;
- valid reload targets = 92;
- no holdout XML present in the downloaded artifact;
- `F_PE_ELASTIC10D2_HOLDOUT_FETCHED=0`.

No D2 result depends on a fresh BRO object response.

## Target-bound coverage

Coverage below means that the source field is bound to the exact settlement
determination or investigated interval that owns the valid mechanical target.

| Field | unload | reload | distinct objects |
| --- | ---: | ---: | ---: |
| dryVolumetricMassDensity | 0 / 77 | 0 / 92 | 0 |
| volumetricMassDensity | 77 / 77 | 92 / 92 | 35 |
| volumetricMassDensitySolids | 37 / 77 | 38 / 92 | 17 |
| waterContent | 77 / 77 | 92 / 92 | 35 |
| sampleMoistness | 77 / 77 | 92 / 92 | 35 |
| geotechnicalSoilName | 11 / 77 | 12 / 92 | 6 |
| organicMatterContent | 2 / 77 | 2 / 92 | 1 |
| organicMatterContentClass | 5 / 77 | 6 / 92 | 4 |
| sandMedianClass | 0 / 77 | 0 / 92 | 0 |
| specialMaterial | 0 / 77 | 0 / 92 | 0 |
| saturated | 0 / 77 | 0 / 92 | 0 |
| underLoad | 0 / 77 | 0 / 92 | 0 |
| verticalStrain | 0 / 77 | 0 / 92 | 0 |

The 35-object count for density/water fields corresponds to the 35 calibration
objects that yielded at least one valid mechanical target.

## Global presence is not target binding

Several fields exist elsewhere in the BHR-GT objects but cannot be attached to
the settlement target under the preregistered scope rule.

Most importantly, `dryVolumetricMassDensity` occurs four times in two
calibration objects but zero times on a valid settlement target.

The four occurrences are:
- one value in a saturated-permeability determination;
- three values in made specimens for shear-loading determinations.

For `BHR000000450418`, the dry-density observations occur at investigated
intervals 5.60-5.70, 5.70-5.80 and 5.80-5.90 m, while the valid settlement
targets occur at 1.86-1.88, 3.31-3.33 and 7.31-7.33 m.

Therefore using those values as ELAS predictors would require a new,
independently preregistered cross-analysis or depth-linkage rule. D2 does not
make that inference.

The same distinction explains why broad borehole-log descriptors such as
`sandMedianClass` are common object-wide but have zero exact target-bound
coverage under D2.

## Preregistered eligibility gates

### Dry density

Requirement:
- at least 50% of valid unload targets;
- at least 15 calibration objects.

Observed:
- 0 / 77 unload targets;
- 0 target-bound objects.

Decision:
`dryVolumetricMassDensity` is NOT eligible for Phase-E target-level models.

### Dry density + solids density

Requirement:
- jointly available for at least 25% of unload targets;
- at least 10 calibration objects.

Observed:
- 0 / 77 unload targets;
- 0 target-bound objects.

Decision:
a derived porosity route is NOT authorized from D2.

### Categorical descriptors

No categorical descriptor passes the preregistered gate.

`sampleMoistness` has complete target coverage but only one observed category,
`veldvochtig`, so it has no discriminating value in this calibration corpus.

`geotechnicalSoilName` and `organicMatterContentClass` have too few
target-bound objects. Other categorical fields have zero target-bound coverage.

## Variables that remain directly usable as source-bound evidence

D2 does not select a statistical model.

The source fields with broad direct target binding are:
- `volumetricMassDensity`;
- `waterContent`;
- `volumetricMassDensitySolids` on a bounded subset.

Target metadata already frozen in Phase D also retain:
- target depth;
- branch stress change;
- determination method;
- unload versus reload identity.

Any transformation, interaction, stress normalization or predictor model must
be preregistered separately.

## Workflow isolation correction

The legacy ELASTIC10 retrieval workflow originally triggered on
`research/elastic/**`.

The D2 parser commit therefore also started an incidental broad rerun
(`36543951681`) even though D2 itself is defined as offline-only.

That broad rerun is not D2 evidence and does not enter any D2 result.

The trigger has been narrowed so future D2 parser changes no longer start the
BRO retrieval/corpus workflow.

## Decision

Classification:

`SOURCE_BOUND_DESCRIPTOR_AUDIT_CLOSED_MODEL_SELECTION_STILL_SEPARATE`.

F-PE-ELASTIC10D2 establishes that the most obvious dry-density shortcut is not
supported on the current target-bound corpus, while wet volumetric mass density
and water content are directly available for essentially the full valid
mechanical target set.

No PTF, default ELAS, stress-independent material constant or BOFEK mapping is
selected here.
