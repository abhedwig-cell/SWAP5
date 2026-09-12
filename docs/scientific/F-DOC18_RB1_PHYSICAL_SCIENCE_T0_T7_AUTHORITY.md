# F-DOC18 — RB1 Physical-Science T0–T7 Authority

## Decision and scope

F-DOC18 closes the bounded `PHYSICAL_SCIENCE` portion of the F-DOC11 T0–T7 gap decomposition for exactly three immutable RB1 capabilities:

- `RB1-SW-REFERENCE`;
- `RB1-ET-ROOT-SERIAL`;
- `RB1-SURFACE-EVAP-RESTRICTED`.

Decision, only when the exact branch head passes the F-DOC18 qualification workflow:

`QUALIFIED_RB1_PHYSICAL_SCIENCE_T0_T7_AUTHORITY`

The exact documentation base is the qualified F-DOC16 conceptual-foundation head `b0bdf08b5c38771a4ee22c93ed0949f408ceeb2b`. The immutable RB1 scientific source remains `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`; RB1 qualification and release metadata remain `aeb74560d801c4ac7314df7b8845fcc5daf8bba6` and `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`.

This is documentation and traceability work. It changes no production source, reference data, physics, constitutive model, solver, tolerance, release denominator, performance policy or mass criterion.

## Authority method

F-DOC18 deliberately does not infer scientific theory from code presence or RB1 release PASS. Each capability is bound through four layers:

1. the F-DOC16 physical-system and 1D-column conceptual authority;
2. controlled SWAP scientific lineage, principally Working Group SWAP (2026), *SWAP: theory and user guide*, version 4.3.024, and Kroes et al. (2017), *SWAP version 4; Theory description and user manual*, DOI `10.18174/416321`;
3. the already qualified F-DOC04/F-DOC06 RB1 implementation and release traceability;
4. exact frozen RB1 source objects used only to confirm that the documented restricted formulation is the formulation actually admitted to RB1.

The 2026 legacy manual is a scientific-lineage source, not SWAP5 release authority. Where the manual describes broader options than RB1, the RB1 release profile is controlling and the broader option is not admitted by this document.

## 1. `RB1-SW-REFERENCE` — reference vertical matrix soil-water flow

### T0 — physical phenomenon: resolved

The represented phenomenon is vertical water storage and flow through a variably saturated porous soil profile within the representative one-dimensional column established by F-DOC16. Water can enter or leave through the top and bottom interfaces and through admitted distributed source/sink terms. Horizontal unsaturated flow is outside the column model.

### T1 — scientific theory: resolved, restricted

The scientific basis is conservation of water mass combined with Darcy–Buckingham flow in an unsaturated porous medium. In the SWAP convention documented by the scientific lineage, vertical coordinate `z` is positive upward and water flux `q` is positive upward:

`q = -K(h) d(h+z)/dz`.

For the admitted matrix-flow system, local storage change equals the negative flux divergence plus admitted sources and minus admitted sinks. Combining Darcy–Buckingham flow and continuity gives the one-dimensional Richards equation. Constitutive relations provide volumetric water content `theta(h)`, hydraulic conductivity `K(h)` and differential water capacity `C(h)=dtheta/dh`.

RB1 is not generalized by this statement to every constitutive option described in the legacy manual. Its release scope remains the frozen `SWSOPHY=0`, `SWKIMPL=0` reference profile already bounded by F-DOC04 and the RB1 release authority.

### T2 — conceptual process model: resolved

The soil profile is a stack of vertical compartments. Pressure head is the principal hydraulic potential state; water content follows the admitted constitutive relation. Adjacent compartments exchange vertical Darcy flux. Top and bottom interfaces supply boundary conditions. Root extraction, drainage and subsurface addition enter only through explicitly admitted sink/source terms. The process owns no horizontal spatial field.

This process is one realization behind F-DOC16 concepts `SW5-CONCEPT-0001` (representative 1D column), `SW5-CONCEPT-0003` (layered soil/root-zone domain) and `SW5-CONCEPT-0005` (bottom interface).

### T3 — formal mathematical model: resolved, restricted

For the broad scientific lineage:

`dtheta/dt = d/dz [ K(h) (dh/dz + 1) ] - S_a - S_d - S_m + S_si`,

with symbols following the controlled SWAP manual. For the frozen RB1 reference profile, only source/sink and constitutive terms that are actually admitted by the release capability may be active; the equation above is not a license to activate macropore or other excluded physics.

The formal initial-boundary-value problem consists of:

