# SWAP-011 B1 candidate

Current B1 status: **QUALIFIED / NOT YET ADMITTED**

Technical audit status: **FIX_TESTED / READY_PATCH_UPSTREAM**

Historical provenance status: **EXACT_E7_RECOVERED_AND_VERIFIED**

Current ordered-admission status: **PATCH_PERSISTED / FULL_CANONICAL_REPLAY_PENDING**

Contents:

- `finding.md`: defect, intended rule and classification;
- `qualification.md`: recorded historical E5/E6/E7 qualification evidence;
- `PATCH_PROVENANCE.md`: recovered historical E7 authority and ordered-admission relationship;
- `fix.patch`: exact qualified F-PE19 **B1.10 -> B1.11 ordered admission transform**;
- `apply_and_verify.py`: byte-safe ordered-preimage applicator;
- `materialize_exact_fix_patch.py` and `artifacts/`: auditable exact-payload materialization route;
- `tests/README.md`: regression and qualification map.

The stored `fix.patch` is deliberately **not relabelled as the historical E7 patch**. The immutable historical E7 patch has SHA-256 `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`. The current ordered admission transform has SHA-256 `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238` and preserves the already admitted SWAP-009, SWAP-010 and SWAP-012 semantics.

F-PE19 has independently qualified that composed current-B1 candidate and frozen the prospective B1.11 identity. Formal B1 admission remains fail-closed until reconstruction from the exact canonical B0 source archive reproduces the frozen 63-member B1.11 manifest SHA-256 `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.

`SWAP-011` is not part of B1 until it appears in `../../b1-manifest.yml`.
