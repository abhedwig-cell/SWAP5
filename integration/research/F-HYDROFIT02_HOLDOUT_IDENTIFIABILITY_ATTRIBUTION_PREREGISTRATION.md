# F-HYDROFIT02 P-LID02 — hold-out severe-case attribution preregistration

## Purpose

Attribute the P-LSHRINK02 SEVERE failure before changing lambda regularization.

## Frozen severe case

BHR000000378532, 0.65-0.75 m.

This BRO/depth identity is unique in the frozen corpus and is distinct from the separate duplicate-identity provenance issue.

## Fixed-lambda comparators

Without tuning evaluate:
1. hard fixed LOO-median target lambda = -1.4503;
2. hard fixed lambda at the two observed P-LSHRINK02 fitted values, approximately -3.1424 and -4.0392;
3. every point on the existing frozen profile grid [-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,0.5,1,2,5,10];
4. stored source lambda for diagnostic comparison only.

For every fixed-lambda fit report hydraulic objective, alpha/n/Ks boundary status and condition number of the five fitted hydraulic parameters.

Report the existing shrinkage results alongside these comparators, but introduce no new sigma values.

## Attribution

- If five-parameter fixed-lambda fits are SEVERE across broad lambda regions: INTRINSIC_NONLAMBDA_IDENTIFIABILITY.
- If fixed-lambda fits are generally non-SEVERE but joint lambda fitting is SEVERE: LAMBDA_COUPLING_IDENTIFIABILITY.
- If only a narrow lambda region is SEVERE: LAMBDA_REGION_SPECIFIC.

Do not modify thresholds, bounds, objectives or optimizer settings.

## Parallel provenance issue

Separately preserve and resolve the repeated BRO/depth records with different stored source lambda values before treating corpus record count as independent hydraulic sample count. That issue must not be used to dismiss or reinterpret the unique BHR000000378532 severe case.
