# F-HYDROFIT02 P-BOUND01 attribution result

Run: `36424368169`.

## Attribution

Existing linear normalized-bound logic classified:

- KS_BOUND: 8/12;
- MULTIPLE_BOUNDS (ALPHA + KS): 4/12.

No case was blocked by n.

However, the Ks classification is invalid as a scientific gate.

The generic Ks domain is `[1e-12, 1e8]` cm/d, spanning 20 orders of magnitude. Linear normalization to this interval marks essentially every ordinary Ks value as near the lower bound. For example fitted Ks values of 6.85, 17.9, 62.7 and 246 cm/d were all flagged as within 0.1% of the lower bound. Source WENR Ks values were likewise almost universally flagged.

Therefore the previous P-LPROF01 result of 0/12 qualified lambda profiles was confounded by a scale-inappropriate Ks boundary metric.

## Genuine signals retained

Four cases also hit or approached the alpha generic boundary under the existing linear alpha metric. Two are especially severe:

- BHR000000378543 0.37-0.47 m: alpha=10, Ks~6427, condition number ~1.3e10;
- BHR000000378543 0.60-0.70 m: alpha~10, Ks~7906, condition number ~1.1e10.

These remain non-qualified independently of the Ks metric correction.

Two BHR000000378544 intervals were also tagged alpha-near-bound because alpha is small relative to the broad [1e-8,10] box; this too requires scale-aware review rather than automatic rejection.

## Decision

For strictly positive scale parameters alpha and Ks, bound proximity must be assessed in log space. n may remain on an additive/linear scale. Theta ordering remains structural.

Requalify the already-computed profile minima using log-distance to declared positive bounds. Do not refit and do not change parameter domains in that requalification.
