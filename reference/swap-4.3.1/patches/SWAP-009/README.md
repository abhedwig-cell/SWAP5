# SWAP-009: PDI vapor-conductivity pressure-head sign

Current B1 status: **CANDIDATE, NOT ADMITTED**

Audit status: **FIX_TESTED**

Severity: **high**

## Defect

The four PDI conductivity functions in B0 call the vapor-conductivity helper with `dabs(h)`:

```fortran
Kvap = Kvap_func (WC, dabs(h), Temp) * Conv
```

`Kvap_func` evaluates the Kelvin relative-humidity term using the supplied pressure head in the exponent. Unsaturated pressure head is negative, so replacing it by `abs(h)` changes the sign of that exponent and can produce relative humidity greater than one.

This is a demonstrable implementation error relative to the implemented Kelvin relation, not a proposal for new PDI physics.

## Minimal correction

Pass the signed pressure head unchanged in all four PDI conductivity variants:

```fortran
Kvap = Kvap_func (WC, h, Temp) * Conv
```

Affected functions:

```text
K_PDI
K_PDI_s
K_PDI_2
K_PDI_2_s
```

No capillary-conductivity, film-flow, retention or capacity expression is changed by this patch.

## Exact source identities

```text
B0 target:
SWAP/WC_K_models_04_11.f90

B0 SHA-256:
1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd

B0 bytes:
18693

exact stored fix.patch SHA-256:
43e63c098868632da51a3dd1c2980e9af72d6ce2a3dabafadff76f2151256f66

corrected target SHA-256:
f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7

corrected target bytes:
18669
```

The exact stored patch hash above was computed from the repository payload after upload, not predicted from an in-memory text representation.

## Qualification status

The central audit register classifies SWAP-009 as `FIX_TESTED`, certainty very high, severity high, with hydraulic tests and a theory cross-check. The audit's direct Kelvin-term check shows the old/corrected vapor-term ratio grows strongly with suction, approximately 1.16 at `h=-1e5 cm`, 4.26 at `-1e6 cm` and about `1.99e6` at `-1e7 cm` near 20 degrees C.

The correction is therefore B1-eligible in principle. Because this is a physically active hydraulic correction rather than a portability-only fix, formal admission is deliberately held until the repaired B1 identity oracle has independently passed VQ and the SWAP-009 admission checklist is complete.

## Classification

- confirmed implementation/code bug: yes
- intended constitutive relation changed: no
- computed PDI conductivity can change: yes, especially very dry soil
- new model physics: no
- B1 eligible in principle: yes
- B1 admitted now: no
