# SWAP-009 qualification

## Audit classification

The SWAP 4.3.1 issue register records:

```text
ID: SWAP-009
component: PDI hydraulics
category: code bug
status: FIX_TESTED
certainty: very high
severity: high
reproducible: yes
impact: large error in very dry soil conductivity
test evidence: hydraulic tests and theory cross-check
upstream advice: submit as separate physics bug
```

The wording "physics bug" in the audit means that the implementation error directly affects a physical constitutive term. The correction itself does not introduce a new PDI formulation; it restores the sign required by the already implemented Kelvin equation.

## Code-level proof

B0 `Kvap_func` contains:

```fortran
Hr = dexp(h/100.0d0*MgRT)
Kvap_func = fKvap*D*Hr
```

For an unsaturated pressure head `h < 0`, this gives `0 < Hr < 1`, as required for relative humidity below saturation.

The four PDI callers in B0 instead pass `dabs(h)`. Therefore the same equation receives a positive value and produces `Hr > 1`. The sign error is entirely upstream of `Kvap_func`; the minimal correction is to pass the original signed `h`.

## Independent magnitude check

At 20 °C, using the constants from `Kvap_func`, the old versus corrected relative-humidity factor differs by:

```text
h = -1e5 cm: old/corrected = 1.156064795...
h = -1e6 cm: old/corrected = 4.264044823...
h = -1e7 cm: old/corrected = 1.987090345e6
```

These reproduce the audit note's approximately `1.16`, `4.26`, and `1.99e6` ratios. The repository helper `theory_check.py` encodes this algebraic check without requiring a Fortran compiler.

## Historical hydraulic evidence

The audit technical note classifies PDI vapor conduction as a proven physical/code error and a direct local fix. It reports targeted numerical testing and includes the PDI sign correction in the group of small, safe maintenance fixes recommended for upstream submission.

The broader hydraulic testbank directly exercises the SWAP constitutive functions. Its role here is supporting evidence that the corrected PDI implementation was evaluated in the same controlled hydraulic framework as the other 4.3.1 constitutive checks. This admission does not claim a dedicated long-duration end-to-end dry-soil field scenario was run solely for SWAP-009.

## Byte-exact provenance

```text
B0 WC_K_models_04_11.f90 SHA-256
1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd

minimal SWAP-009 fix.patch SHA-256
43e63c098868632da51a3dd1c2980e9af72d6ce2a3dabafadff76f2151256f66

corrected WC_K_models_04_11.f90 SHA-256
f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7
```

The exact B0 target string occurs four times, corresponding to the four PDI conductivity functions. No other code is changed by the isolated patch.

## B1 admission reasoning

This meets the corrected-reference rule:

- a demonstrable implementation defect exists;
- the intended existing equation is unambiguous from `Kvap_func` and the signed pressure-head convention;
- the correction is minimal and local;
- the issue is already `FIX_TESTED` in the audit line;
- the B0-to-B1 numerical difference is expected and physically meaningful in the dry PDI range;
- no new model formulation is introduced.

## Qualification conclusion

```text
BUG_CONFIRMED: PASS
INTENDED FORMULATION ESTABLISHED: PASS
EXACT B0 PREIMAGE: PASS
MINIMAL PATCH ISOLATION: PASS
INDEPENDENT KELVIN-SIGN CHECK: PASS
HISTORICAL HYDRAULIC QUALIFICATION: PASS
MODEL-CHANGE EXCLUSION: PASS
B1 ADMISSION: PASS
```

Mass conservation remains a hard SWAP5 invariant. SWAP-009 changes a constitutive conductivity contribution, not the accounting equations themselves. Future B2 qualification must therefore still include water-balance checks for scenarios in which the corrected dry-soil vapor term materially affects fluxes.
