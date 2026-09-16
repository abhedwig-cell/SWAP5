# F-PE13 → SWAP-011 B1 admission handoff

Date: 2026-09-16

Source workunit: `F-PE13 — SWAP-011 E7 provenance recovery`

Recovery verdict: `A — EXACT_E7_RECOVERED_AND_VERIFIED`

## Exact recovered authority

External E7 package SHA-256:

`97e31ea1216e4796ab3df5cb062f1d46c2c396f5dcbe90b4f783144b8a9162ac`

Exact E7 patch SHA-256:

`9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`

Verified E7 postimages:

- `MOD_MvG_functions.f90`: `9b319e3388912dc31efb46b2c46cd6836b3859560b141d226d971ff5b6ca7cea`
- `WC_K_models_04_11.f90`: `95b12a7f62da81ccde14f1bd11d7998a582d26349249da24df3422558588603f`
- `MOD_RIA.f90`: `5758d34ddf9e8ff45a6aaec07d3586ab9ac7cc8e9e65d31677cb9adb7f370227`

Pinned B0 preimages were independently reproduced from the recovered complete testbank and match canonical B0 exactly.

## Preserved evidence

The E7 package contains:

- exact unified patch;
- cleaned three-file production postimage;
- E7 finalization report and technical change note;
- E6 150-run regression runner;
- D2 reference source;
- compiler/build helper/order;
- expected E6 GNU Fortran 14.2 result JSON;
- E5/E6/E7 compact evidence tables;
- internally consistent SHA-256 manifest.

Historical execution evidence remains immutable. A new replay was not performed in F-PE13.

## Admission boundary

Do not admit directly from historical B0 by replaying the full patch onto the current ordered B1 baseline.

The recovered E7 `MOD_MvG_functions.f90` also includes a pressure-head inverse correction. Current reference governance later admitted that behavior separately as SWAP-012. Therefore the next workunit must reconcile the exact historical E7 payload against the present ordered B1 state and prove which bytes are already represented by admitted SWAP-012 before constructing any SWAP-011 admission candidate.

The historical E7 artifact itself must remain immutable. Any current-baseline admission delta derived from it must be documented as an admission transform, not relabeled as the historical E7 patch.

## Current SWAP5 authority observed at handoff

- canonical: `integration/f-ci-canonical`
- head: `bfbb466678249811afc6a0800fd32a367818660f`

## Next permitted workunit

A separate bounded SWAP-011 B1 admission/reconciliation decision surface may now start.

Required opening steps:

1. live-verify current canonical and current ordered B1 authority;
2. live-verify the already admitted SWAP-012 patch/postimage;
3. classify overlap between SWAP-012 and recovered E7 `MOD_MvG_functions.f90`;
4. prove the residual SWAP-011 admission delta derives unambiguously from the exact E7 payload;
5. preserve the historical E7 patch and hashes unchanged;
6. only after independent admission qualification update the ordered B1 manifest/reference snapshot.

No Energy Balance, RossFast, new derivative design, tolerance change or performance redevelopment belongs in that workunit.
