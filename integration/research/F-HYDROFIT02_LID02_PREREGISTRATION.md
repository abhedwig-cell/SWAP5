# F-HYDROFIT02 P-LID02 — new severe-case and duplicate-identity characterization preregistration

## Trigger

P-LSHRINK02 exposed a unique SEVERE fit at BHR000000378532, 0.65-0.75 m under both preregistered LOO shrinkage widths. The frozen corpus also contains repeated BRO/depth identities with different stored source lambda values.

## Purpose

Characterize both phenomena without changing the estimator.

## A. Severe case

For BHR000000378532 0.65-0.75 m, report from the official object:
- raw theta/K observation count and ranges;
- source hydraulic parameters and source lambda;
- horizon code and direct interval metadata already allowed by prior audits;
- frozen lambda-profile J across the existing grid;
- fitted parameter vectors and condition numbers at the profile grid points;
- singular-value spectrum for the shrinkage solutions sigma=0.5 and 1.5.

Do not add grid points, change bounds, weights, objective or optimizer.

Classify whether the severe conditioning is localized in lambda or persists across a broad range. This classification must be descriptive, not threshold-tuned.

## B. Duplicate identity provenance

For every frozen (BRO id, begin depth, end depth) key occurring more than once:
- enumerate the matching InvestigatedInterval elements in official XML in document order;
- report each element's ShapeHydraulicConductivityCurve values, source lambda, hydraulic observation tuple count, horizonCode, and any determination identifiers available inside that interval;
- hash/canonicalize the raw hydraulic values string to determine whether repeated records share observations or are genuinely distinct measurements.

Do not deduplicate yet.

## Decision

If duplicates are distinct XML InvestigatedInterval records, corpus identity must be extended beyond BRO/depth before further record-level validation.
If they arise from extractor duplication of one XML element, fix the extractor and rebuild the frozen corpus under a separate preregistered correction.

For the severe case, do not alter lambda policy in this workunit.
