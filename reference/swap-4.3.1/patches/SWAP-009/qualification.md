# SWAP-009 qualification evidence

Current B1 admission status: **CANDIDATE, NOT ADMITTED**

## Audit finding

The SWAP 4.3.1 issue register records SWAP-009 as:

```text
component: PDI hydraulics
category: code bug
status: FIX_TESTED
certainty: very high
severity: high
reproducible: yes
impact: large error in very dry soil conductivity
proposed fix: pass signed h to the vapor-conductivity helper
existing evidence: hydraulic tests and theory cross-check
```

## Independent constitutive reasoning

The B0 vapor helper uses a Kelvin relative-humidity term of the form:

```text
Hr = exp((h / 100) * MgRT)
```

where unsaturated pressure head `h` is negative. Passing `abs(h)` changes the exponent sign. That is inconsistent with the implemented formula and can give `Hr > 1` in unsaturated soil.

The four PDI conductivity functions are the affected callers. The minimal correction does not modify the helper itself and therefore preserves the shared Kelvin formulation for callers that already supply the correct sign.

## Recorded targeted results

The audit note reports, near 20 degrees C, the ratio between the old vapor term and the sign-corrected term as approximately:

```text
h = -1e5 cm   -> 1.16
h = -1e6 cm   -> 4.26
h = -1e7 cm   -> 1.99e6
```

This confirms that the defect becomes increasingly important in the very dry range for which PDI vapor/film processes are relevant.

## Exact B0 / corrected-source verification

The candidate patch is isolated to four identical caller substitutions in `WC_K_models_04_11.f90`.

```text
canonical B0 SHA-256:
1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd

number of B0 target occurrences:
4

corrected target SHA-256:
f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7
```

`apply_and_verify.py` fails closed on an unknown B0 preimage, requires exactly four substitutions and verifies the corrected target identity.

## Qualification boundary

The available evidence demonstrates the sign defect and the direct constitutive correction. It does not by itself prove that every full SWAP PDI scenario is insensitive outside the intended conductivity change.

Before formal B1 admission, require at least:

- PASS of the independent VQ identity gate for the current repaired B1 base;
- successful application of the candidate to canonical B0/B1 construction;
- recovery or rerun of the PDI hydraulic testbank confirming the expected Kelvin/conductivity behaviour;
- at least one representative full PDI SWAP run or equivalent production-path regression with water-balance evidence, so that the physically active change is not admitted solely on a function-level test.

No tolerance relaxation is allowed for water balance.

## Conclusion

```text
BUG_CONFIRMED: PASS
DIRECT CONSTITUTIVE CORRECTION: PASS
CANONICAL B0 PREIMAGE: PASS
EXACT STORED PATCH IDENTITY: PASS
AUDIT HYDRAULIC TEST EVIDENCE: PASS
CURRENT B1 BASE IDENTITY: PENDING VQ
FULL PDI PRODUCTION-PATH REGRESSION: PENDING
B1 ADMISSION: PENDING
```
