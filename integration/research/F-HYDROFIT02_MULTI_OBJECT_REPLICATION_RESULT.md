# F-HYDROFIT02 — independent BRO replication result

Run: `36413728958`

Three independently discovered BRO bodemfysisch objects were processed through the same acquisition/export/refit path:

- BHR000000346010;
- BHR000000346024;
- BHR000000378560.

Six hydrophysical intervals were available in total.

## Objective replication

For every interval the unconstrained six-parameter refit reduced the declared family-mean objective relative to the stored WENR/BRO parameters.

J6/Jstored ratios:

- BHR000000346010, 0.10-0.20 m: 0.465;
- BHR000000346010, 0.40-0.50 m: 0.686;
- BHR000000346024, 0.05-0.15 m: 0.771;
- BHR000000378560, 0.04-0.14 m: 0.684;
- BHR000000378560, 0.35-0.45 m: 0.184;
- BHR000000378560, 0.50-0.60 m: 0.866.

Thus objective improvement replicates across these objects, but magnitude is highly variable.

## Critical negative result: unconstrained l policy fails

Two intervals from BHR000000346010 drive the fitted conductivity exponent to the imposed lower bound:

- 0.10-0.20 m: l approximately -9.9999;
- 0.40-0.50 m: l approximately -10.0000.

The first also drives alpha close to its upper bound and Ks to approximately 33452 cm/d.

These are boundary solutions and must not be presented as physically credible parameter estimates merely because the scalar objective is lower.

This falsifies a naive policy of making l freely estimable over a broad generic box for every soil.

## Interpretation

The earlier real-object evidence that l=0.5 is not a neutral universal default remains valid.

However, the replication shows that the alternative cannot be “always fit l freely”. A modern RETC successor requires an explicit l policy, likely involving one or more of:

- physically/empirically informed bounds;
- profile-based identifiability gates;
- regularization/prior information;
- fixing l when data do not identify it;
- reporting boundary solutions as non-qualified rather than silently accepting them.

The same principle applies to other parameters when their optimum reaches generic bounds.

## Status

Real-data acquisition and objective-improvement replication: positive.

Universal free-six-parameter estimation policy: falsified.

No production parameter-generation recommendation is qualified yet.
