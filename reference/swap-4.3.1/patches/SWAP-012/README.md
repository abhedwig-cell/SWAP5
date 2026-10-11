# SWAP-012 — hydraulic `prhead` inverse consistency

Status: **PREPARED FOR B1.9 ADMISSION**

B0 `prhead` uses the default unimodal Mualem-Van Genuchten analytical inverse for hydraulic models whose selected retention relation differs. Affected models are 3 and 5–12; model 4 is the unaffected standard-MvG control.

The admitted candidate is deliberately isolated from SWAP-011 although the historical combined audit patch changed both routines in `MOD_MvG_functions.f90`. SWAP-012 changes only the `prhead` import/local declarations and the inverse dispatch/bisection branch. No `dhconduc`/Jacobian derivative content is included.

Exact identity:

```text
B0 / ordered B1.8 MOD_MvG_functions.f90
a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390

fix.patch
263e515b7c80059c13e71fcbc3dc1f187b6d0673e07c0c265bbc140fea0df131

corrected target
4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1
```

B1.9 source identity:

```text
members          63
source bytes      1,863,300
manifest SHA-256  5e28510813e5748bae52ffd5c08027bb55b63858aa994ea90635b632826de657
```

See `finding.md`, `qualification.md` and `ADMISSION_CHECKLIST.md`.
