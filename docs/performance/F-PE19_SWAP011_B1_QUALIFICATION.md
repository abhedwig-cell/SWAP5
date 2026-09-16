# F-PE19 — SWAP-011 current-B1 admission qualification

Date: 2026-09-16

Status: `QUALIFIED_FOR_B1_ADMISSION / SUPERSEDED_BY_B1_11_ADMISSION_CLOSE`

This is the historical QUALIFY checkpoint for the exact F-PE19 ordered admission transform. The current closure authority is `docs/performance/F-PE19_B1_11_ADMISSION_CLOSE.md`; exact replay evidence is `docs/performance/evidence/F-PE19_B1_11_FULL_REPLAY.json`.

## Candidate authority

Ordered preimage: corrected SWAP 4.3.1 `B1.10`.

Derived admission patch:

- SHA-256: `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`
- bytes: `37169`
- changed files: exactly `MOD_MvG_functions.f90`, `WC_K_models_04_11.f90`, `MOD_RIA.f90`

The exact historical E7 patch remains separately immutable at SHA-256 `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`.

The early qualification checkpoint predated the full canonical-distribution replay. Candidate postimage hashes printed in earlier revisions of this file were draft metadata and are not B1.11 byte authorities. The same stored ordered transform is controlled by the patch SHA above; final byte-safe replay established the authoritative postimages:

- `MOD_MvG_functions.f90`: `6b65ce49904aa0c037d6f43f93115af7d35227b7f67d52dbdd96b614da955ab5`
- `WC_K_models_04_11.f90`: `e963989e81622cf0554aeeb6ecae705e20b41ff03e259e1b8753df0609884874`
- `MOD_RIA.f90`: `fe696bdf463259868ad3659072566babc8288ab1d8329bf068f8d3b5945a0d2f`

## Fresh qualification evidence

Fresh source-bound qualification used GNU Fortran 14.2.0 and the unmodified hydraulic harness recovered from the historical testbank. Both current B1.10 and the ordered SWAP-011 candidate compiled successfully.

The unmodified hydraulic dK/dh testbank showed the known B1.10 derivative mismatch for affected models and zero >1% derivative failures for the SWAP-011 candidate across the tested models. The already admitted SWAP-012 inverse behavior remained zero-failure in the same tested scope.

A focused vapor-enabled finite-difference gate for models 8-11 closed the post-E7 SWAP-009 dependency interaction, including model 10. A separate model-12/RIA gate passed with vapor both disabled and enabled. A broad residual/constitutive invariance sweep covered `theta(h)`, `K(h)`, `C(h)` and inverse behavior and found the intended non-derivative observables bit-identical between B1.10 and the candidate in the tested scope.

Historical E5/E6/E7 evidence remains immutable evidence for the original E7 line. The F-PE19 qualification independently covers the composed current-B1 candidate where later admitted dependencies differ from historical E7.

## QUALIFY verdict

```text
SOURCE_BUILD                         PASS
UNMODIFIED_HYDRAULIC_TESTBANK       PASS
SWAP012_INVERSE_PRESERVATION        PASS
SWAP009_VAPOR_INTERACTION           PASS
RIA_MODEL12_VAPOR_OFF_ON            PASS
RESIDUAL_CONSTITUTIVE_INVARIANCE    PASS
TOLERANCE_WIDENING                  NONE
PRODUCTION_SOURCE_CHANGE            NONE
QUALIFICATION_VERDICT               QUALIFIED_FOR_B1_ADMISSION
```

The subsequent exact full B0 -> B1.11 replay also passed and reproduced the frozen source identity `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`. Therefore the earlier `Next permitted action` in this checkpoint has been completed.
