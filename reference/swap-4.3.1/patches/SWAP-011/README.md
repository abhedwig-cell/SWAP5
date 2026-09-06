# SWAP-011 B1 candidate

Current B1 status: **NOT ADMITTED**

Technical audit status: **FIX_TESTED / READY_PATCH_UPSTREAM**

Blocking provenance status: **PATCH_PAYLOAD_PENDING**

Contents:

- `finding.md`: defect, intended rule and classification;
- `qualification.md`: recorded E5/E6/E7 qualification evidence;
- `PATCH_PROVENANCE.md`: exact artifact/preimage requirements for B1 admission;
- `tests/README.md`: regression and qualification map.

There is deliberately no `fix.patch` in this directory yet. The final qualified E7 patch must be recovered from an original artifact and verified against the byte-exact B0 source identity. Reconstructing patch code from the documentation is prohibited.

`SWAP-011` is not part of B1 until it appears in `../../b1-manifest.yml`.
