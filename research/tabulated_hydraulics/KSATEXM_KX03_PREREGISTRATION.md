# TAB-HYD-KX03 — explicit analytical F-SI39 sub-branch preregistration

Date: 2026-09-23

Status: **PREREGISTERED_RESEARCH_ONLY**

## Motivation

KX01 showed that an approximate generated theta must not own a discontinuous F-SI39 branch predicate.

KX02 showed that replacing the predicate by the mathematically equivalent `h>-2 cm` is still not floating-equivalent to the canonical implementation at the adjacent representable boundary value.

The F-SI39 extension is already admitted physics. It should therefore remain an explicit authority branch rather than be re-approximated by the generated representation.

## Frozen KX03 candidate

For the current F-TAB02 scientific envelope:

- default MvG;
- H_ENPR=0;
- SWKIMPL=0;
- F-SI39 explicitly enabled.

Retain the generated raw-head400 provider for:

- returned theta;
- returned C;
- ordinary MvG K when F-SI39 is inactive.

For KSATEXM branch ownership only, compute an authority relative saturation using the same default-MvG water-content operation order as the canonical provider:

1. compute analytical authority theta for the supplied h, including the existing h>=0 and wet h>-0.01 branch semantics;
2. compute `Se_authority=(theta_authority-theta_r)/(theta_s-theta_r)`;
3. apply the exact canonical predicate `Se_authority > Se_threshold`;
4. when active, use `Se_authority` in the exact F-SI39 interpolation formula.

The generated theta/C outputs are not replaced by analytical values. The analytical sub-branch exists only to preserve the already-admitted F-SI39 conductivity extension.

No tolerance, clamp, solver-policy change or new physical state is allowed.

## Constitutive gate

Reuse the exact upper/lower Hupsel authority and KX01/KX02 scans.

Required:

- zero global and local branch-classification mismatch against canonical analytical F-SI39;
- saturated KSATEXM exact within 1e-9;
- lower h=-1 canonical oracle within 2e-10;
- h=-5 extension no-op;
- theta max abs <=1e-4;
- C max abs <=1e-4;
- log10(K) max abs <=5e-4;
- authority-theta max abs difference versus canonical <=1e-14;
- authority-Se max abs difference versus canonical <=1e-14;
- active F-SI39 K max abs <=1e-9 cm/d;
- active interpolation fraction finite and within [0,1];
- local continuity jump <=1e-5 cm/d.

Because the active branch uses the canonical authority Se, its conductivity should reproduce canonical F-SI39 to roundoff. Any material active-branch error falsifies the implementation.

## Next gate

Only after constitutive PASS, run a bounded typed Reference-Richards K0 comparison using the exact Hupsel two-layer KSATEXM parameters.

Do not alter `work/f-tab02-generated-k0-provider` from this research slice.
