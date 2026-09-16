# F-PE19 — SWAP-011 admission state boundary

Date: 2026-09-16

Status: `ADMISSION_READY_EXCEPT_CANONICAL_B0_FULL_REPLAY`

Protocol state: `RECONCILE = PASS -> QUALIFY = PASS -> ADMIT = BLOCKED -> CLOSE = NOT YET`

## Completed gates

- exact historical E7 package recovered and byte-verified;
- historical E7 patch identity preserved separately at SHA-256 `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`;
- overlap with already admitted SWAP-009, SWAP-010 and SWAP-012 fully reconciled;
- exact current-B1.10 ordered admission transform derived without source redesign;
- ordered transform independently qualified against current B1.10;
- prospective B1.11 source identity frozen;
- exact ordered `fix.patch` persisted in the SWAP-011 candidate dossier;
- byte-safe ordered applicator stored;
- fail-closed `tools/vq/b1_11_reconstruct.py` stored.

## Exact persisted ordered patch

`reference/swap-4.3.1/patches/SWAP-011/fix.patch`

- SHA-256: `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`
- byte count: `37169`
- changed files: exactly `MOD_MvG_functions.f90`, `WC_K_models_04_11.f90`, `MOD_RIA.f90`.

The one-shot GitHub Actions materialization run `35087718847` completed successfully. Its materialization step reported the exact SHA-256 and 37,169-byte size, and bot commit `ef4692a5113962f8de584d658b8ba0e5f2cab58d` persisted the exact file. A subsequent run also completed successfully with the payload already present.

## Byte-safe target application

The ordered transform is pinned to B1.10 preimages:

- `MOD_MvG_functions.f90`: `4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1`;
- `WC_K_models_04_11.f90`: `7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e`;
- `MOD_RIA.f90`: `a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3`.

It reproduces the qualified postimages:

- `MOD_MvG_functions.f90`: `6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104`;
- `WC_K_models_04_11.f90`: `d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126`;
- `MOD_RIA.f90`: `673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a`.

A local byte-safe application was independently rerun using exact B0 hydraulic target bytes from the recovered complete testbank plus the already admitted ordered transformations needed to obtain the B1.10 target preimages. All three target postimage identities passed.

## Frozen prospective B1.11 identity

- source members: `63`;
- source bytes: `1,886,519`;
- source manifest SHA-256: `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`;
- `headcalc.f90`: unchanged at `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`.

## Remaining blocker

Formal B1 admission requires an end-to-end reconstruction from the **full canonical B0 distribution**, not merely the three affected target files. The required controlling archive identity is:

- `SWAP_4.3.1.zip` SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- nested Fortran source archive `SWAP.ZIP` SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

The accessible uploaded/testbank material provides the exact affected B0 hydraulic target files, but not the complete canonical 63-file distribution archive required by the published reconstruction contract. Exact File Library searches by filename and both controlling SHA-256 values returned documentation and derived evidence, not the archive object itself.

A useful recovery clue survives in the retained A23y qualification evidence: that work explicitly records reconstructing from a local object named `SWAP_4.3.1(6).zip` with the same controlling distribution SHA-256 `2b48353d...`. This proves that an exact-name duplicate existed in an earlier runtime/workspace, but the ZIP bytes themselves are not recoverable from the currently searchable File Library. `SWAP_4.3.1(6).zip` is therefore an additional exact external filename to search in local downloads/backups.

Therefore the gate remains fail-closed:

`CANONICAL_B0_FULL_ARCHIVE_REPLAY = BLOCKED_MISSING_ARCHIVE_BYTES`

`B1_MANIFEST_MUTATED = NO`

`ADMITTED_B1 = NO`

`ISSUE_12_CLOSE_ALLOWED = NO`

## Next permitted action

When an original canonical B0 distribution/archive with the controlling SHA-256 becomes available, including a local duplicate named `SWAP_4.3.1(6).zip`:

1. verify its raw SHA-256 before use;
2. run `tools/vq/b1_11_reconstruct.py` against the controlling distribution;
3. require exact reproduction of the frozen B1.11 manifest `24ce2768...`;
4. only on PASS promote the difference ledger entry, add SWAP-011 to `b1-manifest.yml`, publish immutable B1.11 and close issue #12.

No production-source redesign, tolerance change, Energy Balance, RossFast, WFT300 or other capability expansion belongs in this remaining gate.