- an initial profile state for pressure head/water content consistent with the admitted constitutive relation;
- the one-dimensional Richards conservation law in the configured soil depth;
- an admitted top boundary condition;
- an admitted bottom boundary condition;
- admitted distributed source/sink terms;
- constitutive maps `theta(h)` and `K(h)` from the frozen reference hydraulic profile.

### T4 — SWAP/RB1-specific formulation: resolved, restricted

The immutable RB1 capability is the Full Richards `REFERENCE` route already bounded by F-DOC04: `SWKIMPL=0`, `SWSOPHY=0`, the frozen reference boundary profile, and no RossFast substitution. F-DOC18 does not admit active macropore physics, alternative Richards implementations, PDI variants outside the RB1 reference profile, or a different boundary profile.

Representative frozen source pins are:

- `src/adapter/mod_reference_richards_legacy_binding.f90` blob `6eda1fec1bd03c03a1c0a8f2df29a273f70d962f`;
- `src/legacy/b1_10_port/headcalc.f90` blob `55893f1f5ccba2052ad681743aa155b69f351246`.

The source pins confirm the admitted implementation binding; they do not substitute for T1 theory.

### T5 — computational continuous formulation: resolved

The continuous problem is evaluated over a caller-supplied model-time interval and remains independent of calendar-day boundaries. Flux divergence, storage change, boundary fluxes and source/sink terms retain their water-balance meaning. The continuous formulation is mass-conservative: numerical acceptance is not allowed to redefine or waive the physical balance.

### T6 — discretisation: resolved, restricted

The admitted scientific lineage uses an implicit backward finite-difference compartment scheme. For compartment `i`, storage is evaluated from the actual water-content difference `(theta_i^{j+1}-theta_i^j)` over the step, while internodal Darcy fluxes connect adjacent compartments. In the frozen `SWKIMPL=0` RB1 reference route the hydraulic conductivity contribution is explicitly linearized at the admitted old-time-level route; the storage relation remains nonlinear through `theta(h)`.

The spatial grid is one-dimensional and vertically compartmented. F-DOC18 does not impose a new grid, time step or application tolerance and does not make day/month/year a fundamental numerical unit.

### T7 — numerical solution method: resolved, restricted

The nonlinear discrete residual system `F_i(h)=0` is solved by the frozen reference Newton-Raphson route. The implementation builds the Jacobian, solves the tridiagonal linear system, attempts a full Newton step and backtracks when the residual objective does not improve. Convergence includes compartment water-balance and pressure-head criteria, with total-balance criteria retained in the admitted reference path. Failed attempts may request retry through the surrounding transactional machinery; only accepted state may become committed state.

This T7 authority documents the released reference route only. It does not qualify RossFast, an alternative nonlinear solver, a universal iteration tolerance or a universal time-step policy.

## 2. `RB1-ET-ROOT-SERIAL` — restricted reference ET demand and drought-only root uptake

### T0 — physical phenomenon: resolved

The represented phenomenon is atmospheric evaporative demand partitioned into potential plant transpiration and surface evaporation demand, followed by extraction of soil water by roots under the released drought-stress profile.

### T1 — scientific theory: resolved, restricted

The scientific lineage separates potential atmospheric demand from soil/root supply limitation. Potential transpiration is distributed over the rooted profile according to root distribution. The released root-stress concept is the drought side of the Feddes reduction function: root uptake is unreduced above the drought threshold `h3`, decreases linearly between `h3` and wilting threshold `h4`, and is zero below `h4`. The critical drought threshold varies with potential transpiration between configured low- and high-demand values.

Broader Feddes wet/oxygen stress, salinity stress, compensation models and process-based root hydraulics described in the SWAP manual are not admitted by this RB1 capability unless separately present in its frozen release profile.

### T2 — conceptual process model: resolved

The process chain is compositional:

1. externally supplied reference ET demand is partitioned using the released canopy/crop view into potential transpiration, potential soil evaporation and potential pond evaporation rates;
2. potential transpiration is handed explicitly to the root-uptake process;
3. rooted-layer fractions distribute potential uptake over rooted compartments;
4. the local pressure head applies the released drought-reduction factor;
5. the resulting root extraction vector is a soil-water sink and actual transpiration attribution is the integral/sum of that same sink, not a second mass booking.

### T3 — formal mathematical model: resolved, restricted

For the released reference-ET partitioning, the frozen process uses the restricted relations represented by `mod_reference_et_demand_process`:

