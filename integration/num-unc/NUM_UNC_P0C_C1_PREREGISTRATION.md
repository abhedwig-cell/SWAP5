# NUM-UNC P0C C1 preregistration: temporal inference-invariance test

Date: 2026-09-19
Timing: before any N1 execution

## Purpose

C1 is the first NUM-UNC P0C stage allowed to execute N1. It tests the three physical cases frozen by corrected C0-R1. It does not relocate the transition.

## Fixed cases

B01, Se=0.85, 16 x 10 cm cell-centred grid, zero prescribed bottom flux, zero root/drainage/evaporation, and the exact C0 forcing schedule.

Frozen multipliers:

- C- = 1.0006347656250001;
- C0 = 1.11181640625;
- C+ = 1.2229980468750001.

The N0 C0 switch first occurred in forcing block 8. This fixes the C0 pre/post split before N1:

- pre-transition common endpoints: blocks 1 through 7;
- post-transition common endpoints: blocks 8 through 16.

## Numerical realizations

N0 performs one Reference Richards solve of 0.0064 day per forcing block.

N1 performs two sequential Reference Richards solves of 0.0032 day within exactly the same 0.0064-day forcing block. The precipitation value is held identical across the two N1 half steps. Therefore forcing breakpoints and integrated external forcing are identical.

Both routes use the same nonlinear criteria and physical process configuration.

Any request for timestep reduction, solver non-convergence, internal retry, alternative linear solve, non-finite state, nonzero runoff or hard typed integrated-mass failure makes that route inadmissible. It is not repaired during C1.

## Primary scientific inference

For each physical case:

`PONDING_EVENT` if any accepted endpoint has ponding depth greater than (10^{-10}) cm, otherwise `NO_PONDING_EVENT`.

C1 asks whether this inference is invariant between N0 and N1.

## Common-endpoint divergence

At the end of every 0.0064-day forcing block, compare N0 and N1.

Primary trajectory metric:

[
D_\theta(t_k)=
\sqrt{\frac{1}{N}\sum_i(\theta_i^{N0}(t_k)-\theta_i^{N1}(t_k))^2}.
]

Secondary diagnostics:

- (D_{h,rms});
- (D_{h,inf});
- (D_{\theta,inf});
- absolute total-storage difference;
- absolute ponding-depth difference.

## Numerical baseline floor

The complete C- trajectory is prospectively designated as the no-switch numerical baseline.

[
U_{C-}=\max_k D_\theta^{C-}(t_k).
]

If C- itself changes primary inference under N1, it cannot serve as a no-switch floor and C1 is classified `UNRESOLVED_REFERENCE_ENVELOPE`; no alternative floor may be substituted after observing the result.

A representation floor of

[
U_{fp}=1024\epsilon(1)
]

is applied only to avoid division by exact floating zero.

## Amplification statistic

For C0:

[
D_{pre}=\max_{k=1..7}D_\theta(t_k),
]

[
D_{post}=\max_{k=8..16}D_\theta(t_k),
]

and

[
A=\frac{D_{post}}{\max(D_{pre},U_{C-},U_{fp})}.
]

The preregistered amplification criterion is:

[
A\ge4.
]

Additionally (D_{post}>2U_{C-}) is required.

The primary inference must also differ between N0 and N1.

## Outcome rule

For C0:

- same primary inference: `INVARIANT`, irrespective of continuous trajectory differences;
- different inference but amplification criteria fail: `THRESHOLD_PROXIMITY_ONLY`;
- different inference and both amplification criteria pass: `AMPLIFIED_INFERENCE_FRAGILITY`;
- any inadmissible N0/N1 route: `NUMERICAL_FAILURE_ONLY`;
- C- inference changes or no valid baseline floor can be formed: `UNRESOLVED_REFERENCE_ENVELOPE`.

C+ is an outer positive control. If it loses the ponding inference under N1, C1 is also `UNRESOLVED_REFERENCE_ENVELOPE`, because the frozen physical neighbourhood is no longer behaving as a stable bracketing family.

No outcome may trigger relocation of C-, C0 or C+.

## Claim ceiling

Even `AMPLIFIED_INFERENCE_FRAGILITY` in C1 is discovery evidence only. It must replicate prospectively in O14 before NUM-UNC passes the P0 go rule.
