# F-HYDROFIT02 P-LIDENTITY01 identity-correction result and rerun scope

Identity comparison run: `36518236021`.
Severe-profile characterization run: `36517890213`.

## Corpus identity result

The live identity-corrected rebuild contains 31 records, equal to the frozen pre-identity corpus.

The same three BRO/depth keys retain multiplicity two:
- BHR000000378543 0.60-0.70 m;
- BHR000000378543 1.40-1.50 m;
- BHR000000378544 0.35-0.45 m.

All 31 rebuilt records have a hydraulic SHA-256 and all 31 hashes are unique. There are zero duplicate hydraulic hashes.

Therefore the spatial extractor had retained genuine distinct hydrophysical records correctly. The defect is downstream identity collapse wherever fetched observations were indexed only by BRO id + begin/end depth.

## Consequence for evidence

Any analysis that maps a corpus row back to fetched hydraulic observations using only BRO/depth must be re-executed after hash-aware lookup.

The corpus-level lambda distribution and object-level availability results remain structurally informative, but fit-level results involving the three duplicate depth keys are not authoritative until rerun.

## Severe-case characterization

BHR000000378532 0.65-0.75 m has one genuine hydrophysical record (17 hydraulic tuples, source lambda -3.66885, hash 19f7fe...).

Frozen profile:
- lambda -7.5: J=51.41, MODERATE;
- lambda -5: J=21.04, SEVERE, cond 6.88e11;
- lambda -3: J=28.46, SEVERE, cond 8.65e11;
- lambda -2: J=52.44, MODERATE.

The severe conditioning is localized around the low-objective lambda region. This is a genuine objective-versus-identifiability ridge, not duplicate-record contamination.

## Rerun rule

Update downstream parsers to retain hydraulic hash and bind corpus records by (BRO id, hydraulic hash). Depth and source lambda are audit fields only.

Then rerun, in order:
1. deterministic profile subset membership and profile qualification;
2. fallback comparison;
3. conditional-prior comparison and P-LID01;
4. shrinkage and hold-out replication.

Do not tune policies during this reconciliation. Preserve old results as superseded evidence rather than deleting them.