- uncovered reference demand is `ET_ref * (1-cover)`;
- potential soil evaporation is the nonnegative uncovered reference demand converted from mm/day to cm/day;
- potential pond evaporation is the same uncovered demand multiplied by the configured pond factor and converted to cm/day;
- for an emerged crop, potential transpiration is `ET_ref * cover * crop_factor * CO2_factor`, converted to cm/day.

For root uptake in rooted compartment `i`:

`S_p,i = (f_{i+1}-f_i) * T_p`,

`S_a,i = alpha_dry(h_i; h3(T_p), h4) * S_p,i`,

where cumulative root fractions `f` are monotone from 0 to 1. The released drought factor is

- `alpha_dry = 0` for `h < h4`;
- linear from 0 to 1 for `h4 <= h <= h3`;
- `alpha_dry = 1` for `h > h3`.

`h3(T_p)` is the released piecewise-linear interpolation between configured low-demand and high-demand thresholds over the configured demand interval.

### T4 — SWAP/RB1-specific formulation: resolved, restricted

The frozen reference ET process states the restricted route `SWETR=1`, `SWMETDETAIL=0`, `SWCFBS=0`, `SWINTER=0`. The RB1 root capability remains the released drought-only precomputed-QROT profile described by F-DOC06. It does not imply crop-lifecycle advancement, arbitrary within-step QROT evolution, wet/oxygen/salinity reduction, general compensation or a broader crop model.

Representative frozen source pins are:

- `src/process/mod_reference_et_demand_process.f90` blob `f5e88ec5089fd3b57ac111065fab2aa32dde0fae`;
- `src/process/mod_root_water_uptake_process.f90` blob `e6134587cf3c0164bbe09f2f4c87aef6886aaeb3`.

### T5 — computational continuous formulation: resolved, restricted

Within this capability the ET and root relations produce rates over the current model interval; they are algebraic constitutive/process relations, not an independent time-evolution PDE. Their water-balance effect occurs when the resulting root-extraction rate is used as a sink by the soil-water solve over the interval.

Potential and actual transpiration attribution must refer to the same physical withdrawal. No extra mass term is created by reporting/attribution.

### T6 — process-local discretisation: not independently applicable

`NOT_APPLICABLE_WITH_RATIONALE`: the released ET partition and drought-reduction laws do not introduce a separate spatial/time discretisation beyond the already defined soil compartments, rooted fractions and caller interval. Root extraction is evaluated per existing soil compartment and is then consumed by the Richards discretisation. The T6 authority for water-state advancement remains `RB1-SW-REFERENCE`, not a second root solver.

### T7 — process-local numerical solver: not independently applicable

`NOT_APPLICABLE_WITH_RATIONALE`: the released restricted ET/root process is direct algebraic evaluation after input validation. It has no independent Newton, linear-system or adaptive-step solver. Numerical advancement and acceptance of the water state remain owned by the soil-water solver/transaction route.

## 3. `RB1-SURFACE-EVAP-RESTRICTED` — stateless Darcy-capacity surface evaporation

### T0 — physical phenomenon: resolved

The represented phenomenon is loss of water from the local surface to the atmosphere by evaporation, distinguishing a ponded surface from an unponded soil surface.

### T1 — scientific theory: resolved, restricted

For a wet surface, actual evaporation can meet atmospheric demand. As the soil dries, declining hydraulic conductivity can limit the rate at which liquid water is supplied to the surface. The SWAP scientific lineage therefore limits unponded soil evaporation by the maximum hydraulic/Darcy supply from the top soil. The broader manual also describes Black and Boesten/Stroosnijder empirical reductions, but those are explicitly outside the released `SWREDU=0` RB1 profile.

### T2 — conceptual process model: resolved

The process consumes two independent inputs:

- atmospheric demand: bare-soil and ponded-water evaporation demand;
- a hydraulic surface view: whether the surface is ponded and the current nonnegative evaporation capacity supplied by the hydraulic process.

If ponded, pond evaporation consumes the pond demand and bare-soil evaporation is zero. If not ponded, bare-soil evaporation is the lesser of atmospheric demand and available hydraulic capacity, while pond evaporation is zero.

The evaluator is stateless. Surface water and soil-water mass remain owned by the surrounding surface/soil transaction and accepted flux accounting.

### T3 — formal mathematical model: resolved, restricted

For an unponded surface:

`E_soil = min(E_soil,pot, max(0,E_capacity))`,

`E_pond = 0`.

For a ponded surface:

`E_soil = 0`,

`E_pond = E_pond,pot`.

The scientific lineage identifies the hydraulic limit `E_capacity` with the maximum Darcy supply from the upper soil. The broader legacy expression is

