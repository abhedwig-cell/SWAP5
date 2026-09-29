# F-HYDROFIT02 P-LIDENTITY01 mapping reconciliation before reruns

Authority identity comparison: run `36518236021`, artifact `11012173186`.

This reconciliation is recorded before identity-corrected estimator reruns.

## Corpus membership

The pre-identity and identity-corrected corpora both contain 31 records. All 31 identity-corrected records have a non-empty `hyd_sha256`; all 31 hashes are unique. The three repeated BRO/depth keys remain genuine two-record groups, so no record is deduplicated.

The deterministic 12 indices under the preregistered stable BRO/depth ordering are:

`[0, 3, 5, 8, 11, 14, 16, 19, 22, 25, 27, 30]`.

The other 19 records form the independent complement, unchanged as a membership set.

## Duplicate-key mapping

| BRO/depth | corpus source lambda | hydraulic hash | old depth-only binding | subset |
|---|---:|---|---|---|
| BHR000000378543 0.60-0.70 | -10 | `5f653eae...` | incorrectly rebound to `f095f112...` | complement |
| BHR000000378543 0.60-0.70 | 0.0001 | `f095f112...` | correct by dictionary overwrite | deterministic 12 |
| BHR000000378543 1.40-1.50 | -1.9999 | `aab632a2...` | incorrectly rebound to `3423b336...` | complement |
| BHR000000378543 1.40-1.50 | 0.0001 | `3423b336...` | correct by dictionary overwrite | complement |
| BHR000000378544 0.35-0.45 | 0.0001 | `52c85ee0...` | incorrectly rebound to `c8b36173...` | complement |
| BHR000000378544 0.35-0.45 | 0 | `c8b36173...` | correct by dictionary overwrite | complement |

The old lookup built a dictionary keyed only by BRO/depth. For duplicate depths the later XML hydrophysical interval replaced the earlier one. Consequently exactly three corpus rows were fitted against the wrong hydraulic observations. All three are in the 19-record complement.

## Impact on prior evidence

The original deterministic 12 observation bindings were correct, including BHR000000378543 0.60-0.70 with source lambda 0.0001. Therefore the frozen profile reference and fixed/median fallback fits for those 12 are expected to reproduce exactly apart from numerical noise.

P-LSHRINK02 must be rerun because three complement records were wrong-bound. Its previous negative result remains authority as a historical preregistered result, but its aggregate 19-case metrics are not identity-correct.

P-LPRIOR03 must be rerun because KNN5/KNN5K descriptors for the three earlier duplicate records used the later record's observation count and hydraulic spans. LOO_MEDIAN is descriptor-independent and HORIZON uses the same horizon group for each duplicate pair, so those policies are expected to remain unchanged; this expectation is not substituted for rerun evidence.

P-LSHRINK01 must be rerun because its KNN5K prior centers depend on those descriptor rows. The LOO-centered variants are expected to reproduce because deterministic case binding and leave-one-object lambda medians are unchanged.

P-LID01 must be regenerated from the identity-correct P-LPRIOR03 output.

The severe BHR000000378532 0.65-0.75 record is unique and retains hash `19f7fe0532875070ff6049f98959a5ea57f2cc3b95724387fd74dbf68bc6df12`; its P-LID02 severe-profile result remains directly valid.

## Rerun contract

Use `integration/research/data/F-HYDROFIT02_FROZEN_SPATIAL_LAMBDA_CORPUS_IDENTITY.json`.

All observation lookup must match on hydraulic SHA-256 and audit BRO/depth plus source lambda after the hash match. Preserve the existing deterministic index construction, lambda grid, sigma values, predictor definitions, optimizer settings and identifiability thresholds.
