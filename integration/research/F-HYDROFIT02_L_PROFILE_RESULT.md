# F-HYDROFIT02 P-LPROF01 result

Run: `36418306923`.

## Result

Twelve intervals were selected deterministically from the 31-interval spatial corpus and profiled over lambda:

`[-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,0.5,1,2,5,10]`.

All 12 profiles had an interior objective minimum on this lambda grid.

However, all 12 failed the preregistered qualification gate because at the profile minimum at least one of alpha, n or Ks was within 0.1% of its generic optimization bound.

Classification summary:

- INTERIOR_QUALIFIED: 0;
- EDGE_MINIMUM: 0;
- FLAT_OR_WEAK: 0;
- OTHER_PARAMETER_BOUNDARY: 12.

## Profile-shape evidence

The lambda objective itself is often strongly informative. Examples include minima near:

- -3 for BHR000000378531;
- -5 for BHR000000378532;
- -1 for several intervals;
- -15 for one BHR000000378543 interval.

Other profiles are very shallow over a wide negative-lambda range, for example BHR000000378543 0.60-0.70 m and BHR000000378544 0.65-0.75 m.

Thus lambda profile shape varies materially by sample.

## Critical interpretation

The zero qualified count does not mean lambda is never identifiable.

It means the current qualification scheme cannot isolate lambda identifiability because the five-parameter conditional refits repeatedly encounter generic bounds in alpha, n or Ks.

Therefore lambda policy cannot be solved independently from the admissible-domain policy for the other Mualem-Van Genuchten parameters.

The next work should identify which other parameter(s) hit bounds and whether those bounds represent:

- unrealistic generic boxes;
- genuine non-identifiability;
- model-form mismatch;
- or missing physical constraints/prior information.

No relaxation of bounds is justified merely to obtain qualified lambda profiles.
