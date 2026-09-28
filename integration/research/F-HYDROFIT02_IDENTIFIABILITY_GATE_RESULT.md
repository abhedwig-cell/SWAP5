# F-HYDROFIT02 P-LID01 identifiability-gate result

Authority run: `36475320085`.

P-LID01 reclassified the frozen P-LPRIOR03 fits only. No fit, lambda value, objective, optimizer setting or predictor was changed.

## Frozen reclassification

| policy | well | moderate | poor | severe | qualified |
|---|---:|---:|---:|---:|---:|
| LOO_MEDIAN | 6 | 6 | 0 | 0 | 12/12 |
| HORIZON | 5 | 7 | 0 | 0 | 12/12 |
| KNN5 | 3 | 8 | 0 | 1 | 11/12 |
| KNN5K | 5 | 5 | 0 | 2 | 10/12 |

The preregistered SEVERE threshold is therefore discriminating rather than broadly rejecting ordinary fits.

For KNN5K the two SEVERE cases are both BHR000000378543 intervals:
- 0.37-0.47 m: cond = 1.321e10;
- 0.60-0.70 m: cond = 5.083e8.

The LOO_MEDIAN fits for those same intervals are MODERATE (2.34e4 and 4.73e4 respectively).

## Interpretation

The identifiability gate captures degeneracy that the scale-aware parameter-bound gate misses.

KNN5K remains attractive on objective loss but fails the combined qualification because 2/12 frozen cases are SEVERE. KNN5 also fails one case and has a much worse objective-loss tail. HORIZON remains identifiable but was already falsified on objective loss.

Thus no P-LPRIOR03 hard fixed-lambda conditional policy is qualified.

## Consequence

The evidence now favors treating a data-informed lambda estimate as a regularization target rather than a hard fixed value. A soft prior could allow the fit to move away from a conditional target when the hydraulic likelihood strongly prefers another lambda, while still preventing unconstrained lambda from entering the known alpha/Ks tradeoff.

Any such shrinkage experiment requires a new preregistration. Do not tune KNN hyperparameters first.
