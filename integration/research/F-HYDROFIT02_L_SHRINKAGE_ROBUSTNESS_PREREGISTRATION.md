# F-HYDROFIT02 P-LSHRINK02 — robustness preregistration

## Purpose

Test whether the P-LSHRINK01 positive result for LOO-median soft shrinkage with sigma_lambda=1.5 is robust to the frozen 12-case selection and discrete profile reference.

Do not tune sigma or introduce new target policies.

## Frozen candidate

Candidate: leave-one-BRO-object-out median lambda target, sigma_lambda=1.5.

Comparators:
- hard LOO median;
- soft LOO sigma=0.5;
- soft LOO sigma=4.0.

KNN policies are not developed further in this workunit.

## Tests

R1: run the candidate and comparators on every hydrophysical interval in the current 31-interval corpus for which the existing fitting machinery can execute.

R2: for each interval compute a continuous or sufficiently refined free-lambda reference objective independently of the shrinkage fit, so the denominator is not limited to the coarse previous grid. The reference is diagnostic only and does not need to be qualified as a usable estimator.

R3: report by BRO object as well as pooled:
- hydraulic objective ratio;
- fitted lambda displacement from target;
- scale-aware boundary blocks;
- hydraulic and penalized condition classes.

R4: explicitly retain the two BHR000000378543 intervals as sentinel cases.

## Decision rule

The sigma=1.5 result remains a qualified research candidate only if:
- zero SEVERE cases across the expanded executable corpus;
- zero alpha/n/Ks boundary blocks;
- no single BRO object shows systematic objective degradation that is hidden by the pooled median;
- its objective-loss tail remains materially better than hard LOO median.

Any failure is preserved. Do not retune sigma after R1-R4.
