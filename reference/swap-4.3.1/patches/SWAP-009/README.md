# SWAP-009: PDI vapor conductivity uses wrong head sign

B1 status: **ADMISSION CANDIDATE**

Audit status: **FIX_TESTED**

## Defect

Four PDI conductivity functions in B0 call:

```fortran
Kvap = Kvap_func (WC, dabs(h), Temp) * Conv
```

`Kvap_func` evaluates relative humidity through the Kelvin relation:

```fortran
Hr = dexp(h/100.0d0*MgRT)
```

For unsaturated soil, pressure head `h` is negative. Passing `abs(h)` therefore reverses the sign of the Kelvin exponent and yields `Hr > 1`, which is physically inconsistent for this suction-driven vapor term.

## Correction

Preserve the signed pressure head in all four PDI conductivity routes:

```fortran
Kvap = Kvap_func (WC, h, Temp) * Conv
```

Affected functions are the PDI, scaled-PDI, bimodal-PDI and scaled-bimodal-PDI conductivity routes in `WC_K_models_04_11.f90`.

## Exact identities

```text
B0 file: SWAP/WC_K_models_04_11.f90
B0 SHA-256: 1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd
B0 bytes: 18693

minimal fix.patch SHA-256:
43e63c098868632da51a3dd1c2980e9af72d6ce2a3dabafadff76f2151256f66

corrected WC_K_models_04_11.f90 SHA-256:
f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7
corrected bytes: 18669
```

The patch is the four SWAP-009 hunks isolated from the audited `SWAP_4.3.1_proposed_fixes.patch` and checked against the byte-exact B0 preimage.

## Qualification summary

The central issue register classifies SWAP-009 as `FIX_TESTED`, certainty very high, severity high. It records hydraulic tests plus theory cross-check and identifies a potentially large error in very dry soil conductivity.

The technical audit note gives a direct magnitude check at 20 °C: the ratio of the old to corrected vapor term is approximately 1.16 at `h=-1e5 cm`, 4.26 at `h=-1e6 cm`, and `1.99e6` at `h=-1e7 cm`.

## Classification

- implementation defect: yes
- physical model change: no; the correction restores the sign required by the implemented Kelvin relation
- affected physics: PDI vapor conductivity in dry soil
- expected B0-to-B1 difference: potentially substantial in the very dry PDI range
- mass-balance concession: none
