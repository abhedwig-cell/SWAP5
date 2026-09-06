# SWAP-011 patch provenance gate

Status: **PATCH_PAYLOAD_PENDING**

The technical correction and its qualification are complete in the audit line, but the B1 reference requires the exact final patch bytes, not a reconstruction from prose or memory.

## Expected final upstream artifacts

The completed audit/handoff line identified these artifacts:

```text
SWAP_4.3.1_E7_SW011_upstream_package.zip
SWAP_4.3.1_SW011_overdracht_Marius.docx
SWAP_4.3.1_SW011_overdracht_Marius_bundle.zip
patch/SWAP-011_fix.patch
```

These names are provenance clues only. A file is not accepted merely because it has one of these names.

## Expected production file set

The final patch is expected to change exactly:

```text
SWAP/MOD_MvG_functions.f90
SWAP/WC_K_models_04_11.f90
SWAP/MOD_RIA.f90
```

No change to `SWAP/headcalc.f90` is expected in the final E7 line.

## B0 preimage identities

The exact B0 preimage hashes are already pinned in `../../b0/file-manifest.sha256`. For the three expected files:

```text
MOD_MvG_functions.f90
  a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390

WC_K_models_04_11.f90
  1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd

MOD_RIA.f90
  a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3
```

`MOD_RIA.f90` contains non-UTF-8 B0 bytes, so patch recovery/application must be byte-safe.

## Admission procedure after recovery

Before `SWAP-011` may be added to `b1-manifest.yml`:

1. recover the final E7 patch/package from an original audit artifact;
2. compute and record artifact SHA-256;
3. inspect the patch and confirm the changed-file set;
4. verify all patch preimages against the exact B0 member hashes;
5. apply the patch to a byte-exact B0 working tree using a binary-safe path;
6. verify that no unlisted source file changed;
7. rerun or reproduce the named qualification gate, or attach immutable evidence sufficient to reproduce it;
8. store the exact `fix.patch` under this directory;
9. update the legacy difference ledger;
10. only then add `SWAP-011` to the ordered B1 manifest and freeze the next B1 snapshot.

## Anti-reconstruction rule

Do not recreate `fix.patch` from descriptions of the algorithm. The final implementation contains optimization and fallback details that matter for both behavior and performance. B1 must contain the exact qualified correction, not a plausible equivalent rewrite.
