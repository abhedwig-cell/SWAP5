# F-PE-ELASTIC06C — Dutch BRO mechanical-descriptor coverage result

Date: 2026-09-29

Status: CLEAN_DESCRIPTOR_SUBSET_IDENTIFIED_NO_DETERMINISTIC_ELAS_RULE

## Authority

Source artifact:
GitHub Actions run `36443606773`,
artifact `f-hydrofit02-bro-probe`,
head `24d5414dc343e9a4bdf92bd9a46b58727724dfb5`.

Cross-component provenance file:
`lambda-prior-cross-provenance.json`.

The artifact was produced by the already corrected HYDROFIT depth-overlap rules. No descriptor imputation is introduced here.

## Joint clean coverage

Frozen hydrophysical interval population: 31 intervals.

Exact ASSIGNED coverage:

- horizonCode: 31/31;
- dryBulkDensity: 21/31;
- organicMatterContent: 21/31;
- clayContent: 19/31;
- dryBulkDensity + organicMatterContent jointly ASSIGNED: 21/31;
- dryBulkDensity + organicMatterContent + clayContent jointly ASSIGNED: 9/31.

Therefore there is a useful Dutch mechanical-descriptor subset, but the complete physically preferred triplet is available for only 9 intervals.

## Range of the clean dry-bulk-density + organic-matter subset

For the 21 intervals with unambiguous dry bulk density and organic matter:

- dry bulk density spans `0.176 .. 1.802` in the BRO source units;
- median dry bulk density is `1.416`;
- organic matter spans `0.3 .. 72.5` percent;
- median organic matter is `3.2` percent.

The clean subset therefore spans very low-density organic material through dense mineral subsoil.

Examples at the low-density/high-organic end:
- `BHR000000378531 0.55-0.65 m`: dryBulkDensity 0.230, organicMatterContent 72.5, horizon Cu;
- `BHR000000378532 0.40-0.50 m`: 0.214, 70.3, Cu;
- `BHR000000378532 0.65-0.75 m`: 0.176, 70.3, Cu.

Examples at the dense mineral end:
- `BHR000000378534 0.68-0.74 m`: 1.802, 0.7, Ce;
- `BHR000000378560 0.35-0.45 m`: 1.778, 1.5, Bheb;
- `BHR000000378560 0.50-0.60 m`: 1.698, 0.4, Cg.

This observed spread is large enough that a single universal matrix-compressibility prior would be physically implausible.

## Clean triplet subset

Nine intervals have unambiguous dry bulk density, organic matter and clay content together.

Those intervals span:
- dry bulk density from about `0.753` to `1.778`;
- organic matter from about `0.3` to `15.3` percent;
- clay content from `2` to `70` percent.

This is too small and compositionally uneven for a calibrated multivariate ELAS pedotransfer function.

It is sufficient for:
- broad prior/regime checks;
- falsifying obviously implausible universal assumptions;
- testing whether a proposed literature-based mechanical prior produces reasonable ELAS magnitudes across contrasting Dutch soils.

## Important limitation

These BRO descriptors are physical covariates, not measured elastic-storage targets.

No interval in this evidence set currently provides a source-bound:
- recompression/swelling index;
- constrained modulus;
- matrix compressibility;
- preconsolidation stress;
- measured specific storage.

Therefore even perfect descriptor coverage would not identify a unique ELAS relation without external mechanical target information.

## Consequence

The Dutch evidence now supports two distinct research levels.

### Level 1 — physically informed prior classes

Supported.

A future preregistered study may define broad prior envelopes using combinations of:
- bulk density;
- organic matter;
- clay content where available;
- horizon/depth;
- an explicit reference effective-stress convention.

The objective must be a prior range, not a point-calibrated ELAS prediction.

### Level 2 — deterministic Dutch ELAS pedotransfer

Not currently identified.

This requires mechanical target data or a defensible external constitutive relation with independently justified coefficients.

## Recommended next physical experiment

Use only the 21 clean dry-bulk-density + organic-matter intervals, with the 9 clean clay-complete intervals as a more restricted subset.

Preregister:
1. mineral/organic regime definitions from independent soil-science conventions;
2. literature-derived constrained-modulus or recompression-index envelopes;
3. one or more declared reference effective stresses;
4. conversion to ELAS/Ss through the physical specific-storage equation;
5. sensitivity bands, not fitted point values.

Do not use solver speed, Staringreeks runtime response or MvG parameters as the target during this physical-prior construction.

## Decision

Classification:

`DUTCH_PHYSICAL_PRIOR_FEASIBLE_DETERMINISTIC_PTF_NOT_IDENTIFIED`.

This result strengthens the case for soil-driven ELAS ownership while preserving the distinction between data-supported prior ranges and an unjustified fitted production rule.
