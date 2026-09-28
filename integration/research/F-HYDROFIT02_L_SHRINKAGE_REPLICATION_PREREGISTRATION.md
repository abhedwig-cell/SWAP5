# F-HYDROFIT02 P-LSHRINK02 — independent soft-shrinkage replication preregistration

## Purpose

Replicate P-LSHRINK01 outside the frozen 12 deterministic profile cases before any production-oriented conclusion.

## Frozen policies

Replicate exactly:
- leave-one-BRO-object-out global-median lambda target;
- sigma_lambda = 0.5;
- sigma_lambda = 1.5.

No KNN target and no new sigma values are allowed.

## Replication set

Use every usable interval in the frozen 31-interval corpus that is not a member of the deterministic 12-case P-LPROF01/P-LSHRINK01 subset.

Membership is defined by the existing deterministic linspace index selection. Do not choose replication cases from outcomes.

For each target interval construct its median lambda target using only intervals from other BRO objects.

## Reference

For every replication interval use the same frozen lambda grid:
`[-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,0.5,1,2,5,10]`.

Jbest is the minimum hydraulic objective on this grid. It is a comparison reference, not a continuous optimum.

## Outputs

For each candidate width report:
- fitted lambda and displacement from target;
- hydraulic J/Jbest, excluding prior penalty;
- alpha/n/Ks boundary status;
- hydraulic and penalized condition number;
- P-LID01 condition class.

Aggregate median, mean and maximum J/Jbest, condition-class counts, and formal boundary-block count.

## Replication decision

A candidate replicates only if:
- zero SEVERE cases;
- zero formal alpha/n/Ks boundary blocks;
- maximum J/Jbest <= 1.5.

If both replicate, do not select between 0.5 and 1.5 from small aggregate differences on this corpus. Proceed to broader-corpus or external-data validation.

If sigma=1.5 fails but 0.5 replicates, retain the stronger shrinkage candidate. If both fail, P-LSHRINK01 is not replicated.