`E_max = K_1/2 * ((h_atm - h_1 - z_1)/z_1)`

under the manual's coordinate/sign convention. F-DOC18 binds the RB1 evaluator to the hydraulic-capacity interface; it does not require the surface process to know HeadCalc internals.

### T4 — SWAP/RB1-specific formulation: resolved, restricted

The immutable RB1 scope is exactly the stateless `SWINTER=0`, `SWREDU=0` profile recorded by F-DOC06. Black/Boesten-Stroosnijder cumulative state, interception-dependent alternatives and broader surface-evaporation options are excluded. The known call-local copy/allocation throughput topic remains outside this scientific authority.

Representative frozen source pin:

- `src/process/mod_restricted_surface_evaporation.f90` blob `a213af4deec2fe854d79120899827852a57237d1`.

### T5 — computational continuous formulation: resolved, restricted

The process is a local algebraic boundary-flux law evaluated from demand plus a hydraulic capacity. Its output is an evaporation rate for the current interval and does not itself advance a persistent storage variable.

Mass accounting is single-authority: the evaluator must not create a second authoritative top-water booking. Accepted top/surface flux accounting remains responsible for the actual water loss.

### T6 — process-local discretisation: not independently applicable

`NOT_APPLICABLE_WITH_RATIONALE`: the restricted stateless evaluator has no own temporal or spatial state discretisation. Its hydraulic capacity is obtained from the already discretised soil-water system and its rate is consumed by the surrounding boundary/transaction machinery.

### T7 — process-local numerical solver: not independently applicable

`NOT_APPLICABLE_WITH_RATIONALE`: the evaluator is a direct branch-and-minimum algebraic calculation. It has no independent nonlinear solver, retry mechanism or time-step controller. Those remain properties of the hydraulic/transaction route.

## 4. F-DOC11 physical-science closure result

F-DOC11 assigned exactly three capabilities to `PHYSICAL_SCIENCE`. F-DOC18 gives each of those capabilities an explicit disposition for all eight tiers T0–T7. After a green exact-head workflow, the physical-science portion of the F-DOC11 T0–T7 decomposition therefore has zero unresolved tiers.

This does **not** mean that the three capabilities become `FULLY_TRACED`. F-DOC04/F-DOC06 already bounded T8–T10 implementation traceability, while complete T11 equation-to-test coverage and T12 application validation remain separate obligations. Parameter provenance, calibration/N/A authority, sensitivity, uncertainty and application-specific fitness-for-purpose also remain outside F-DOC18.

## 5. Theory–code discrepancy rule

F-DOC18 reconciles scientific lineage with the frozen RB1 profile; it does not use prose to repair source behaviour. If a later check finds that a frozen implementation relation differs materially from this authority or its cited scientific lineage, that difference is a theory-code discrepancy and must be routed as a separate defect/qualification workunit. The documentation authority may not silently redefine the implementation or vice versa.

## 6. Architecture-invariant review

All 30 SWAP5 architecture invariants were reviewed. This workunit has no adverse architecture delta. Direct bindings are especially relevant to:

- one shared kernel and reusable physics (1, 20, 21);
- separation of physics and solver policy (23, 25);
- generic time (9);
- transactional accepted-state semantics (7, 8);
- mass conservation (13);
- clean hydraulic interfaces rather than HeadCalc internals (22);
- optional functionality paying only when active (27);
- no silent coupling/calendar/file assumptions (28, 29);
- explicit assessment of every architecture change (30).

No architecture or production change is made here.

## 7. Hard nonclaims

F-DOC18 does not:

- reopen or broaden immutable RB1 scientific/release scope;
- change any production source or reference data;
- admit RossFast, alternative Richards solvers, active macropores, broader PDI/MvG profiles or extra bottom-boundary modes beyond the frozen RB1 capability;
- admit wet/oxygen/salinity root-stress physics, process-based root hydraulics, crop-lifecycle advancement or arbitrary within-step QROT evolution;
- admit `SWREDU=1/2`, Black or Boesten/Stroosnijder evaporation in the RB1 restricted surface capability;
- qualify surface-evaporation throughput/scaling or resolve the known call-local allocation performance topic;
- create a second mass booking for actual transpiration or evaporation;
- select a universal time step, tolerance, application accuracy or groundwater-head budget;
- close complete T11 equation-to-test traceability;
- close T12 validation, sensitivity, uncertainty or application-specific fitness-for-purpose;
- promote any capability to `FULLY_TRACED`;
- claim readiness for formal Status A assessment, Status A compliance or Status AA compliance.

Mass conservation remains hard and unchanged.