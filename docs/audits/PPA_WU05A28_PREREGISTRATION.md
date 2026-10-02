# PPA-WU05-A28 preregistration — opt-in approximate RFM sorptivity mode

Date: 2026-10-02
Status: PREREGISTERED

## Purpose

Promote the qualified PERF07 research policy into an explicit, non-default RFM runtime mode without changing the exact/reference RFM path.

## Configuration contract

The runtime configuration exposes a versioned sorptivity policy:
- RFM_SORPTIVITY_POLICY_EXACT = 0: existing fixed-panel behavior;
- RFM_SORPTIVITY_POLICY_A28_V1 = 1: explicit approximate opt-in.

A28_V1 is valid only with the 64-panel reference ceiling and selects:
Initial PERF07 policy was prospectively falsified by Q2 (max 4.5951% over 36 materials, O13 at h=-100 cm). The replacement A28_V1 policy is frozen from the broadened frontier with margin:
- h < -30 cm: 64 panels;
- -30 <= h < -3 cm: 32 panels;
- h >= -3 cm: 16 panels.

The sampled 36-material frontier gives maxima of 0.7087% at -30 cm for 32 panels and 0.6318% at -3 cm for 16 panels. The 8-panel route is not admitted into A28_V1 because its -1 cm maximum is 0.9824%, too close to the 1% gate for an unsampled continuous interval.

The exact policy remains the default. Unknown policies fail configuration validation. The approximate policy is numerical execution policy only and does not change physical state ownership, mass accounting, forcing, or Reference Richards ownership.

## Qualification gates

### Q1 configuration and preservation
- default configuration remains EXACT;
- clear() restores EXACT;
- invalid policy fails closed;
- A28_V1 with a non-64 reference ceiling fails closed;
- exact panel selection is unchanged.

### Q2 broadened constitutive panel frontier
Use all 36 Staringreeks-2018 catalog rows already used by A27 actual-hydraulics qualification, not only B01/O05.
Sample h = -2000,-1000,-500,-400,-350,-300,-250,-200,-150,-100,-75,-50,-30,-20,-10,-3,-1 cm.
Compare A28_V1 against 64 panels with the actual default-MvG provider.
Gate: maximum relative surface-sorptivity error <= 1%.

This is a constitutive/numerical gate, not field validation.

### Q3 trajectory qualification
Only if Q1-Q2 pass, run the existing 32-case production ABC screen with approximate mode explicitly enabled. Compare every jointly completed approximate-C case to the qualified fixed-64 C owner.
Require:
- mass residual <= 1e-6 cm;
- no E1 -> E0/E2/E3 regression on jointly completed cases;
- final storage and drainage difference <= 0.02 cm;
- max sampled theta difference <= 0.01;
- record nonlinear iterations/retries and timing without treating timing as portable.

### Q4 longer-history extension
Before MultiSWAP-MODFLOW production eligibility, add trajectories long enough to expose repeated wet/dry cycling and wall-history accumulation. Q1-Q3 alone cannot establish that production envelope.

## Decision boundary

Passing Q1-Q3 makes A28 a broader approximate-mode candidate, not a production default and not yet a MultiSWAP-MODFLOW production admission. Q4 plus canonical admission remains required.
