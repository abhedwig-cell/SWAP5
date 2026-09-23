# TAB-HYD-KX05 — precomputed floating-boundary KSATEXM constitutive result

Date: 2026-09-23

Status: **PASS_RESEARCH_ONLY**

Controlling workflow run: `35863485123`.

## Purpose

KX05 tests whether the explicit analytical authority-state recomputation used by KX03 can be removed from the hot constitutive path without changing the exact F-SI39 branch classification.

For each material, initialization locates the first representable pressure head for which the canonical authority state satisfies:

`Se_authority > Se_threshold`

The resulting pressure-head branch boundary is immutable provider metadata. Runtime branch selection is then based on pressure head, while the interpolation fraction uses the generated raw-head table state.

No tolerance-based branch switch is introduced.

## Result

Exact Hupsel upper/lower materials:

- theta max abs: `6.69411e-6`;
- C max abs: `2.53671e-5`;
- log10(K) max abs: `3.08709e-4`;
- active-branch K max relative: `5.82272e-5`;
- transition K max abs: `9.58037e-6`;
- global branch mismatches: `0`;
- local branch mismatches: `0`;
- continuity jump: `1.77403e-6 cm/d`;
- active interpolation fraction finite and inside [0,1];
- saturated KSATEXM matches the canonical oracle exactly at the reported precision.

Located first-active heads:

- upper material: `-1.9999999999999871 cm`;
- lower material: `-1.9999999999998426 cm`.

The bounded bisection required 53 iterations for both materials.

## Interpretation

KX01/KX02 established that using the generated theta value itself for strict branch ownership is not bitwise equivalent to the canonical F-SI39 predicate in the floating neighborhood of h=-2 cm.

KX05 resolves that mismatch without evaluating the analytical theta relation in the repeated hot path:

- branch ownership is frozen from the canonical authority at initialization;
- generated theta remains the runtime state used for the interpolation fraction;
- the scientific constitutive gates remain satisfied.

The initial KX05 workflow failures were classifier-only failures: the harness emitted
`KX05_FIRST_ACTIVE_SEARCH_STEPS` while the classifier expected
`KX05_FIRST_ACTIVE_ULP_STEPS`. Run `35863485123` corrects that administrative mismatch and is controlling.

## Next gate

Per preregistration, KX05 must be compared against KX03 in the same three-regime typed Reference-Richards gate.

No production code or canonical branch is changed by this result.
