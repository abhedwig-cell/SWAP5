# SWAP 4.3.1 + WOFOST 8.1 historical reference archive

Status: RECOVERED_VERIFIED_GIT_ARCHIVE

## Authority and purpose

This record closes the archival gap tracked by issue #149 for the exact SWAP 4.3.1 + WOFOST 8.1 donor qualified by F-WOF-PP01.

This is historical provenance only. It does not modify SWAP5 production code, physics, interfaces, numerical policy, qualification scope, or canonical admission.

## Recovered immutable artifacts

- qualified donor: `SWAP_4.3.1_WOFOST81_WORKING_FINAL_13B.zip`
- donor SHA-256: `4e0bf97bca7f3f8716e5bcf46a5dc9bb6b08436304b032d60adc3757491d94dc`
- independent oracle: `tests_Wofost81_PP.zip`
- oracle SHA-256: `99a67a0e5f6bd0881b97950a2ff3fe0f387c0a9e0553f2e36197077fbc15d145`
- exact source archive extracted from the verified donor: `SWAP_WOFOST81_SOURCE.zip`
- source archive SHA-256: `965a4908d028ff6a509ddc3d4efcf2e6bce736a7f59a6fc052c8fa2fdd66459b`
- original `wofost.f90` SHA-256: `84f0033b958132c44d650357e254cf97bc48f455ed9971c449e5582ca3258441`

The donor and oracle were recovered from the user's persistent file Library on 2026-09-29 and independently re-hashed against the immutable identities already recorded by F-WOF-PP01. Both matched exactly.

## Durable Git archive

Dedicated branch:

`archive/swap431-wofost81-qualified-donor`

Archive root:

`reference/historical/swap431-wofost81/`

The exact 545332-byte source ZIP is stored losslessly as ordered base64 chunks under `encoded/`. This is transport encoding only. `reconstruct_source.py` concatenates and decodes those chunks and refuses completion unless the reconstructed bytes match the pinned source archive SHA-256.

`SOURCE_MANIFEST.tsv` records every one of the 127 source-archive files with size, SHA-256, and Git blob SHA-1.

Three exact WOFOST 8.1 modules that already existed as byte-identical Git objects are also exposed under `browse/` for direct inspection:

- `wofost81_assimilation.f90`
- `wofost81_n_stress.f90`
- `wofost81_nitrogen.f90`

The F-WOF-PP01 qualification records are copied by object identity under `qualification/`.

## Verification

Branch-local workflow:

`.github/workflows/swap431-wofost81-archive-verify.yml`

The workflow reconstructs the source ZIP from the committed chunks and verifies:

1. source ZIP SHA-256;
2. ZIP structural integrity;
3. 127-file source count;
4. original `wofost.f90` SHA-256.

Issue #149 may be closed only after this workflow passes on the persisted archive postimage.

## Clarification of the historical source closeout

The earlier F-WOF-PP01 evidence records historical donor source closeout identifier
`839c34a657c2cee202b55d9ee85253d867a3d47a`. That identifier is not currently resolvable as a commit in the connected GitHub repository and is therefore not used as proof of byte identity.

Byte identity is instead anchored to the recovered donor artifact, the exact extracted source archive, the original `wofost.f90` hash, and the Git reconstruction gate above.

## Nested SWAP.ZIP

Inside the recovered donor, the nested `SWAP.ZIP` and `SWAP_WOFOST81_SOURCE.zip` were verified to be byte-identical. The nested `SWAP.ZIP` is therefore not treated as an independent pristine SWAP 4.3.1 baseline.
