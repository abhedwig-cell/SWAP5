# F-HYDROFIT02 scale-aware requalification result

Run: `36425153864`.

The same 12 profile minima were reclassified without changing observations, fits, parameter domains or lambda grid.

For positive scale parameters alpha and Ks, proximity to bounds was assessed in log space. n remained linearly assessed.

## Result

- QUALIFIED_SCALE_AWARE: 10/12;
- ALPHA_BOUND: 2/12;
- KS_BOUND: 0;
- N_BOUND: 0.

Thus the earlier 0/12 qualification result was an artefact of a scale-inappropriate linear Ks gate.

## Two genuine failures

Both remaining failures belong to BHR000000378543:

- 0.37-0.47 m: lambda-profile minimum near -15, alpha=10 upper bound, Ks~6427 cm/d, conditional Jacobian condition number ~1.28e10;
- 0.60-0.70 m: minimum near -10, alpha~10 upper bound, Ks~7906 cm/d, condition number ~1.11e10.

These are genuinely non-qualified under the current model/domain and show severe parameter tradeoff.

## Qualified profiles

Ten intervals now have an interior lambda-profile minimum without alpha/n/Ks bound contact under scale-aware gates.

Qualified grid minima include lambda values around -1, -3 and -5. This supports adaptive free-lambda estimation for a substantial majority of this deterministic real-data subset.

Condition numbers still vary widely and must be reported; passing the boundary gate is not equivalent to high parameter precision.

## Methodological consequence

Optimization and qualification metrics must respect parameter geometry:

- positive scale parameters: log-domain transformations/distances;
- ordered parameters: structural transforms;
- additive shape parameters: appropriate linear or separately justified domains.

A modern RETC successor should encode these geometries directly rather than treating every parameter as a linear box coordinate.

## Next decision point

The evidence now supports designing an adaptive estimator:

1. perform a lambda profile or equivalent identifiability diagnostic;
2. accept free lambda when an interior, sufficiently shaped minimum exists and other parameters pass scale-aware gates;
3. otherwise use a fallback and flag lambda as non-identifiable/model-confounded.

The fallback value/prior remains to be derived and should use the larger source corpus rather than a universal 0.5.
