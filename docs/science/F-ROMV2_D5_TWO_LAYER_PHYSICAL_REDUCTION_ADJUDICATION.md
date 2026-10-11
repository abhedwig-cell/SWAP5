# F-ROMV2 D5 two-layer physical-reduction adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D5  
**Decision:** **L2_IMC_NOT_COMPETITIVE_OR_NOT_ROBUST_IN_EXPOSED_B01_DOMAIN**

## Question

D5 tests whether an extremely small, training-free physical model can improve the
current computational-cost versus hydrological-fidelity frontier.

The candidate, L2_IMC, has only two dynamic states:

1. mean water content in 0-80 cm;
2. mean water content in 80-160 cm.

It uses the B01 Van Genuchten/Mualem relations, Darcy fluxes and one explicit
Heun predictor-corrector per observation interval.

There is no regression, calibration, lookup table, clipping, adaptive
substepping or full-order fallback.

The scientific precedent is the family of vertically integrated/two-layer
unsaturated-zone reductions, including He et al. (2021,
doi:10.1016/j.jhydrol.2021.126797) and He et al. (2022,
doi:10.1016/j.jhydrol.2022.128327). MetaSWAP
(doi:10.2136/vzj2007.0146) is a separate precedent for storage/flux-manifold
reduction and purpose-dependent hydrological fidelity. Neither is an
implementation donor for D5.

## Immutable execution

Workflow run **35445739551**, job **105904227494**, executed head
`e2263533fd54c3d8ddb1b82b29b8da0782a2c1ee`.

Artifact:

- ID: **10584269469**
- digest:
  `sha256:5d3d7aa22889f5fd1a373b656cbb1287e680e2c93efc7c7d1b17bc8f91cf2e29`
- result SHA-256:
  `e8336dd1bf49898963faa6c4a991c28516e60c874a7310034b5dff8baa030d15`.

The regenerated R16 O0 and O2 outputs are bitwise identical.

## Integrity

L2_IMC passes every integrity condition over all 12 exposed histories:

- no nonfinite states;
- no physical-bound failures;
- no clipping;
- no adaptive substeps;
- no full-order fallback;
- maximum absolute transaction mass residual about
  **4.12e-15 cm**, below the frozen **1e-12 cm** gate.

This is important: D5 is not rejected because the simple physical model becomes
unstable.

It is rejected because its hydrological fidelity is not competitive with an
already available comparator.

## Pooled fidelity

Relative to R16:

| metric | L2_IMC | admitted R2 comparator |
|---|---:|---:|
| total-storage RMSE | 0.051645 cm | 0.040709 cm |
| cumulative bottom-exchange RMSE | 0.051645 cm | 0.040709 cm |
| terminal bottom-flux RMSE | 3.579 cm d-1 | 3.002 cm d-1 |
| bottom-flux sign errors | 136/768 | 136/768 |
| histories with reversal-sequence mismatch | 8/12 | 8/12 |

The preregistered balance view therefore fails.

The preregistered transient view also fails.

The candidate eliminates nonlinear Richards solves but does not retain enough
hydrological fidelity to become non-dominated against R2.

Structural cheapness alone is not sufficient.

## Where the error originates

The two state components behave very differently.

Pooled upper-layer storage RMSE is only about

**2.19e-5 cm**.

Pooled lower-layer storage RMSE is about

**0.05165 cm**.

Almost the entire total-storage error therefore arises in the lower 80 cm.

This is a useful physical diagnosis. The main weakness is not the representation
of top forcing in the upper storage state. It is the instantaneous mapping from
a single lower-layer mean water content to the pressure-gradient and
groundwater/capillary exchange at the lower boundary.

A two-layer instantaneous Darcy representation is therefore too compressed in
exactly the part of the system where groundwater feedback requires profile
information.

## Regime dependence

The simple model is essentially exact in the pure flux-mode histories D01, D02
and D05.

Errors appear when the lower boundary is driven by prescribed head and when
forcing sequences switch between upper and lower controls.

Examples:

- D03 final cumulative-bottom-exchange error is more than four times the R16
  cumulative exchange;
- D06 terminal bottom-flux RMSE is about **5.64 cm d-1**;
- V02 final cumulative-bottom-exchange error is about **+26.2%**;
- V01-V04 all miss the R16 reversal sequence.

These percentages are development observations, not acceptance thresholds.

## Purpose-dependent interpretation

### Long-term regional water balance

**Architecture not retained by the D5 comparative frontier.**

A two-state model could in principle be useful for regional balance, but this
specific flux closure loses more cumulative fidelity than R2 while R2 already
exists as a comparator.

### Groundwater-coupled many-column simulation

**Not qualified.**

The weak lower-boundary magnitude and reversal behavior directly concern the
quantity that a groundwater coupler consumes.

### Fast-event simulation

**Not qualified.**

### Soil-moisture drought / ET

**Not tested.**

### Scientific process inference

**Not qualified.**

## Architecture conclusion

D5 falsifies one very specific idea:

> Two instantaneous layer-average water contents plus direct Darcy gradients are
> enough to outperform strongly coarsened Richards on the relevant
> cost-fidelity frontier.

They are not, in this B01 development experiment.

That negative result does not argue for adding fitted coefficients to L2_IMC.
The equations, conductivity averaging and single-step integrator are now
exposed and are not retuned.

Instead the lower-zone diagnosis points toward a different architecture:

> represent lower-zone storage and groundwater exchange through a quasi-steady
> profile/storage-flux manifold rather than through the instantaneous head
> implied by one layer-average water content.

That is conceptually closer to MetaSWAP-style reduction. The scientific
hypothesis is that a low-dimensional profile manifold can carry the
non-local relationship between storage, groundwater head and capillary/recharge
flux that L2_IMC loses.

The next workunit should preregister that manifold before generating any new
confirmatory evidence.

R8, R4 and R2 remain the coarse-Richards comparators.

Production ROM remains unauthorized.
