# PPA-WU05-A28 result — explicit approximate RFM sorptivity mode

Date: 2026-10-02
Status: Q1_Q3_QUALIFIED_BRANCH_ONLY
Production default: NO
MultiSWAP-MODFLOW production eligible: NO

## Prospective falsification retained

The original PERF07 policy (64/32/16/8 panels at -300/-100/-30 cm) failed the broadened 36-material gate. Run 37005436943 found a maximum relative sorptivity error of 4.5950703328%, at O13 and h=-100 cm. This invalidates direct promotion of PERF07 from B01/O05 to a general approximate runtime mode.

The broadened panel frontier was therefore used to freeze a replacement before trajectory qualification.

## Qualified A28_V1 policy

A28_V1 is explicit opt-in and uses the 64-panel route as reference ceiling:
- h < -30 cm: 64 panels;
- -30 <= h < -3 cm: 32 panels;
- h >= -3 cm: 16 panels.

The exact fixed-panel policy remains the runtime default. Unknown policy identifiers fail validation. A28_V1 with a non-64 reference ceiling fails validation.

## Q1/Q2

Persisted run: 37006043173
Postimage: 281ee3680fa290e8ae84f90f5033f0883b203413
Artifact: 11225924965
Artifact digest: sha256:751bb633cad621aafa06b6c37f0e4284333a786ed7dd7b35301b25eadcefcc8b

The live backend compile gate passes.

The panel frontier covers all 36 Staringreeks-2018 catalog materials at 17 pressure heads from -2000 to -1 cm. Maximum relative A28_V1 sorptivity error versus 64 panels is 0.7086813221%, below the preregistered 1% gate.

This is numerical/constitutive coverage of the repository catalog, not field validation.

## Q3 exact-versus-approximate ABC

The same persisted run executes the complete 32-case production ABC harness once with exact fixed-64 C and once with A28_V1 C.

Exact and approximate C jointly complete 30 cases. The comparison gives:
- maximum total-storage difference: 5.9105396133e-9 cm;
- maximum bottom-outflow difference: 2.6587865243e-9 cm;
- maximum sampled theta difference: 1.7074686109e-10;
- maximum approximate mass residual: 9.8175369743e-11 cm;
- jointly completed B/C cases outside E1: 0.

All preregistered Q3 hydrologic gates pass by large margins.

Timing remains machine-specific. The A28 result does not establish a portable speed guarantee and does not use B-versus-C timing as an admission criterion.

## Decision

A28 establishes a real explicit approximate RFM runtime mode and materially broadens PERF07 beyond B01/O05. It does not yet establish the long-history production envelope.

Before MultiSWAP-MODFLOW eligibility, qualify repeated wet/dry cycling and wall-history accumulation over substantially longer trajectories, including state growth, restart/replay and accumulated hydrologic drift. Keep exact RFM as the default/reference path.
