# F-HYDROFIT01 P4 — joint-family weighting preregistration

Authority: `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`

## Question

When retention and conductivity observations are fitted jointly, does mere replication of an unchanged observation family alter the estimated hydraulic parameters?

Replication contains no new independent information in this controlled experiment. A default family-combination rule that changes the optimum solely because identical rows were copied is undesirable for the intended modern estimator.

## P4-A falsification

Create one deliberately imperfect joint dataset so theta and K cannot both be fitted exactly by one parameter vector. Fit it under the current residual concatenation.

Repeat every theta observation R times while leaving K unchanged.

H0-A: the fitted parameters remain numerically unchanged.

Expected falsification mechanism: ordinary concatenated least squares weights a family in proportion to its row count, so H0-A is expected to fail.

No implementation change is allowed before this failure is observed.

## P4-B candidate correction

If P4-A fails, introduce explicit family normalization.

For family f with N_f observations and standardized point residuals r_i, use:

`r_i^* = r_i / sqrt(N_f)`

before the declared family-scale factor.

Then each family's objective contribution is its mean standardized squared residual rather than its sum.

This normalization is a default only when observations lack a fully specified probabilistic likelihood. If independent measurement sigmas and a probabilistic likelihood are explicitly intended, replication represents additional independent evidence and should not be normalized away.

Therefore the configuration must distinguish at least:

- `sum`: likelihood-like sum of squared standardized residuals;
- `family_mean`: equal family contribution independent of row count.

## Gates

W0. Demonstrate current `sum` mode is replication-sensitive on the imperfect joint case.

W1. Demonstrate `family_mean` is invariant to exact within-family replication.

W2. Demonstrate both modes remain identical for a single family up to an objective constant and produce the same optimum.

W3. Preserve exact synthetic recovery from P2/P3.

W4. Report objective contributions by family under the chosen mode.

## Nonclaim

Exact replication invariance is not universally statistically correct. It is a property desired for an equal-family engineering objective when observation counts are sampling-design artefacts. The estimator must expose the choice rather than silently impose it.
