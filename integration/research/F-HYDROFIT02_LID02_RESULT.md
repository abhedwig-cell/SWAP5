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

## Identity-corrected corpus confirmation

Authority run `36518236021` rebuilt the spatial corpus with explicit raw-hydraulic SHA-256 identity: old=31 records, new=31 records, hashes present 31/31, unique hashes 31/31, duplicate hashes 0. The same three duplicate BRO/depth keys retain multiplicity two. The corpus therefore contains 31 genuine unique hydrophysical measurement records; the correction is identity/binding, not deduplication.

## Frozen severe-case lambda profile

Authority run `36517890213` shows that BHR000000378532 0.65-0.75 m has localized rather than broad ill-conditioning. On the preregistered lambda grid, only lambda=-5 (J=21.04, cond=6.88e11) and lambda=-3 (J=28.46, cond=8.65e11) are SEVERE. All other grid points from -25 through 10 are MODERATE, and no alpha/n/Ks boundary is contacted.

The hydraulic objective itself prefers the same region in which conditioning collapses. This is therefore a genuine local identifiability valley, not general data failure and not a duplicate-record artefact.

Before repeating policy qualification, enrich the frozen corpus with hyd_sha256/ordinal and convert every downstream observation lookup to exact hydraulic-record identity. Re-establish the deterministic 12/19 mappings and rerun affected record-level analyses; do not carry their earlier qualification status forward unchanged.
