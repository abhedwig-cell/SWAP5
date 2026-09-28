# F-HYDROFIT02 P-LSHRINK01 soft lambda shrinkage result

Authority run: `36481379126`.

All six preregistered target × sigma combinations completed on the frozen 12-case set. Hydraulic objective excludes the prior penalty.

## Summary

| target | sigma_lambda | median J/Jbest | mean | max | bound blocked | severe hydraulic | severe penalized |
|---|---:|---:|---:|---:|---:|---:|---:|
| LOO | 0.5 | 1.0182 | 1.0455 | 1.2615 | 0 | 0 | 0 |
| LOO | 1.5 | 0.9997 | 1.0189 | 1.2545 | 0 | 0 | 0 |
| LOO | 4.0 | 0.9987 | 0.9870 | 1.0111 | 0 | 2 | 2 |
| KNN5K | 0.5 | 1.0000 | 1.0123 | 1.1867 | 0 | 2 | 2 |
| KNN5K | 1.5 | 0.9997 | 0.9886 | 1.0118 | 0 | 1 | 2 |
| KNN5K | 4.0 | 0.9987 | 0.9863 | 1.0059 | 0 | 2 | 2 |

Ratios below 1 occur because Jbest is the minimum on the previously frozen discrete lambda profile grid, whereas shrinkage optimizes lambda continuously. They do not imply an inconsistency.

## Qualification

LOO sigma=1.5 satisfies the preregistered promising-policy rule:
- zero SEVERE cases;
- zero alpha/n/Ks boundary blocks;
- objective-loss tail materially better than the hard LOO fallback (max 1.255 versus 4.132; mean 1.019 versus 1.512).

LOO sigma=0.5 is also stable but has slightly larger aggregate objective loss.

LOO sigma=4.0 is not qualified despite excellent objective values: both BHR000000378543 intervals become SEVERE again. This directly demonstrates that weak regularization allows the optimizer to re-enter the known ill-conditioned lambda/alpha/Ks geometry.

None of the KNN5K-target shrinkage variants satisfies the combined identifiability rule. The conditional target itself points the problematic BHR000000378543 cases toward the degenerate region strongly enough that soft regularization does not reliably rescue them.

## Scientific interpretation

The evidence supports a simpler hierarchy than the conditional-prior route suggested initially:

1. use a leakage-resistant broad empirical lambda center;
2. treat it as a soft regularization target, not a hard fixed lambda;
3. allow the hydraulic observations to move lambda away from that center;
4. retain explicit identifiability and scale-aware boundary gates.

On this frozen evidence, a LOO-median center with sigma_lambda=1.5 is the first lambda policy that combines low hydraulic objective loss with no severe identifiability failures.

This is a qualified research result, not production admission. The result must next be tested for sensitivity to the 12-case subset/profile reference and then on a larger independent or expanded BRO corpus before any default estimator is proposed.
