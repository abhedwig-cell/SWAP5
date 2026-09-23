# TAB-HYD-KX05 — precomputed floating-equivalent F-SI39 boundary preregistration

Date: 2026-09-23

Status: **PREREGISTERED_RESEARCH_ONLY**

## Motivation

KX03/KX04 resolved scientific correctness by recomputing canonical analytical theta/Se inside every active-provider evaluation. The direct four-node solver gate passed scientifically but the active-extension case was about 27% slower than analytical.

KX01/KX02 showed that the only branch-identity problem occurs at the floating neighborhood of the source h=-2 cm transition.

For H_ENPR=0 default MvG, authority Se is monotone in pressure head. Therefore the canonical strict predicate has a single floating transition.

## Frozen KX05 candidate

At immutable provider initialization, per material/node:

1. start from exact source threshold h=-2 cm;
2. evaluate the canonical-authority theta/Se operation ordering;
3. advance with Fortran `nearest(h,+1)` until the first representable pressure head for which `Se_authority > Se_threshold`;
4. store that first-active head as immutable numerical metadata.

At runtime:

- evaluate generated raw-head400 theta/C/base-K exactly as in the qualified provider;
- classify F-SI39 as active iff `h >= first_active_head`;
- if active, compute the F-SI39 interpolation fraction from generated-table theta/Se;
- apply the exact linear Kthr-to-KSATEXM formula;
- do not recompute analytical theta/Se in the hot path.

No clamping or tolerance-based branch decision is allowed.

## Constitutive gate

Exact Hupsel upper/lower parameters and KX01-KX03 scans.

Required:

- zero global and local branch-classification mismatch against canonical analytical F-SI39;
- report first-active head and bounded search-iteration count;
- theta max abs <=1e-4;
- C max abs <=1e-4;
- log10(K) max abs <=5e-4;
- active-branch K max relative <=1e-4;
- saturated KSATEXM exact within 1e-9;
- h=-5 extension no-op;
- active interpolation fraction finite and within [0,1];
- local K continuity jump <=1e-5 cm/d.

## Solver/performance decision

If constitutive PASS:

- compare KX05 and KX03 in the same KX04 three-regime typed Reference-Richards harness;
- both must satisfy the KX04 scientific gates;
- performance is reported paired against analytical and against KX03.

KX05 is preferred for handoff only if it preserves KX03 scientific closure and removes a material part of KX03's active-extension overhead.

No production branch is changed by this research experiment.
