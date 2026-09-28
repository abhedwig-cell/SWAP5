# F-HYDROFIT02 P-LCORP02 spatial corpus result

Run: `36417418681`.

## Discovery

The preregistered 182-cell Netherlands coverage grid completed with:

- 0 query errors;
- 0 service-cap rejections;
- 70 unique modelled BHR-P candidates for accountable party 27378529.

All 70 candidates were fetched successfully.

Nine were explicitly `bodemfysischOnderzoek`. These contained 31 qualifying hydrophysical intervals with joint theta/K observations and a stored conductivity-shape curve.

All 31 use modelling procedure `WENRHydrofysicav1`.

## Source lambda distribution

Across the 31 source fits:

- minimum: -20;
- q05: -9.909;
- q25: -3.219;
- median: -1.511;
- q75: -0.356;
- q95: +0.151;
- maximum: +0.732;
- negative: 23;
- exactly zero: 1;
- positive: 7;
- outside [-4,0]: 13 of 31.

## Interpretation

The source-lambda distribution is broad, crosses zero, and contains a substantial negative tail.

This independently confirms that neither lambda=0.5 nor a universal [-4,0] range represents the historical/source WENRHydrofysicav1 corpus.

The extreme source value -20 also means that a broad negative lambda is not automatically evidence of optimizer failure. Boundary status must be interpreted relative to the declared fitting policy and profile identifiability, not by magnitude alone.

Conversely, the prior broad-free refits that hit their imposed -10 boundary remain non-qualified because the data did not demonstrate an interior optimum within that exploration range.

## Consequence

A modern policy should separate:

1. admissible/exploration domain;
2. identifiability qualification;
3. fallback/regularization.

The empirical source distribution can inform exploration and priors, but must not itself be treated as a hard physical range.

## Next evidence step

Profile lambda on a deterministic subset of these 31 intervals using a wider exploration domain that contains the observed source range, while keeping other-parameter boundary gates active. Compare:

- stored source lambda;
- free-profile interior optimum where present;
- objective gain;
- whether alpha/Ks/n/theta remain qualified.

This is required before specifying a fallback prior or adaptive estimator.
