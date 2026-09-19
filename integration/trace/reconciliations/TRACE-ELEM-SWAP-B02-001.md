# TRACE-ELEM-SWAP-B02-001 reconciliation

Date closed: 2026-09-19
Prospective result: `NO_CONFIRMED_DISCREPANCY`
Candidate IDs: none

## Element

Reference evapotranspiration demand and drought-only root-water uptake, selected before detailed inspection as the Batch-02 process relation.

## Frozen scientific and implementation scope

The reviewer page itself binds the claim to the frozen SWAP5 Status-A review baseline and identifies the restricted reference profile rather than the full historical SWAP evapotranspiration chapter. It explicitly excludes broader historical ET methods, interception variants, wet/oxygen stress, salinity stress, compensation and process-based root hydraulics.

The exact frozen scientific production baseline used for direct source inspection is `50346642bd565f79134ea17d5462e544b354998c`.

Direct inspection of the frozen source confirms the reviewer equations.

### ET demand

`src/process/mod_reference_et_demand_process.f90` blob `f5e88ec5089fd3b57ac111065fab2aa32dde0fae` implements:

- uncovered demand `ET_ref*(1-c)`;
- soil evaporation `max(0,0.1*ET_uncovered)`;
- pond evaporation `max(0,0.1*ET_uncovered*f_pond)`;
- emerged-crop potential transpiration `max(0,0.1*ET_ref*c*k_c)*f_CO2`;
- zero potential transpiration without crop emergence;
- no consumption of crop-specific factors on the non-emerged route.

F-VQ35 independently qualified this exact ET-demand source blob over 1700 grid cases. F-VQ36 separately qualified its generic-time runtime binding without broadening the root-uptake claim.

### Root-water uptake

`src/process/mod_root_water_uptake_process.f90` blob `e6134587cf3c0164bbe09f2f4c87aef6886aaeb3` implements:

- cumulative-root-fraction differencing for compartment potential extraction;
- demand-dependent interpolation of `h3`;
- the `h4` drought cutoff;
- `alpha_dry` multiplication of potential extraction;
- exact reporting of potential, actual and drought-reduction terms as one physical root withdrawal;
- early zero routes for no roots and negligible transpiration.

F-CI19's full source-lineage admission audit identifies this exact root-process blob as F-VQ22 `INDEPENDENT_PROCESS_ADMISSION` for the MACRO/Feddes drought-only root-water-uptake process, while explicitly stating that higher runtime composition is not implied.

The current canonical blob remains identical. Later runtime/coupling work therefore does not replace the process-level scientific authority.

## Post-selection canonical delta

After Batch-02 preregistration, canonical advanced from `c95ded26961ada4b1d6d7bf36e6fa8f75b0d12b9` to `308a619c91d2cc3dae7f7aa143cfbe97c780c635`.

That delta included PPA-ROOT-HYD01 and a change to `src/solver/mod_reference_richards_temporal_indicator.f90`.

PPA-ROOT-HYD01 is relevant because it studies root-active hydraulic execution, but its own preregistration and R1 result explicitly separate the issue from the root-uptake process relation:

- ROOT and mathematically equivalent GENERIC prescribed sinks had identical D1 rejection patterns;
- the isolated gap was temporal-certificate coverage;
- R1 changed only the restricted temporal-indicator policy for concrete `b110_root_sink_provider_t`;
- HeadCalc, Richards equations, Feddes logic, the root-sink provider, defect equations, tolerances and transaction core were not changed.

Therefore this post-selection development does not create a discrepancy in the selected ET/root-uptake process semantics.

## TRACE disposition

No prospectively new discrepancy was found between the bounded reviewer-facing ET/root-uptake formulation, frozen process implementation and relevant qualification/admission evidence.

No candidate was registered.

This is a denominator null observation. It does not claim that all historical ET or root-stress physics are admitted, and it does not treat the later temporal-certificate extension as part of the root-uptake process equation itself.
