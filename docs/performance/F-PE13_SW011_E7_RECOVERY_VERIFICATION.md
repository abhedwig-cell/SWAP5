# F-PE13 — SWAP-011 exact E7 recovery verification

Date: 2026-09-16

Status: `EXACT_E7_RECOVERED_AND_VERIFIED`

This checkpoint reopens the previously closed F-PE13 provenance-recovery line only because a genuinely new external artifact source became available after closeout.

No SWAP 4.3.1 production source and no SWAP5 production source is modified here.

## Authorities

Original F-PE13 closeout branch/head:

- `work/f-pe13-swap011-e7-provenance-recovery`
- `dc74d0bc21c3f6abb792702b0ec767837e0efbea`

Current SWAP5 canonical observed during recovery verification:

- `integration/f-ci-canonical`
- `bfbb466678249811afc6a0800fd32a367818660f`

The canonical advance is unrelated to SWAP-011 provenance and does not invalidate the immutable SWAP 4.3.1 B0 or audit evidence.

## Newly recovered external artifact

Uploaded object:

`SWAP_4.3.1_E7_SW011_upstream_package (1).zip`

The `(1)` is only the local duplicate-name suffix. The archive root is exactly:

`SWAP_4.3.1_E7_SW011_upstream_package/`

Uploaded ZIP SHA-256:

`97e31ea1216e4796ab3df5cb062f1d46c2c396f5dcbe90b4f783144b8a9162ac`

Archive entries: 33.

The internal package contains the expected historical objects, including:

- `patch/SWAP-011_fix.patch`
- `source/MOD_MvG_functions.f90`
- `source/WC_K_models_04_11.f90`
- `source/MOD_RIA.f90`
- `E7_FINALIZATION_REPORT.md`
- `docs/SWAP-011_technical_change_note.md`
- `tests/run_swap011_regression.py`
- `tests/reference/D2_MOD_MvG_functions.f90`
- compiler/build-order helpers
- E5/E6/E7 evidence tables
- `MANIFEST.sha256`

## Package integrity

All 25 files listed in the internal `MANIFEST.sha256` were recomputed from the recovered archive and all 25 SHA-256 values match.

Important recovered identities:

- `patch/SWAP-011_fix.patch`: `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`
- `source/MOD_MvG_functions.f90`: `9b319e3388912dc31efb46b2c46cd6836b3859560b141d226d971ff5b6ca7cea`
- `source/WC_K_models_04_11.f90`: `95b12a7f62da81ccde14f1bd11d7998a582d26349249da24df3422558588603f`
- `source/MOD_RIA.f90`: `5758d34ddf9e8ff45a6aaec07d3586ab9ac7cc8e9e65d31677cb9adb7f370227`

## B0 preimage verification

A separately recovered historical `SWAP_4.3.1_complete_testbank.zip` contains the three original hydraulic source files. Their bytes independently reproduce the already pinned B0 identities:

- `MOD_MvG_functions.f90`: `a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390`
- `WC_K_models_04_11.f90`: `1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd`
- `MOD_RIA.f90`: `a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3`

This is an independent byte-level match to `reference/swap-4.3.1/b0/file-manifest.sha256`.

## Changed-file gate

The recovered `SWAP-011_fix.patch` contains exactly three `diff --git` targets:

1. `SWAP/MOD_MvG_functions.f90`
2. `SWAP/MOD_RIA.f90`
3. `SWAP/WC_K_models_04_11.f90`

There is no `headcalc.f90` hunk and no fourth source target. Therefore applying this patch to B0 leaves `SWAP/headcalc.f90` byte-identical by construction.

## Byte-safe patch application verification

The patch was applied only in a temporary local verification tree containing the exact B0 preimage bytes, using the application mode documented by E7:

`git apply --ignore-space-change --ignore-whitespace`

Result: PASS for all three files, including legacy non-UTF-8 `MOD_RIA.f90`.

