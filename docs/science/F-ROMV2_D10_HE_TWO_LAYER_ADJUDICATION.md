# F-ROMV2 D10 — faithful He two-layer comparator adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D10  
**Decision:** **HE2_PUBLISHED_CORE_NOT_COMPETITIVE_ON_ITS_ZERO_HEAD_ENVELOPE**

## Question

D10 asks a deliberately narrow question:

> Does the published fixed-H two-layer integrated Richards core provide a stronger reduced-physics comparator than R2 when both are tested against R16 on a lower-boundary condition that is clearly inside the published model envelope?

The lower boundary is zero pressure head.

D10 does **not** test the arbitrary nonzero unsaturated prescribed-head histories used in earlier F-ROMV2 development work.

## Literature authority recheck

Before adjudicating the result, the primary 2021 paper was rechecked.

Its coordinate and sign definitions are:

- soil depth (z) positive downward;
- water flux (q) positive downward;
- (psi) is the negative of pressure head and is therefore positive capillary suction in unsaturated soil.

At the water table, the paper derives

[
q_2 =
K_{s2}
left[
1+
{2(psi_b-arpsi_2)over H-h}
ight].
]

For the published zero-pressure-head experiment, the authors explicitly set

[
psi_b=0.
]

D10 implements that expression without changing its sign convention.

No equation or sign correction is introduced after seeing the result.

## Matched experiment

All three routes use homogeneous B01 and the same initial effective saturation

[
S_e=0.85.
]

Column depth is 160 cm.

The reduced models use two 80-cm layers.

Four preregistered top-flux histories, P01-P04, are applied with a common zero-pressure-head lower boundary.

The time step is 0.001 day.

The first two intervals are matched zero-head seed intervals for R16, R2 and HE2.

R16 and R2 use the previously admitted D4 integrated-mass research numerical authority.

HE2 uses:

- the published integrated upper and lower balances;
- the published interface flux closure;
- the published zero-head bottom flux;
- iterative Heun;
- published corrector tolerance (10^{-4}) in volumetric water content.

## Immutable execution

Workflow run **35449382543**, job **105913774233**, executed head

`b11fd5ec8debcfa2145574bf28bcdb0cdb6ef18d`.

Artifact:

- ID: **10586298491**
- digest:
  `sha256:0b89a9b02af68c5d0d8cf4a42b403623cded1f4feba9d6b834cc13965a4f2f56`
- D10 result SHA-256:
  `8e9cd1b2a31aec95be809f3bf647d5c06ea518d87007e2b61448535c8d427c02`
- R16 O0/O2 SHA-256:
  `f97b46d4d5f92bde993b7a63afe74eaa37716b98cf4a49e90562e802f6055aea`
- R2 O0/O2 SHA-256:
  `3fd69af0e61b668e3df84dce3558ac17b9999299dfe329b85bcf68a77c68478a`.

The R16 and R2 O0/O2 payloads are each bitwise identical.

## Integrity

HE2 completes all 4 histories and 256 reported development intervals.

There is:

- no training;
- no calibration;
- no clipping;
- no adaptive substepping;
- no full-order fallback.

Maximum absolute transaction mass residual is about

**4.17e-15 cm**,

below the frozen **1e-12 cm** water-depth gate.

At the published (10^{-4}) water-content corrector criterion, every seed or development step converges in one Heun correction.

HE2 is therefore not rejected for numerical instability.

## Matched fidelity

Relative to R16:

| metric | HE2 | R2 |
|---|---:|---:|
| total-storage RMSE | 0.85813 cm | 0.60280 cm |
| cumulative bottom-exchange RMSE | 0.80907 cm | 0.56599 cm |
| terminal bottom-flux RMSE | 19.943 cm d-1 | 13.970 cm d-1 |
| upper-storage RMSE | 0.00164 cm | 0.000595 cm |
| lower-storage RMSE | 0.85966 cm | 0.60233 cm |
| bottom-flux sign errors | 256/256 | 256/256 |

HE2 is worse than R2 on both preregistered views.

The balance view fails.

The transient view fails.

Therefore the frozen decision is:

`HE2_PUBLISHED_CORE_NOT_COMPETITIVE_ON_ITS_ZERO_HEAD_ENVELOPE`.

## The sign discrepancy is physical

The 256/256 sign result was checked against the raw accepted R16 and R2 outputs.

At P01 step 1:

- R16 bottom flux is approximately **-19.40 cm d-1**;
- R2 bottom flux is approximately **+1.01 cm d-1**.

The zero-pressure lower boundary is much wetter than the initial unsaturated B01 profile.

R16 resolves strong capillary inflow from below.

R2 is too coarse to reproduce its direction.

This is not a parser sign inversion because both values come from the same Reference observation surface and the same `BOTTOM_FLUX` field.

HE2 also predicts the wrong direction.

That behavior follows directly from the published bottom closure.

At the initial B01 state,

[
arpsi_2 approx 29.79 {m cm}
]

while the lower-layer thickness is 80 cm, giving

[
q_2 =
K_s
left(1-{arpsi_2over 40}ight)>0.
]

The full R16 solution instead resolves an upward capillary response.

Thus the dominant D10 discrepancy is not in upper-zone storage. It is in the lower-zone/water-table flux approximation.

## Relation to the published validation

D10 does not contradict the published validation studies.

Those studies demonstrate that the two-layer model can perform well for many soils, layer thicknesses and forcing regimes, and also show that performance is generally weaker under zero-pressure-head conditions than under free drainage.

D10 asks a different, narrower question:

> Is the published core competitive for the wet B01/shallow-water-table state that is relevant to this SWAP5 reduction research?

For this exposed development state, the answer is no.

Published RMSE values are not imported as SWAP5 acceptance thresholds.

## Consequence for HE2_SWAPH

D9 explicitly required the faithful published core to justify interest before an arbitrary-nonzero-prescribed-head SWAP extension could be considered.

D10 does not meet that gate.

Therefore:

- `HE2_SWAPH` is **not authorized**;
- arbitrary nonzero bottom-head equations are not invented;
- no post-result modification of Eq. 31 is allowed;
- no parameter calibration is introduced to rescue the result.

## What remains open

D10 closes this particular He-derived extension route for the current B01 hydraulic accelerator question.

It does not close reduced modeling in general.

The wider F-ROMV2 evidence now says:

- C2 contains strong local state information but has inadequate domain coverage;
- R8/R4/R2 give a transparent coarse-Richards fidelity sequence;
- D5 instantaneous two-layer Darcy closure is dominated by R2;
- D7 one-state quasi-steady reconstruction is dominated by R2;
- D8 two-segment quasi-steady reconstruction approaches but does not cross the R2 frontier;
- the literature-faithful HE2 core is also dominated by matched R2 on the shallow zero-head B01 test.

The next step should return to the broader state of the art and ask which **different** reduction classes remain scientifically plausible, rather than adding another ad hoc layer or modifying a failed lower-boundary closure.

Production ROM remains unauthorized.
