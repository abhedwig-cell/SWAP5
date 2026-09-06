# SWAP-012 qualification evidence

Current B1 admission status: **QUALIFIED CANDIDATE FOR B1.9**

## Exact provenance

```text
canonical B0 / ordered B1.8 target SHA-256
a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390
stored fix.patch SHA-256
263e515b7c80059c13e71fcbc3dc1f187b6d0673e07c0c265bbc140fea0df131
corrected target SHA-256
4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1
```

No admitted B1.1-B1.8 correction changes `MOD_MvG_functions.f90`, so the ordered B1.8 preimage equals canonical B0. The stored patch is SWAP-012-only; it contains no SWAP-011 `dhconduc` numerical-derivative implementation.

## Broad D2 qualification

The independent D2 study tested models 3 and 5–12 over 22,240 valid round trips. The original inverse produced 17,176 errors larger than 0.01 decade in pressure head. The bracketed inverse produced 0 failures; maximum corrected error was 2.09e-8 decade. Model 4 remained essentially machine-precise and unchanged.

The measured corrected-call cost was about 4–9 microseconds for models 3–11 and about 182 microseconds for RIA model 12. This is much slower than the incorrect closed-form inverse in relative terms but small in absolute terms; D2 classifies SWAP-012 `FIX_TESTED`. The D2 performance reservation belongs to the older SWAP-011 numerical derivative, not to SWAP-012 admission.

## Fresh isolated actual-source gate

A fresh strict GNU Fortran gate compiled the actual canonical B0 `MOD_MvG_functions.f90` and the exact SWAP-012-only corrected source with matched support modules. Sixty pressure heads were tested per hydraulic model 3–12, including model 4 as unaffected analytical control: 600 round trips total. Failure threshold: `1e-6` decade in pressure head.

```text
B0
model 3   60/60 fail
model 4    0/60 fail
model 5   60/60 fail
model 6   60/60 fail
model 7   60/60 fail
model 8   33/60 fail
model 9   60/60 fail
model 10  60/60 fail
model 11  60/60 fail
model 12  60/60 fail
TOTAL     513/600 fail
max error 7.4915 decades

SWAP-012 only
models 3–12  0/600 fail
model 4      machine-precision control
max error    1.17e-10 decade
```

This isolates the inverse repair from SWAP-011 even though both were historically carried in one broad patch.

## Behavioural envelope

For affected models, values produced through `prhead` may change because B1.9 returns the inverse of the actually selected retention relation instead of the unrelated default-MvG inverse. The retention functions themselves, conductivity functions, Richards residual/Jacobian, solver policy and mass criterion are unchanged by SWAP-012.

A future faster model-specific inverse is an optimization and must reproduce this corrected inverse contract.

Prospective B1.9 deterministic identity:

```text
members          63
source bytes      1,863,300
manifest SHA-256  5e28510813e5748bae52ffd5c08027bb55b63858aa994ea90635b632826de657
```
