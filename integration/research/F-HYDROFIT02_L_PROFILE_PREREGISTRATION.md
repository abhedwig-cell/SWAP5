# F-HYDROFIT02 P-LPROF01 — real-corpus lambda profile preregistration

Authority observed: `integration/f-ci-canonical@94e265d18200b40d942184809e1e45694aea850f`.

## Frozen source population

Use the 31 qualifying intervals discovered by P-LCORP02.

Select a deterministic subset of at most 12 intervals by sorting on `bro_id, begin_depth, end_depth` and taking evenly spaced indices over the full ordered list, including first and last. Selection is completed before any profile values are evaluated.

## Lambda profile

For each selected interval evaluate fixed lambda values:

`[-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,0.5,1,2,5,10]`.

At every lambda, refit theta_r, theta_s, alpha, n and Ks using the same family-mean theta/K objective.

Use an ordering-preserving theta parameterization so theta_s > theta_r throughout optimization.

## Qualification

A lambda profile is INTERIOR_QUALIFIED only if:

- the lowest objective occurs at neither end of the lambda grid;
- at the minimum, alpha, n and Ks are not within 0.1% of generic bounds;
- theta ordering is valid by construction;
- the profile has objective values on both sides of the minimum at least 1% higher than the minimum.

Otherwise classify as:

- EDGE_MINIMUM;
- OTHER_PARAMETER_BOUNDARY;
- FLAT_OR_WEAK.

Also report source lambda and nearest-grid source objective.

## Purpose

Estimate how often real joint theta/K data identify lambda sufficiently to justify free estimation. Do not infer a production prior or universal bound from this subset.
