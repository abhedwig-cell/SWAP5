# F-HYDROFIT02 P-LSAFE02 — independent expanded BRO validation preregistration

## Trigger

P-LSAFE01 is research-qualified on the frozen identity-correct 31-record corpus, but that corpus is too small and too internally related to support a production default.

P-LSAFE02 is an external replication test. It must not tune or re-estimate any estimator component from the validation records.

## Frozen estimator carried forward

The estimator is fixed exactly as qualified in P-LSAFE01:

1. lambda center for an unseen BRO object: the median source lambda of the frozen 31-record training corpus;
2. frozen center value: `-1.51057`;
3. primary estimator: soft lambda shrinkage with `sigma_lambda = 1.5`;
4. existing hydraulic objective, weighting, transformations, optimizer and parameter bounds;
5. primary gate: hydraulic condition number finite and < `1e8`, with no scale-aware alpha/n/Ks boundary block;
6. fallback: hard-fix lambda to the same frozen center `-1.51057`, then refit theta_r, theta_s, alpha, n and Ks;
7. apply the same gate to the fallback.

No validation-record lambda values, descriptors or outcomes may change the center, sigma, grid, condition threshold, bounds or fallback.

## Independent validation population

Discovery uses the official BRO BHR-P service.

Selection is fixed before acquisition:

- nationwide deterministic spatial search;
- `characteristicModelled = JA`;
- no `deliveryAccountableParty` restriction;
- object must contain surveyPurpose `bodemfysischOnderzoek`;
- target InvestigatedInterval must contain both:
  - `WaterContentAndConductivityAtSpecificSoilWaterPotential`;
  - `ShapeHydraulicConductivityCurve`;
- modelling method must be `mualemVanGenuchten`;
- hydraulic record identity is BRO id + begin depth + end depth + SHA-256 of the raw hydraulic values string.

To enforce object-level independence, exclude every BRO id represented in the frozen 31-record training corpus, not merely the 31 known hashes.

Do not exclude a newly discovered record because its source lambda, objective, observation count, conditioning or fitted outcome is unusual.

## Spatial discovery contract

Use a deterministic national grid covering the same broad Netherlands extent used by the earlier spatial discovery, but without the accountable-party filter.

Initial cells:
- latitude: 50.8 through 53.4 degrees in 0.2 degree increments;
- longitude: 3.5 through 7.1 degrees in 0.3 degree increments;
- search radius: 10 km.

If the BRO service reports that a cell exceeds its result limit, do not use a truncated cell result. Subdivide that cell deterministically into a 3×3 lattice of nine child searches at half-radius, with child centers offset by {-r/2, 0, +r/2} in north-south and east-west distance from the parent center, and continue recursively until:
- the service returns an uncapped result; or
- radius reaches 1.25 km.

Any cell still capped at 1.25 km is retained as an acquisition incompleteness and must be reported. It must not be silently sampled.

Deduplicate discovered objects by BRO id and inspect every discovered object. There is no post-discovery lexicographic inspect cap.

Transient BRO fetch failures use the existing bounded retry strategy. Persistent failures are reported and not silently replaced.

## Frozen training exclusion

Training BRO ids are taken from:
`integration/research/data/F-HYDROFIT02_FROZEN_SPATIAL_LAMBDA_CORPUS_IDENTITY.json`.

Every validation object whose BRO id occurs in that file is excluded before estimator evaluation.

This prevents hydraulic records from the same physical BRO object from contributing to both estimator development and external validation.

## Evaluation

For every eligible independent record:

- bind the exact hydraulic record by SHA-256;
- audit source lambda but never use it as a matching key;
- compute `Jbest` on the already frozen grid:
  `[-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,0.5,1,2,5,10]`;
- run the frozen P-LSAFE01 estimator;
- report primary/fallback stage, final condition class, boundary blocks and `J/Jbest`.

Report aggregate results for the complete eligible independent set.

Also report descriptive strata, without using them to tune or qualify the estimator:
- hydraulic tuple count: 1-20, 21-100, >100;
- hydraulic potential span: <1e3, 1e3..<1e4, >=1e4;
- source-lambda sign: negative, zero, positive.

## Evidence-size classification

Before considering estimator replication:

- fewer than 30 eligible records or fewer than 5 independent BRO objects:
  `INSUFFICIENT_INDEPENDENT_BRO_EVIDENCE`;
- otherwise the external replication gate is evaluated.

This threshold controls evidentiary interpretation only. Records are never discarded to meet it.

## External replication rule

If the evidence-size gate is met, P-LSAFE02 is externally research-replicated only if:

- zero final SEVERE/non-finite fits;
- zero final alpha/n/Ks boundary blocks;
- zero hydraulic-hash mismatches;
- zero silent record loss;
- every discovered eligible record has an explicit final disposition;
- final maximum `J/Jbest <= 4.13247088`, the already frozen hard-LOO guardrail used in P-LSAFE01.

Fallback frequency and aggregate median/mean objective loss are reported but are not tuning criteria.

Any failure is retained as a negative external replication result. Do not introduce another fallback, change the center, alter sigma or relax the gate after seeing the validation data.

## Interpretation limits

A positive result would support external research replication of the gated estimator on a larger and object-independent BRO sample.

It would still not by itself authorize production admission. Production admission would require a separate workunit defining operational failure semantics, software ownership, reproducibility requirements and an explicit production acceptance gate.

A negative or evidence-insufficient result is a valid closure outcome for P-LSAFE02.


## Pre-execution correction

Before any P-LSAFE02 acquisition was executed, the originally written four-child half-radius subdivision was found not to geometrically cover the complete parent search circle. It was therefore replaced by the deterministic 3×3 nine-child half-radius lattice above. This correction was made before validation outcomes or independent-corpus membership were observed and changes only spatial completeness handling, not eligibility or estimator criteria.
