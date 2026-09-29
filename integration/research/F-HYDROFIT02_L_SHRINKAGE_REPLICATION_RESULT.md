# F-HYDROFIT02 P-LSHRINK02 independent replication result

Authority run: `36515672735`, head `94ab4b39f94a78916caedfd4a61e18bb20cffd0a`.

The preceding run `36515217337` failed before replication because live BRO acquisition timed out while rebuilding the spatial corpus. No shrinkage inference is retained from that failed run. The valid authority run reached and completed the preregistered independent-complement replication.

## Hold-out result

The replication set is the 19 frozen-corpus intervals outside the original deterministic 12-case subset.

| target | sigma_lambda | median J/Jbest | mean | max | boundary blocks | severe hydraulic | severe penalized |
|---|---:|---:|---:|---:|---:|---:|---:|
| LOO median | 0.5 | 1.063 | 1.062 | 1.275 | 0 | 1 | 1 |
| LOO median | 1.5 | 1.000 | 0.989 | 1.199 | 0 | 1 | 1 |

Both candidates satisfy the preregistered objective-tail and boundary criteria but fail the zero-SEVERE replication criterion.

The same hold-out interval causes failure for both widths:

`BHR000000378532 0.65-0.75 m`

- sigma=0.5: lambda target -1.4503, fitted lambda -3.1424, J/Jbest 1.2508, hydraulic cond 2.20e17, penalized cond 2.77e11;
- sigma=1.5: fitted lambda -4.0392, J/Jbest 0.9541, hydraulic cond 1.73e17, penalized cond 8.09e11.

No alpha/n/Ks formal boundary block is present.

## Decision

P-LSHRINK01 is **NOT_REPLICATED** under its preregistered identifiability criterion.

The failure is not objective accuracy. It is structural/local identifiability: a very good hydraulic objective can coexist with an essentially singular parameter geometry.

Do not rescue the result by choosing a new sigma after seeing this case. Before further lambda-policy work, characterize why BHR000000378532 0.65-0.75 m is singular and determine whether the issue is lambda-specific, another parameter tradeoff, measurement design, or Jacobian scaling/parameterization.

The negative replication result is retained as authority.