The official B0 files use CRLF while the E7 review patch and packaged cleaned source use LF. After CRLF-to-LF normalization, each locally applied result is byte-identical to the corresponding recovered E7 `source/` postimage:

- `MOD_MvG_functions.f90`: exact normalized SHA-256 `9b319e3388912dc31efb46b2c46cd6836b3859560b141d226d971ff5b6ca7cea`
- `WC_K_models_04_11.f90`: exact normalized SHA-256 `95b12a7f62da81ccde14f1bd11d7998a582d26349249da24df3422558588603f`
- `MOD_RIA.f90`: exact normalized SHA-256 `5758d34ddf9e8ff45a6aaec07d3586ab9ac7cc8e9e65d31677cb9adb7f370227`

This reproduces the line-ending behavior explicitly documented in the recovered E7 finalization report.

## Architecture gate

Recovered production postimages contain the expected final E7 architecture:

- lazy/model-specific constitutive state;
- `RIAKDerivativeFromState` retained;
- `RIAStencilCrossesBoundary` retained;
- model-specific derivative support in `WC_K_models_04_11.f90`;
- finite-difference fallback retained for required branch/stencil cases;
- exploratory `hconduc_dh` wrapper absent;
- exploratory `RIAKDerivativeAnalytic` absent.

This matches the already staged E5/E6/E7 qualification description.

## Qualification evidence relationship

The recovered package identifies itself as the E7 release-engineering form of the E5/E6-qualified candidate and records:

- E7 finalization date: 2026-09-02;
- SWAP-011 status: `FIX_TESTED`;
- patch status: `READY_PATCH_UPSTREAM`;
- GNU Fortran 14.2.0;
- flags: `-O2 -cpp -Dlinux -finit-local-zero -fallow-argument-mismatch -ffree-line-length-none -fno-range-check`;
- TTUTIL 4.27 rebuilt with the same toolchain;
- E6 matrix: 150/150 normal runs;
- 60/60 identical Newton histories;
- K0 endpoints: 30/30 byte-identical;
- K1 endpoints: 16/30 byte-identical, remaining state differences at the recorded round-off scale;
- max H-profile RMSE: `1.4338e-11 cm`;
- max nodal H difference: `9.9817e-11 cm`;
- affected K1 median candidate/D2 runtime ratio: `0.7911`;
- E7 focused patch sanity for models 3, 7, 10 and 12: normal completion, exact E5 Newton histograms and byte-identical E5 endpoints.

The recovered package also contains the reusable E6 regression script, D2 reference source, build helper, compile order and expected-result JSON.

`EXACT_PAYLOAD_RECOVERED = YES`

`QUALIFICATION_REPLAY_REPRODUCED = NO`

No replay was forced in this provenance workunit. The exact historical package and immutable recorded qualification are kept distinct from any future replay exercise.

## Important later-admission observation

The recovered historical E7 package also contains pressure-head inverse changes inside `MOD_MvG_functions.f90`, as explicitly described by its technical change note. Current SWAP5 reference governance later treated the pressure-head inverse as the separately admitted SWAP-012 correction.

This does not invalidate E7 provenance, but it means a future B1 admission workunit must reconcile overlap with the already admitted SWAP-012 state rather than blindly applying the historical E7 patch to the current ordered B1 baseline. That is a separate admission decision surface and is not performed here.

## Protocol closeout

`RECONCILE = COMPLETE`

`RECOVER = COMPLETE`

`VERIFY = COMPLETE`

`CLOSE = EXACT_E7_RECOVERED_AND_VERIFIED`

Final provenance verdict:

`A — EXACT_E7_RECOVERED_AND_VERIFIED`

No production source was modified. No B1 manifest was changed. No SWAP-011 admission was performed.

Next permitted action: start a separate bounded SWAP-011 B1 admission/reconciliation workunit using this exact recovered E7 payload, explicitly accounting for the already admitted SWAP-012 overlap before any ordered-baseline mutation.
