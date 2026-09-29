# F-HYDROFIT02 P-LSHRINK02 hold-out replication result

Authority run: `36515672735`.

The replication step used the repository-frozen 31-interval corpus and therefore did not depend on successful live BRO spatial discovery in this run.

## Preregistered hold-out result

The complement of the deterministic 12-case subset contains 19 frozen corpus records.

| sigma_lambda | median J/Jbest | mean | max | boundary blocks | SEVERE hydraulic | SEVERE penalized |
|---|---:|---:|---:|---:|---:|---:|
| 0.5 | 1.063 | 1.062 | 1.275 | 0 | 1 | 1 |
| 1.5 | 1.000 | 0.989 | 1.199 | 0 | 1 | 1 |

Both candidates fail the preregistered replication rule because each has one SEVERE case.

The common failure is BHR000000378532, 0.65-0.75 m:
- sigma=0.5: hydraulic condition number about 2.20e17, penalized about 2.77e11;
- sigma=1.5: hydraulic condition number about 1.73e17, penalized about 8.09e11.

Neither fit contacts the formal alpha/n/Ks boundary and both have acceptable hydraulic objective ratios. This is therefore another hidden identifiability failure rather than an objective-loss failure.

P-LSHRINK01 is **not independently replicated** under its preregistered zero-SEVERE criterion.

## Frozen-corpus identity caveat

The frozen corpus contains repeated BRO/depth identities with different stored source lambda values:
- BHR000000378543 1.40-1.50 m occurs twice, lambda -1.9999 and 0.0001;
- BHR000000378544 0.35-0.45 m occurs twice, lambda 0.0001 and 0.

The current downstream hydraulic lookup keys observations by BRO id plus begin/end depth. Thus these are distinct corpus records for lambda characterization but map to the same fetched hydraulic interval in the replication fitter.

This does not explain or remove the BHR000000378532 0.65-0.75 m SEVERE failure, which has a unique frozen BRO/depth identity. It does mean the 19-record exercise must not be described as 19 independent hydraulic intervals.

## Consequence

Do not tune sigma after this failure.

Before further lambda-policy work:
1. resolve the provenance/identity semantics of duplicate same-depth source-lambda records;
2. characterize the newly exposed BHR000000378532 0.65-0.75 m identifiability failure;
3. then decide whether the appropriate estimator is stronger regularization, a qualification-triggered hard fallback, or a model/measurement identifiability classification.

The negative replication result is retained.
