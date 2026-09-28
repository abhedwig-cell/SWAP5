# F-HYDROFIT02 P-LPOL01 result

Run: `36414815428`  
Official conductivity-shape schema validated in run `36414962434`.

## Schema correction/confirmation

The official BRO `ShapeHydraulicConductivityCurve` record contains, in order:

1. shapefactorAlpha;
2. shapefactorN;
3. shapefactorM;
4. shapefactorLambda;
5. weightfactor.

Therefore the fourth stored conductivity-shape value is indeed lambda. Positive stored values such as 6.31143 and 6.74567 in BHR000000346010 are source data, not a parser error.

## Policy comparison

Three policies were compared on the frozen six-interval set:

- STORED_L: retain source lambda and refit other parameters;
- BOUNDED_L: fit lambda in [-4,0];
- BROAD_L: fit lambda in [-10,10].

BOUNDED_L retained more than 99% of the BROAD_L objective improvement on all six intervals.

However, it failed the preregistered qualification condition because the two pathological BHR000000346010 intervals simply moved to the new lambda boundary -4. One also retained alpha at its upper bound and extreme Ks.

Thus the bounded policy did not remove the pathology; it truncated it.

STORED_L avoided the lambda-boundary pathology and retained approximately 70-99% of broad-fit objective improvement, depending on interval, but cannot serve as a general policy for new samples with no prior fitted lambda.

## Decision

Universal fixed lambda=0.5: rejected by real-data evidence.

Universal broad free lambda: rejected by boundary failures.

Universal hard lambda range [-4,0]: rejected by both source evidence (positive valid stored lambda exists) and boundary behavior.

## Qualified design direction

Lambda must be treated as an adaptively identifiable parameter.

A free-lambda solution may be qualified only when:

- the profile objective has an interior minimum over the declared exploration range;
- lambda is not at/near its bound;
- freeing lambda does not drive alpha, Ks, n or theta parameters to generic bounds;
- the objective improvement over the fallback policy is material.

Otherwise the fit must report lambda as non-identifiable under the available data and invoke an explicit fallback policy rather than presenting a boundary optimum as an estimate.

The fallback policy itself remains open. Candidate evidence sources include source/stored lambda where available and an empirical distribution learned from a larger corpus of qualified BRO hydrophysical fits.

## Next workunit

Use BRO delivery accountable party `27378529`, discovered in the official characteristics responses, to expand the real-data corpus. Estimate the empirical distribution of source lambda and identify which samples provide interior free-lambda profiles. Do not derive production bounds until this larger corpus has been characterized.
