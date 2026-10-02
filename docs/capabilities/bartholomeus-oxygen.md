# Bartholomeus oxygen stress: bounded production capability

Status: production-admission candidate, 2026-10-02. Canonical admission is recorded
separately in the C3A status/closeout authority, not inferred from this document.

## Applicability

The new typed Fortran standalone Reference application activates oxygen only with
oxygen mode 2, oxygen type 1 and analytical MvG REFERENCE waterfilm. In this
admission slice the application is homogeneous and serial, with prescribed-flux
bottom 2 or free-drainage bottom 7 and the existing restricted soil-temperature
owner. It does not admit groundwater-coupled, macropore, snow, drain-response,
elastic, hysteretic or tabular compositions. No generic legacy input parser,
all-crop lifecycle or worker-parallel oxygen capability is claimed.

OFF returns the incoming root sink exactly and does not allocate the extra oxygen
sink scratch. Unsupported oxygen modes/types and tabular waterfilm fail closed.
PRACTICAL/WFT300 remains MODE_NOT_ADMITTED.

## Inputs and ownership

The existing drought/Feddes root process produces the base root-extraction vector.
The crop owner publishes current nodal root dry-mass density in kg/m3 through the
separate `crop_bartholomeus_input_t`, with current atmospheric temperature in C.
This publication is not a root-fraction surrogate, interpolation or new crop state.
Specific root length in m/kg and the source crop constants reside in immutable
`fmr_bartholomeus_parameters_t`.

Construct soil data with `construct_bartholomeus_dataset`: hydraulic coefficients,
compartment thickness in cm, organic-matter and sand fractions, bulk density in
kg/m3, and owner-evaluated water contents at Campbell heads -100/-500 cm and the
diffusivity normalization head. The analytical source route uses the -100 cm
normalization. Sharing must include every construction input and initial
hysteresis branch. This slice admits branch 0 only; no shared cache is introduced.
The backend verifies geometry and MvG construction coefficients against its current
hydraulic parameter owner. Thickness is not cumulative depth.

## Runtime chain

Each trial reads its starting hydraulic and existing thermal states. REFERENCE
waterfilm, temperature-dependent parameters and microbial respiration feed the
MICRO/MACRO balance and bounded respiration solve. Ordered top-to-bottom evaluation
propagates C_top(node+1)=C_macro(node). Factors reduce only rooted extraction;
non-rooted entries are preserved. `mod_root_uptake_oxygen_composition` is the only
production composition authority.

The original base sink is restored before every active sibling/retry/step. Oxygen
owns no accepted continuation state, checkpoint field, restart payload or water
ledger. Thermal state remains with its existing owner. The existing root-sink
provider books the resulting extraction exactly once.

## Evidence and limitations

[Shared integration contract](../audits/PPA_WU05C3A_SHARED_INTEGRATION_CONTRACT.md),
[C3Q physics result](../audits/PPA_WU05C3Q_RESULT.md) and
[C3P composition](../audits/PPA_WU05C3P_RESULT.md) define the reference boundaries.
C3A actual application tests cover OFF exact identity, active reduction,
non-rooted preservation, no roots/zero demand, invalid/unsupported inputs,
A/B/A replay, rejected candidate isolation and owning thermal restart.
Hard unrounded water-balance residual must remain <=1e-12.

The complete unchanged corrected B1.11 oxygenstress source is SHA-verified and
compiled as the assembled oracle. Only unrelated input-owner modules are fixtures;
oxygen equations, waterfilm and SOLVE are not stubs. Forty-two physical evaluations
include no stress, intermediate stress, full stress, saturation and multi-node
propagation. Final RWU differences are required <=legacy SOLVE accuracy 1e-4.
This is bounded behavioural qualification, not an independent scientific review
or validation of every crop, soil or practical lookup.
