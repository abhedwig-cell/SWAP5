# SWAP-011 B1 correction

Current B1 status: **ADMITTED_B1 / B1.11**

Technical audit status: **FIX_TESTED / READY_PATCH_UPSTREAM**

Historical provenance status: **EXACT_E7_RECOVERED_AND_VERIFIED**

Current ordered-admission status: **FULL_CANONICAL_REPLAY_PASS / ADMITTED_B1**

Contents:

- `finding.md`: defect, intended rule and classification;
- `qualification.md`: historical E5/E6/E7 qualification and B1.11 replay closure;
- `PATCH_PROVENANCE.md`: recovered historical E7 authority and ordered-admission relationship;
- `fix.patch`: exact qualified F-PE19 **B1.10 -> B1.11 ordered admission transform**;
- `apply_and_verify.py`: byte-safe ordered-preimage applicator;
- `tests/README.md`: regression and qualification map.

The stored `fix.patch` is deliberately **not relabelled as the historical E7 patch**. The immutable historical E7 patch remains in the recovered external E7 package and is pinned by SHA-256 `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110` in `PATCH_PROVENANCE.md`. The ordered B1.10 admission transform has SHA-256 `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238` and preserves the already admitted SWAP-009, SWAP-010 and SWAP-012 semantics.

The complete byte-safe replay from the exact B0 distribution passed and reproduced the frozen B1.11 identity exactly:

```text
members          63
source bytes      1,886,519
manifest SHA-256  24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2
```

The one-shot transport/materialization machinery used to persist the exact mixed-line-ending **ordered B1.10 admission patch** was removed after successful materialization; its commits and successful Actions run remain in branch history as audit evidence.

`SWAP-011` is formally part of the corrected reference starting at B1.11.
