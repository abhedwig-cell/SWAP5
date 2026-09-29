# F-HYDROFIT02 P-LID02 provenance characterization result

Authority run: `36516759371`.

## Duplicate identities

The three repeated BRO/depth keys in the frozen corpus are genuine distinct hydrophysical records in the official BRO XML, not extractor duplication.

Examples:
- BHR000000378543 0.60-0.70 m: two hydraulic intervals, 233 versus 142 tuples, different SHA-256 hashes, different determination ids (including WDH01/WGD01 versus WDH02/WGD02), lambda -10.0 versus 0.0001.
- BHR000000378543 1.40-1.50 m: 158 versus 240 tuples, different hashes and determination-id combinations, lambda -1.9999 versus 0.0001.
- BHR000000378544 0.35-0.45 m: 321 versus 281 tuples, different hashes and determination ids, lambda 0.0001 versus 0.0.

Therefore (BRO id, begin depth, end depth) is not a valid unique record identity for this corpus.

Downstream research scripts that map a corpus row back to observations using only that triple can silently assign the wrong same-depth hydraulic record. Record-level validation using that lookup must be corrected and rerun.

## New severe case source

BHR000000378532 0.65-0.75 m contains one actual hydraulic interval:
- document ordinal 8;
- horizon Cu;
- 17 hydraulic tuples;
- source lambda -3.66885;
- shape 0.03315,1.15437,0.13373,-3.66885,1.00;
- determination ids WDH01, WGD01, WRS17.

A second same-depth InvestigatedInterval exists but has no hydraulic tuple array and no conductivity-shape curve. It is not a duplicate hydraulic measurement.

Thus the P-LSHRINK02 severe failure for this depth is not explained by competing same-depth hydraulic records.

## Required correction

Extend frozen corpus identity with a stable XML hydrophysical interval identity, minimally document-order ordinal plus observation hash and relevant determination ids. Rebuild/rebind downstream profile, fallback, conditional-prior and shrinkage evaluation to exact records before treating record-level replication metrics as final.

Do not change the scientific estimator during this identity correction.
