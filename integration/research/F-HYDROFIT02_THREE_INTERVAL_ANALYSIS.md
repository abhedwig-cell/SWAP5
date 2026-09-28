# F-HYDROFIT02 — real-object three-interval analysis

BRO object: `BHR000000378560`  
Run: `36413209715`

## Common setup

All three hydrophysical intervals were evaluated with the same explicit family-mean objective. The stored WENR/BRO Mualem-Van Genuchten parameters were evaluated under that objective and compared with a six-parameter refit in theta_r, theta_s, alpha, n, Ks and l.

This is an objective comparison, not a reconstruction of the historical WENR fitting protocol.

## Interval 0.04-0.14 m

Stored J = 51.2605; six-parameter J = 35.0650, a reduction of 31.6%.

Family contributions:

- theta: 6.8177 -> 4.7910;
- K: 44.4429 -> 30.2740.

Modern fit:
theta_r=0.12618, theta_s=0.70538, alpha=0.09339, n=1.18034, Ks=32.53 cm/d, l=-3.06237.

Profile analysis shows finite minima for Ks and l. theta_r has a broader shallow minimum: theta_r=0 remains only about 1.64 objective units above the optimum. Therefore the nonzero theta_r estimate should not be interpreted as strongly identified.

Largest remaining standardized residuals occur near h=-3 cm for both theta and K, with additional theta mismatch near -100/-177 cm.

## Interval 0.35-0.45 m

Stored J = 82.6339; six-parameter J = 15.2140, a reduction of 81.6%.

Family contributions:

- theta: 13.0772 -> 3.4734;
- K: 69.5568 -> 11.7405.

Modern fit:
theta_r approximately 0, theta_s=0.33380, alpha=0.05588, n=1.32581, Ks=13.8267 cm/d, l=-2.30924.

theta_r is boundary-supported at zero and worsens monotonically over the tested positive profile. Ks and l have clear local profile minima.

This interval provides the strongest evidence in the object that the stored WENR parameters are not optimal under the modern joint theta/K objective.

## Interval 0.50-0.60 m

Stored J = 73.8692; six-parameter J = 63.9820, a reduction of 13.4%.

Family contributions:

- theta: 21.8340 -> 13.6941;
- K: 52.0353 -> 50.2878.

Modern fit:
theta_r=0.01668, theta_s=0.32979, alpha=0.02683, n=1.93994, Ks=5.3155 cm/d, l=-1.27531.

The modest total improvement is dominated by theta. K remains poorly represented under both fits, with a very large residual around h=-100 cm. This is evidence of model/data mismatch that parameter optimization alone does not resolve.

## Cross-interval conclusion

The first real object falsifies a simple claim that a modern refit will uniformly improve every soil layer by the same mechanism.

Observed reductions in the declared objective are approximately:

- 31.6%;
- 81.6%;
- 13.4%.

In the first two intervals most absolute objective improvement comes from K. In the third interval K remains problematic and most improvement comes from theta.

The conductivity exponent l is materially informed by these joint theta/K datasets and should not be fixed to the conventional 0.5 by default. All three fitted l values are negative and close in sign/order to the stored WENR values.

theta_r behaves differently by layer: shallow/weakly identified in interval 1, boundary-zero in interval 2, and low with a finite profile minimum in interval 3. A single blanket theta_r treatment is therefore not justified by this object.

## Consequence for a modern RETC successor

A credible modern implementation should:

1. fit theta and K jointly with explicit family weighting;
2. expose l as a fitted or policy-controlled parameter;
3. report profile/identifiability information rather than only point estimates;
4. retain residual-by-head diagnostics;
5. flag structured model mismatch instead of forcing all disagreement into parameter values;
6. preserve and compare the historical/source fit under the same declared objective.

The next evidence step is replication across additional independent BRO bodemfysisch objects, followed by the separate Staringreeks provenance mapping.
