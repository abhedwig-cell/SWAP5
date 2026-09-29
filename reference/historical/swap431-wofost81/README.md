# SWAP 4.3.1 + WOFOST 8.1 qualified donor source archive

Status: RECOVERED_AND_BYTE_VERIFIED

This historical reference is isolated from SWAP5 production code.

Recovered artifacts:
- donor: `SWAP_4.3.1_WOFOST81_WORKING_FINAL_13B.zip`
  SHA-256: `4e0bf97bca7f3f8716e5bcf46a5dc9bb6b08436304b032d60adc3757491d94dc`
- independent oracle: `tests_Wofost81_PP.zip`
  SHA-256: `99a67a0e5f6bd0881b97950a2ff3fe0f387c0a9e0553f2e36197077fbc15d145`
- exact source archive extracted from the verified donor: `SWAP_WOFOST81_SOURCE.zip`
  SHA-256: `965a4908d028ff6a509ddc3d4efcf2e6bce736a7f59a6fc052c8fa2fdd66459b`
- original `wofost.f90` inside that source archive:
  SHA-256: `84f0033b958132c44d650357e254cf97bc48f455ed9971c449e5582ca3258441`

The donor was recovered on 2026-09-29 from the user's persistent Library and independently re-hashed.
Both donor and oracle match the immutable identities recorded by F-WOF-PP01.

## Archive encoding in Git

The exact 545332-byte `SWAP_WOFOST81_SOURCE.zip` is stored losslessly as numbered base64 chunks under `encoded/`.
This is transport encoding only. Concatenating the chunks in lexical order and base64-decoding them reproduces the
exact source ZIP byte-for-byte. `reconstruct_source.py` performs that operation and verifies the pinned SHA-256.

`SOURCE_MANIFEST.tsv` records every file in the source archive with size, SHA-256 and Git blob SHA-1.

The donor contains both `SWAP_WOFOST81_SOURCE.zip` and a nested `SWAP.ZIP` with identical bytes; therefore the nested
`SWAP.ZIP` is not treated as an independent pristine SWAP 4.3.1 baseline.

## Scientific qualification link

The independent qualification authority remains the F-WOF-PP01 evidence under
`tests/fwof/pp01/` on `work/f-wof-pp01-independent-potential-production-equivalence`.
The archive does not modify production physics or widen the qualification claim.

## Scope

This branch is a historical provenance archive. It is not a production branch and does not alter the canonical SWAP5 tree.