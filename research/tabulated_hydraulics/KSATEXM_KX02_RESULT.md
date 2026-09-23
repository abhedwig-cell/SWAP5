# TAB-HYD-KX02 — source-head KSATEXM branch result

Date: 2026-09-23

Status: **FALSIFIED_FLOATING_BRANCH_EQUIVALENCE; INFORMATIVE**

Controlling run: `35857710405`.

## Candidate

KX02 replaced KX01's generated-theta branch classifier by the source head threshold:

`h > -2 cm`.

The F-SI39 interpolation fraction remained based on generated-table relative saturation and was not clamped.

## Result

Quantitative fidelity remained strong:

- theta max abs = `6.69411e-6`;
- C max abs = `2.53671e-5`;
- log10(K) max abs = `3.08709e-4`;
- active-branch K max abs = `1.32497e-2 cm/d`;
- active-branch K max relative = `5.82272e-5`;
- transition K max abs = `9.58108e-6 cm/d`;
- continuity jump = `1.77403e-6 cm/d`.

The frozen active-fraction gate passed without clamping:

- minimum f = `7.99395e-9`;
- maximum f = `0.9999999996883`;
- non-finite active fractions = 0.

Saturated and h=-1 F-SI39 oracles remained correct, and h=-5 remained an exact no-op.

However, the strict branch-identity gate still found exactly two local mismatches, again one per layer at the floating value immediately above -2 cm.

## Interpretation

In exact mathematics the F-SI39 threshold generated at h=-2 cm is equivalent to a head threshold for H_ENPR=0. In floating arithmetic the canonical implementation does not branch directly on head. It:

1. evaluates analytical water content;
2. reconstructs relative saturation by subtraction/division;
3. applies the strict comparison `relsat > c(11)`.

The resulting floating branch boundary is therefore not guaranteed to equal the representable test `h > -2.0` at the adjacent floating value.

KX02 is rejected because it replaces the canonical numerical branch predicate by a mathematically equivalent but not floating-equivalent predicate.

## Consequence

The next candidate must preserve F-SI39 as an explicit source-authority branch rather than infer its activation from either generated theta or head.

KX03 will compute the canonical default-MvG theta/relative-saturation expression with the same operation ordering solely for F-SI39 classification and interpolation, while retaining the generated table for the normal K0 theta/C/base-K path.
