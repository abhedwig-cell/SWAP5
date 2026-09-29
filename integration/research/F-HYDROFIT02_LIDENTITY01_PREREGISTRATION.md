# F-HYDROFIT02 P-LIDENTITY01 — exact hydrophysical record identity correction preregistration

## Purpose

Correct research-corpus record identity without changing any estimator or scientific policy.

## Identity

For every hydrophysical InvestigatedInterval in official XML that has both:
- WaterContentAndConductivityAtSpecificSoilWaterPotential;
- ShapeHydraulicConductivityCurve;

record:
- BRO id;
- XML InvestigatedInterval document ordinal;
- begin/end depth;
- SHA-256 of the raw hydraulic values string;
- determinationId set;
- source lambda.

The primary research identity is (BRO id, interval ordinal, hydraulic SHA-256). Depth remains metadata, not a unique key.

## Frozen-corpus correction

Reconstruct the existing 31 frozen rows against official XML in document order. For duplicate BRO/depth groups, bind each frozen source lambda to the XML hydraulic interval carrying that same source lambda. Require a unique match. For non-duplicate keys, require exactly one hydraulic interval/source-lambda match.

If any row cannot be uniquely bound, stop and preserve the ambiguity.

Write a corrected frozen identity corpus as a new file; do not overwrite the historical frozen corpus.

## Re-evaluation scope

After successful binding, rerun the already-preregistered P-LSHRINK02 hold-out experiment with:
- same deterministic 12/complement selection applied to the corrected 31-row ordering;
- same LOO-median construction;
- sigma 0.5 and 1.5 only;
- same profile grid;
- same boundary and P-LID01 condition gates.

No estimator tuning is allowed.

The previous P-LSHRINK02 result remains historically valid for the depth-key implementation but is superseded for exact-record inference if P-LIDENTITY01 succeeds.
