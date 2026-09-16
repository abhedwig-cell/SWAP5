# F-PE19 — SWAP-011 current-B1 admission reconciliation

Date: 2026-09-16

Status: `RECONCILE_COMPLETE / QUALIFICATION_REQUIRED`

Protocol: `RECONCILE -> QUALIFY -> ADMIT -> CLOSE`

This workunit is the separate admission decision surface handed off by F-PE13 after recovery of the exact historical E7 SWAP-011 package. It does not redesign SWAP-011 and does not modify SWAP5 production source.

## Authorities

Current SWAP5 canonical at workunit start:

- branch: `integration/f-ci-canonical`
- commit: `bfbb466678249811afc6a0800fd32a367818660f`

Current corrected SWAP 4.3.1 reference:

- snapshot: `B1.10`
- manifest: `reference/swap-4.3.1/b1-manifest.yml`
- source manifest SHA-256: `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`

Exact recovered E7 provenance authority:

- F-PE13 handoff: `work/f-pe13-swap011-e7-provenance-recovery@ffbf99d96ae835d3509fa92043bcb4766d67059d`
- external E7 package SHA-256: `97e31ea1216e4796ab3df5cb062f1d46c2c396f5dcbe90b4f783144b8a9162ac`
- exact historical E7 patch SHA-256: `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`

Historical E7 postimages:

- `MOD_MvG_functions.f90`: `9b319e3388912dc31efb46b2c46cd6836b3859560b141d226d971ff5b6ca7cea` (LF package form)
- `WC_K_models_04_11.f90`: `95b12a7f62da81ccde14f1bd11d7998a582d26349249da24df3422558588603f` (LF package form)
- `MOD_RIA.f90`: `5758d34ddf9e8ff45a6aaec07d3586ab9ac7cc8e9e65d31677cb9adb7f370227` (LF package form)

## Current ordered B1.10 preimages for SWAP-011 targets

Only previously admitted corrections touching the three E7 target files are relevant to the ordered preimage:

- `MOD_MvG_functions.f90`: SWAP-012 already admitted at B1.9; current hash `4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1`.
- `WC_K_models_04_11.f90`: SWAP-009 then SWAP-010 already admitted; current hash `7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e`.
- `MOD_RIA.f90`: no admitted B1 correction touches this file; current hash remains B0 `a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3`.

Later B1.8-B1.10 corrections do not touch these target files except SWAP-012 described above.

## Exact overlap reconciliation

### MOD_MvG_functions.f90 / SWAP-012

The recovered E7 patch contains the same pressure-head inverse correction later isolated and admitted as SWAP-012. Direct comparison of the E7 `prhead` implementation with the byte-safe SWAP-012 corrected target finds the same code; the only textual difference after line-ending normalization is whitespace on the blank line immediately before the corrected branch.

A three-way merge using exact B0 as common ancestor, current B1.10 as one side and exact E7 semantics as the other produces only that whitespace conflict in `MOD_MvG_functions.f90`. The admission candidate preserves the already admitted SWAP-012 bytes and takes E7 only outside that already represented correction.

Therefore SWAP-012 is not re-admitted or overwritten.

### WC_K_models_04_11.f90 / SWAP-009 and SWAP-010

Historical E7 does not contain the later separately admitted SWAP-009 and SWAP-010 corrections.

The admitted transforms remain uniquely applicable to the exact E7 postimage:

- SWAP-009 target sequence occurs exactly four times in the E7 postimage and can be replaced by the already admitted signed-head form.
- SWAP-010 target block occurs exactly once in the E7 postimage and can be replaced by the already admitted model-7 capacity form.

The three-way merge is conflict-free for this file. Its merged result is byte-identical to `E7 + admitted SWAP-009 + admitted SWAP-010` after restoring the B1 CRLF storage convention.

Therefore neither SWAP-009 nor SWAP-010 is reverted by SWAP-011 admission.

### MOD_RIA.f90

No B1 correction overlaps the historical E7 change. The admission candidate is the E7 postimage expressed in the current B1 CRLF storage convention.

## Derived current-B1 admission candidate

A deterministic three-way isolation was performed from exact byte authorities only. No algorithm or source was reconstructed from prose.

Candidate postimage SHA-256 identities:

- `MOD_MvG_functions.f90`: `6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104`
- `WC_K_models_04_11.f90`: `d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126`
- `MOD_RIA.f90`: `673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a`

The derived current-B1 patch has:

- changed-file set: exactly the same three source files;
- size: `37169` bytes;
- SHA-256: `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`.

A fresh application check against the exact three current B1.10 preimages passes and reproduces all three candidate postimage hashes above, including byte-safe application to legacy non-UTF-8 `MOD_RIA.f90`.

This derived patch is an admission transform from current B1.10. It is NOT the historical E7 patch and must never be relabelled as such. The immutable historical patch remains identified by `9ccf4ec4...`.

## Qualification inheritance assessment

Historical E5/E6/E7 evidence remains valid evidence for the exact E7 line, but it is not sufficient by itself for automatic current-B1 admission because relevant dependencies changed after E7:

- SWAP-009 changes vapor conductivity calls in `WC_K_models_04_11.f90` from `dabs(h)` to signed `h`, including `K_PDI_2` used by hydraulic model 10.
- SWAP-010 changes the model-7 capacity implementation in the same source module.

The current-B1 merge is mechanically unambiguous, but the composed numerical behavior must therefore be requalified. In particular, model 10 with vapor enabled is a required focused case because SWAP-009 changes a constitutive dependency used on the E7 derivative path.

No historical tolerance may be widened and no E7 source logic may be edited merely to obtain PASS.

## RECONCILE verdict

`CURRENT_B1_OVERLAP = FULLY_CLASSIFIED`

`RESIDUAL_ADMISSION_DELTA = BYTE_DERIVABLE_FROM_EXACT_E7`

`MECHANICAL_COMPOSITION = PASS`

`HISTORICAL_E7_MUTATED = NO`

`B1_MANIFEST_MUTATED = NO`

`ADMISSION_ALLOWED_NOW = NO`

Reason: independent qualification of the composed B1.10 + SWAP-011 candidate is still required because SWAP-009/SWAP-010 changed relevant dependencies after historical E7 qualification.

## Next permitted action

QUALIFY the exact candidate above against current B1.10, prioritizing:

1. source/build qualification with GNU Fortran 14.2 where reproducible;
2. affected hydraulic models 3, 5-12, with direct focus on 7, 10 and 12;
3. model 10 with vapor enabled and disabled;
4. Newton-route and endpoint comparison where the historical E6/E7 harness supports it;
5. mass-balance/output checks for executable full-model cases;
6. deterministic identity checks binding all results to the candidate postimage hashes.

Only a qualified candidate may proceed to B1.11 admission. No Energy Balance, RossFast, WFT300, new hydraulic method, tolerance widening or SWAP5 production change is in scope.
