# EB-I03 — Phase-Resolved Hydraulic Flux Seam

## Authority and purpose

EB-I03 is an additive conservation-output seam on top of the current-canonical reference Richards route. It does not change the admitted Richards equations, candidate hydraulic state, top/bottom boundary fluxes, Newton iteration, mass-balance acceptance, or committed runtime state.

Restart authority:

`integration/f-ci-canonical@2a0db2524fba6e258316ce82630c60ea1c9c673a`

Owner-qualified technical content head:

`4b461ee13363a1c4b45dc2de9f30865a1a6423b7`

Owner qualification:

- workflow run `34720796585`
- job `103626149517`
- canonical race guard: PASS
- frozen hydraulic seam preservation: PASS
- GNU Fortran `-O0`: PASS
- GNU Fortran `-O2`: PASS
- optimization-invariant test output: PASS

Production delta:

- `src/solver/mod_soil_water_phase_flux_view.f90`
- `src/adapter/mod_reference_richards_phase_flux_binding.f90`

Frozen current-canonical seams remain byte-identical:

- `src/solver/mod_soil_water_solver_contract.f90` blob `276941d76ba951a89c43899e61fd0532418d8230`
- `src/solver/mod_reference_richards_workspace.f90` blob `74f99556005ae39614f9df678467b1e19097bae2`
- `src/solver/mod_process_hydraulic_view.f90` blob `d7d85fe71ced0d94b29c8d9395859ae1834f7dd6`

## Why a separate result/view is required

The generic hydraulic process view contains hydraulic state but no interval face-flux field. The reference Richards worker workspace does contain numerical face-flux-related scratch, but that scratch is solver-internal, is not a general accepted-step publication contract, and is not guaranteed to be fully materialized on every route.

EB-I03 therefore does not expose HeadCalc or workspace arrays directly. It defines a solver-independent candidate interval result view and implements one reference-Richards producer in the adapter layer. Other soil-water solvers may later produce the same logical view through their own implementation.

The view is result data, not physical state. It is not restart state and it is not retained per column unless a later runtime consumer explicitly chooses to retain or aggregate it.

## Sign, topology and units

For an active profile with `n` compartments, the view has `n+1` faces:

- face 1: top boundary;
- faces 2..n: internal compartment interfaces;
- face n+1: bottom boundary.

The admitted reference sign convention is retained: **positive upward**.

The liquid flux rate is reported in `cm/day`. The interval-equivalent liquid transport is reported in `cm` and is computed as

`Q_face = q_face * step_duration`.

This multiplication is qualified only as the transport amount represented by the existing backward-Euler discrete interval equation. EB-I03 does not claim that it is a higher-order reconstruction of the continuous-time integral `∫ q(t) dt`.

## Residual-preserving reference reconstruction

For reference Richards compartment `i`, the final discrete residual has the form

`r_i = storage_i + sink_i - source_i + root_i + q_i - q_(i+1)`.

EB-I03 replays that equation as

`q_(i+1) = q_i + storage_i + sink_i - source_i + root_i - r_i`,

starting from the already published candidate top flux.

The final Newton/continuity residual is deliberately included. EB-I03 therefore does **not** force the reconstructed faces to close by setting `r_i=0`, does not repair the water balance, and does not hide an accepted numerical residual. The residual vector is published alongside the liquid face field.

The reconstructed bottom face is compared with the existing published bottom flux. Their difference is exposed as `bottom_flux_consistency_residual_cm_day`; it is not silently overwritten.

## Phase semantics

EB-I03 provides a physically identified **liquid-water** face-flux field for the qualified reference single-domain Richards route.

It deliberately does not invent a vapor flux:

- `vapor_phase_modelled = false`;
- `vapor_flux_available = false`;
- `vapor_transport_available = false`;
- `full_physical_phase_coverage = false`.

A missing vapor model is not equivalent to a qualified zero vapor flux. A later vapor-transport capability must publish its own phase-resolved contribution before full physical phase coverage may become true.

## Fail-closed boundary

The reference binding is unavailable when any of the following applies:

- the solve result is not `SW_SOLVE_CONVERGED`;
- the request lacks the parameter set;
- the request lacks an explicit source/sink provider;
- macropores are active;
- `step_duration <= 0`;
- active-node topology is inconsistent;
- required state/workspace arrays have inconsistent shape;
- required scalar or array values are non-finite.

The explicit source/sink-provider requirement prevents EB-I03 from silently depending on a legacy-global source/sink path that is not represented in the public request contract.

Macropore-active cases fail closed because matrix and macropore flow need an explicit path/phase accounting contract of their own; folding them into one matrix-liquid vector would overclaim physical coverage.

## Transaction semantics

The view is explicitly marked `candidate_interval = true`. It is derived from a converged candidate solve and is not a committed ledger entry.

A retry/non-converged result produces no available flux view. EB-I03 itself mutates no committed state. Runtime composition that transfers candidate hydraulic transport into a transactional energy ledger is intentionally deferred to a separate workunit, where commit/rollback and trial leakage must be qualified end to end.

## Relationship to energy conservation

EB-I03 supplies the liquid-transport quantity needed by later water-carried enthalpy accounting. It does **not** itself calculate energy.

A later thermal/energy composition may combine a qualified liquid transport field with an independently defined water-enthalpy convention and temperature field. That later composition must still qualify interpolation/upwinding, boundary-water temperature, time integration, and signs. EB-I03 alone does not make liquid advective energy `accounted=true`.

EB-I03 has no source dependency on the unadmitted EB-I01 ledger or EB-I02 owner branch. Their eventual composition requires a separate current-canonical integration/qualification workunit.

## Hard nonclaims

EB-I03 does not claim:

- a full SWAP5 energy balance;
- vapor transport physics;
- freeze/thaw phase transport;
- macropore path-resolved fluxes;
- exact continuous-time flux integration beyond the existing backward-Euler interval representation;
- runtime commit/rollback publication of the view;
- MultiSWAP throughput qualification;
- bounded-cost qualification for pathological columns;
- independent verification;
- canonical admission.
