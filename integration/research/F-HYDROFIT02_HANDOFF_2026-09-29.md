# F-HYDROFIT02 handoff — 2026-09-29 identity correction and identifiability

## Authority at handoff

Research branch: `research/f-hydrofit02-bro-acquisition@af26245a1d3a0ec0f7404bf18b3d571300685ded`.

Canonical observed immediately before handoff: `integration/f-ci-canonical@56a072f6484b8c8dd92e0c72bb2e71ab1d55ed94`.

Always refetch both before writes. Parallel work is active.

## Scientific state

The original question was whether Mualem lambda can be estimated robustly rather than fixed at 0.5.

Evidence accumulated:
- free lambda can materially improve hydraulic fit but can create alpha/Ks tradeoff and poor identifiability;
- a universal scalar fallback is safer but has a large objective-loss tail;
- low-capacity hard conditional predictors did not qualify;
- a KNN5K hard target improved objective but created SEVERE condition cases;
- an explicit identifiability gate was preregistered: WELL <1e4, MODERATE 1e4..<1e6, POOR 1e6..<1e8, SEVERE >=1e8/nonfinite;
- soft shrinkage around a leakage-resistant leave-one-BRO-object-out median looked strong on the original deterministic 12 cases;
- independent complement replication on 19 frozen corpus records failed the preregistered zero-SEVERE rule for both sigma=0.5 and 1.5 because BHR000000378532 0.65-0.75 m is SEVERE.

Do not tune sigma from that negative result.

## P-LID02 severe case

BHR000000378532, 0.65-0.75 m:
- one genuine hydrophysical InvestigatedInterval;
- document ordinal 8;
- horizon Cu;
- 17 hydraulic tuples;
- hydraulic SHA-256 `19f7fe0532875070ff6049f98959a5ea57f2cc3b95724387fd74dbf68bc6df12`;
- determination IDs WDH01, WGD01, WRS17;
- source lambda -3.66885.

Frozen lambda-profile run `36517890213` completed successfully.

Profile:
- lambda -25: J 297.26, cond 2.89e5 MODERATE
- -20: 253.38, 1.97e5 MODERATE
- -15: 189.12, 1.16e5 MODERATE
- -10: 98.95, 4.82e4 MODERATE
- -7.5: 51.41, 2.41e4 MODERATE
- -5: 21.04, 6.88e11 SEVERE
- -3: 28.46, 8.65e11 SEVERE
- -2: 52.44, 1.49e4 MODERATE
- -1: 84.58, 1.88e4 MODERATE
- 0: 122.50, 2.28e4 MODERATE
- 0.5: 141.95, 2.50e4 MODERATE
- 1: 160.99, 2.75e4 MODERATE
- 2: 196.48, 3.30e4 MODERATE
- 5: 275.44, 5.53e4 MODERATE
- 10: 342.17, 1.13e5 MODERATE

Interpretation: the objective minimum region itself overlaps a narrow severe-conditioning zone around lambda roughly -5 to -3. This is not generic poor conditioning across all lambda. Do not add grid points without a new preregistration.

## Hydrophysical record identity defect

P-LID02 proved `(BRO id, beginDepth, endDepth)` is not a unique hydrophysical record identity.

Three duplicate keys in the frozen corpus correspond to genuine distinct hydrophysical XML records with different raw hydraulic hashes and source lambdas:
- BHR000000378543 0.60-0.70 m: lambda -10 and 0.0001; 233 vs 142 hydraulic tuples;
- BHR000000378543 1.40-1.50 m: lambda -1.9999 and 0.0001; 158 vs 240 tuples;
- BHR000000378544 0.35-0.45 m: lambda 0.0001 and 0; 321 vs 281 tuples.

These are not extractor duplicates.

P-LIDENTITY01 preregistration requires identity:
`BRO id + begin depth + end depth + SHA-256(raw hydraulic values string)`.
Document ordinal is provenance only.

The spatial corpus extractor has been modified to emit `hyd_sha256` and `interval_ordinal`.

## Current live work

Run `36518236021` on head `af26245a1d3a0ec0f7404bf18b3d571300685ded` is still in progress at handoff. It rebuilds the live spatial corpus with hashes and compares it against:
`integration/research/data/F-HYDROFIT02_FROZEN_SPATIAL_LAMBDA_CORPUS.json`.

Do not proceed to estimator conclusions until this run is complete and its `BRO_IDENTITY_*` output has been inspected.

## Required next sequence

1. Follow run 36518236021 to completion. A queued/in-progress run is not closure.
2. Inspect `BRO_IDENTITY_COMPARE`, `BRO_IDENTITY_KEY`, `BRO_IDENTITY_HASH`, `BRO_IDENTITY_DUP_HASHES`.
3. Establish whether the identity-corrected live corpus still has 31 records and whether all hydrophysical hashes are unique.
4. Record P-LIDENTITY01 result.
5. Update all downstream parsers/lookups that currently key by BRO/depth so they bind by hydraulic hash.
6. Re-freeze an identity-corrected corpus only after an explicit old/new comparison. Preserve the old frozen corpus for audit.
7. Re-establish deterministic profile/hold-out membership on true hydrophysical records.
8. Re-run affected lambda profile, fallback, conditional-prior and shrinkage analyses. Do not carry old case-level results forward when mapping was ambiguous.
9. Keep the BHR000000378532 severe-profile result as valid only if its unique hydraulic hash remains the same after identity correction.
10. Do not tune lambda grids, sigma values, KNN hyperparameters or qualification thresholds without new preregistration.

## Key files

- `integration/research/F-HYDROFIT02_HYDRO_RECORD_IDENTITY_PREREGISTRATION.md`
- `integration/research/F-HYDROFIT02_LID02_PREREGISTRATION.md`
- `integration/research/F-HYDROFIT02_L_SHRINKAGE_REPLICATION_RESULT.md`
- `research/hydrofit/bro_spatial_lambda_corpus.py`
- `research/hydrofit/compare_hydro_record_identity.py`
- `research/hydrofit/characterize_lid02_provenance.py`
- `integration/research/data/F-HYDROFIT02_FROZEN_SPATIAL_LAMBDA_CORPUS.json`

## Governance

Repository is authority. Before every write refetch canonical and research branch. Incorporate parallel commits. Never force-push. Preserve preregistrations and negative results. Do not interpret CI green as scientific qualification.
