# F-ROMV2 D9 — published two-layer integrated Richards reconciliation

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D9  
**Decision:** **PUBLISHED_TWO_LAYER_INTEGRATED_RICHARDS_FAITHFUL_COMPARATOR_AUTHORIZED_WITH_BOUNDARY_ENVELOPE**

## Why D9 exists

D8 closed the clean-sheet QS2 composite manifold without authorizing a custom QS3.

The remaining question is whether the published two-layer integrated Richards formulation by He et al. provides a stronger existing reduced-physics candidate than the clean-sheet D5/D8 families.

The answer is **yes, as a literature-faithful research comparator**, but only inside an explicit boundary-condition envelope.

## Primary scientific authority

The equation authority is:

- He, J., Hantush, M. M., Kalin, L., Rezaeianzadeh, M., Isik, S. (2021), *A two-layer numerical model of soil moisture dynamics: Model development*, Journal of Hydrology 602, 126797, doi:10.1016/j.jhydrol.2021.126797.

The broader validation authority is:

- He, J., Hantush, M. M., Kalin, L., Isik, S. (2022), *Two-Layer numerical model of soil moisture dynamics: Model assessment and Bayesian uncertainty estimation*, Journal of Hydrology 613A, 128327, doi:10.1016/j.jhydrol.2022.128327.

A corrigendum exists for the 2022 assessment paper:

- doi:10.1016/j.jhydrol.2022.128424.

The 2021 model is not a bucket model and is not equivalent to D5.

It is derived by integrating the one-dimensional Richards continuity equation over two vertical control volumes.

## Published fixed-H core

With depth coordinate positive downward and (q) positive downward, the upper balance is

[
h,{dar	heta_1over dt}=q_0-q_1-har S.
]

For the lower layer,

[
(H-h),{dar	heta_2over dt}-	heta_{2s}{dHover dt}=q_1-q_2.
]

For a fixed-depth SWAP5 research column, (dH/dt=0).

The published interface closure is based on first-order/Taylor approximations:

[
ar psi_i approx psi_i(ar	heta_i),
qquad
ar K_i approx K_i(ar	heta_i).
]

With

[
eta={H-hover H},
]

the interface approximations are

[
psi(h)=etaarpsi_1+(1-eta)arpsi_2,
]

and

[
K(h)=etaar K_1+(1-eta)ar K_2.
]

The resulting interface flux is

[
q_1=
left[etaar K_1+(1-eta)ar K_2ight]
left[
1+{2over H}left(arpsi_2-arpsi_1ight)
ight].
]

This is the central distinction from D5 and D8.

D5 used instantaneous Darcy gradients between two layer-average states.

D8 reconstructed two quasi-steady subprofiles.

The published two-layer model instead closes the interlayer flux directly from a vertically integrated first-order approximation.

## Bottom-boundary authority

Two published lower-boundary cases are central.

### Free drainage

For a deep water table / unit gradient,

[
q_2approx ar K_2 approx K_2(ar	heta_2).
]

### Zero-pressure-head water table

For the shallow-water-table case,

[
q_2 =
K_{s2}
left[
1+{2(psi_b-arpsi_2)over H-h}
ight],
]

with the published verification using (psi_b=0).

The 2021 numerical experiments and the 2022 large texture/thickness evaluation repeatedly compare free-drainage and zero-pressure-head bottom conditions.

The literature therefore clearly supports those two cases.

## What is not automatically literature-faithful

The SWAP5 D01-D08/V01-V04 development workload contains nonzero prescribed pressure heads near the initial unsaturated pressure state.

That is not the same as the published zero-pressure-head water-table test.

A possible generalized lower-boundary expression could be derived for arbitrary unsaturated prescribed head. But doing so would be a **new SWAP5 extension** of the published model.

It must not be presented as a faithful reproduction without direct source authority.

Therefore D10 is intentionally narrower than the current D/V workload.

## Numerical scheme

The published model uses iterative Heun predictor-corrector integration.

The predictor is ordinary forward Euler.

The correction uses the average of the beginning- and end-of-step slopes and is iterated until

[
left|
ar	heta_i^{j+1,p}-ar	heta_i^{j+1,p-1}
ight|
le epsilon.
]

The 2021 experiments use

[
epsilon=10^{-4}
]

in volumetric water content.

Their principal comparison timestep is 0.001 day.

For the first SWAP5 faithful reproduction, the published corrector tolerance is retained.

A SWAP5-specific timestep-sensitivity study, if needed, is separate from equation reproduction.

## Published evidence relevant to F-ROMV2

The 2021 study reports generally good agreement of layer-average moisture and cumulative fluxes against HYDRUS-1D for three soils.

The 2022 study expands this substantially:

- 231 soil textures;
- many combinations of upper- and lower-layer thickness;
- free drainage and zero-pressure-head lower boundaries;
- contrasting-permeability layers;
- a field application.

The authors explicitly report worsening performance for thicker lower vadose layers and, under shallow-water-table conditions, coarse soils.

They identify the first-order truncation and the substitutions

[
arpsi_iapproxpsi(ar	heta_i),
qquad
ar K_iapprox K(ar	heta_i)
]

as important structural approximations.

That is directly relevant to the remaining lower-zone error diagnosed in D8.

## F-ROMV2 interpretation

This literature does **not** restore a requirement of numerical equivalence to Richards.

It supports the opposite framing: the two-layer model is intended to predict layer-average moisture and fluxes efficiently at field-to-watershed scale where detailed vertical profile resolution may be unnecessary.

That is exactly the purpose-dependent fidelity distinction adopted by F-ROMV2.

Published HYDRUS RMSE values are literature evidence, not SWAP5 acceptance thresholds.

## D10 authority

D10 is authorized to implement only a bounded faithful subset:

- homogeneous B01;
- fixed 160 cm total depth;
- 80 cm upper layer;
- 80 cm lower layer;
- no root sink;
- prescribed top flux;
- zero-pressure-head lower boundary;
- published interface equation;
- published zero-head lower-boundary equation;
- iterative Heun;
- published corrector tolerance (10^{-4});
- no calibration;
- no trajectory training;
- no production source change.

D10 compares that published equationset against the current-canonical R16 Reference route under matched forcing.

D10 is not blind confirmation and does not establish application acceptance.

## Successor boundary

If D10 shows that the faithful equationset is scientifically credible on the supported zero-head envelope, a later workunit may ask whether a **separately named** generalization to arbitrary nonzero prescribed bottom head is justified.

Such a model would be He-derived, not a literal reproduction.

If D10 already performs poorly relative to coarse Richards on the published envelope, there is no basis for inventing that extension merely to rescue the architecture.

Production ROM remains unauthorized.
