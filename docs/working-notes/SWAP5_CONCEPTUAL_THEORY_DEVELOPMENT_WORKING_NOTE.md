# SWAP5 conceptual theory development working note

> **Status: NON-AUTHORITATIVE WORKING NOTE**
>
> This file preserves conceptual reasoning developed during review of the SWAP5 theoretical framework. It is not a scientific authority, release authority, Status-A assessment, admission decision, or replacement for any qualified F-DOC/F-CI/F-GC authority.
>
> **Controlling authority remains F-DOC16** for `SCI-FOUND-01` at the conceptual-foundation level. Where this note differs from a qualified authority, the qualified authority controls.

## 1. Purpose

The immediate motivation was a documentation question: the historical SWAP manual moves relatively quickly into the represented system and process theory, while the conceptual path from the real physical system to the selected model abstraction can be made clearer.

The useful high-level chain is:

`physical world -> model purpose -> horizontal support -> system boundary -> physical state -> conservation -> interfaces -> process closures -> numerical formulation -> software realization -> qualification`

The main methodological rule is that the physical conceptualisation determines the formal model. The formal model then constrains software contracts. Architecture must be compatible with the science, but implementation structure must not silently define the science.

This note preserves additional reasoning around that chain without creating a second SWAP5 conceptual authority.

## 2. Controlling repository context at preservation time

This note was created from `integration/f-ci-canonical@eba90d79010b095b6556e93bd8b77a8c28d25560`.

Relevant qualified authorities checked during the discussion include:

- F-DOC16, `b0bdf08b5c38771a4ee22c93ed0949f408ceeb2b`, which closes `SCI-FOUND-01` at conceptual-foundation level;
- F-DOC15 R1, `75df47fb5cf6188535a9705165785fc8744b2cb2`, which reconciles Status-A readiness after F-DOC16 and F-DOC18;
- F-DOC11, which decomposes the remaining controlled theory/formal gap and identifies `RB1-CORE-MASS` and `RB1-ROOT-PARALLEL` as the remaining `HYBRID` T0-T7 capabilities.

This note does not promote those branch heads into canonical release authority and does not change their scope.

## 3. What is already covered by F-DOC16

F-DOC16 already establishes much of the conceptual foundation that motivated this discussion, including:

- the local soil-plant-atmosphere system represented by SWAP;
- modelling purpose;
- the representative one-dimensional column;
- defined horizontal support and conditions for 1D admissibility;
- upper, lateral and bottom system boundaries;
- generic time semantics;
- process-disposition categories;
- standalone, MultiSWAP, tile, direct-groundwater and deep-vadose conceptual composition;
- the nonclaim that bottom flux is universally groundwater recharge;
- the nonclaim that multiple SWAP columns form a horizontally coupled soil-flow model;
- hard mass conservation and the separation of physical options from numerical policy.

Therefore the material below should not be turned into a duplicate general scientific authority merely because it is useful explanatory material.

## 4. Additional conceptual synthesis worth preserving

### 4.1 Three levels of system description

It is useful to distinguish three levels explicitly:

1. **Real physical system**: atmosphere, vegetation, land surface, soil, groundwater, management and spatial heterogeneity.
2. **SWAP column**: a selected one-dimensional model representation over a defined horizontal support, with explicit vertical state and selected directly coupled processes.
3. **Composed model system**: one or more SWAP columns plus possible external components such as groundwater, deep-vadose transfer, surface-water routing or regional runtime/coupling logic.

The core idea is that SWAP need not represent the entire hydrological system. It must represent a well-defined part with explicit exchange contracts to what lies outside.

### 4.2 Horizontal support and nonlinearity

A SWAP column should not be interpreted as an abstract point by default, nor as one MODFLOW cell by default. It represents a defined horizontal support for which one column representation is defensible for the intended application.

For nonlinear processes, parameter averaging and response averaging are not generally equivalent:

`F(mean(p)) != mean(F(p))`.

This matters for hydraulic conductivity, runoff thresholds, root stress, drainage, capillary rise and other nonlinear responses. Therefore heterogeneity can require multiple representative supports/tiles rather than one averaged parameter set.

A useful conceptual splitting criterion is:

> Two parts of a larger area require separate column representations when differences in properties, forcing, boundaries or process topology produce materially different responses for the intended application.

This is application- and tolerance-dependent, not a universal soil-class rule.

## 5. Physical state, storage and conservation

This is the main additional line developed in the discussion and may be useful for future `RB1-CORE-MASS` work.

### 5.1 Physical state

A robust definition is:

> The committed physical state is the minimal set of model variables that, together with model configuration, parameters and future forcing, is sufficient to continue the represented physical evolution without requiring hidden knowledge of the previous numerical trajectory.

This separates physical state from:

- immutable or slowly changing parameters/properties;
- forcing and boundary information;
- derived diagnostics;
- reporting accumulators;
- numerical scratch such as Newton iterates, residual vectors, Jacobians and factorisations.

A useful practical criterion is:

> A variable belongs to physical state when forgetting it changes future physical evolution under otherwise identical future inputs.

This is especially important for constitutive memory such as hysteresis.

### 5.2 State is not the same as storage

A physical state variable need not itself be a conserved store. Pressure head can describe hydraulic state while water storage is obtained through a constitutive relation.

Conceptually:

`S_k = S_k(x,p)`

and total water storage is the sum of all active water-bearing reservoirs and phases that are actually represented.

Examples may include soil liquid water, surface storage, interception, snow and optional preferential-flow storage. Whether vapour storage or plant water storage is explicitly represented must follow the admitted physical formulation rather than be assumed here.

### 5.3 Constitutive memory

The common shorthand `theta = theta(h)` is not universal. With hysteresis or other memory-bearing closures, a more general form is:

`theta = theta(h, xi_memory, p)`.

Such memory belongs to the physical state if it affects future evolution.

### 5.4 Internal versus external transfers

For a chosen system boundary, an internal transfer must cancel from the balance of the enclosing system.

Examples include surface-to-soil infiltration when both surface storage and soil are inside the SWAP system, or matrix-macropore exchange when both domains are internal.

External exchanges remain in the total system balance, for example precipitation, evapotranspiration, runoff, drainage to an external system and bottom exchange.

The same named process can be internal at one system-composition level and external at another. `Internal` versus `external` is therefore a property of the selected system boundary, not an intrinsic property of a process name.

### 5.5 Conservation composition law

For component `i`:

`Delta S_i = sum(Q_external,i) + sum(Q_j->i) - sum(Q_i->j)`.

When component balances are summed, every internal transfer should appear twice with equal magnitude and opposite sign, and therefore cancel.

This provides a general conservation rule for surface-soil, matrix-macropore, SWAP-deep-vadose, SWAP-groundwater and future component interfaces.

A particularly important distinction is:

- a numerical component balance can close within a qualified residual tolerance;
- the same accepted transferred amount should not be independently booked differently by donor and receiver components.

For a shared accepted transfer, the preferred composition rule is exact opposite booking of the same transferred quantity.

### 5.6 Trial state versus committed history

The discussion also clarified a physically useful interpretation of transactional stepping. A trial endpoint is a possible continuation of physical history, not physical history itself. A rejected trial must not alter committed state or permanently booked transferred quantities.

This is primarily architecture/numerics territory, not a reason to expand the conceptual foundation authority. It is nevertheless directly relevant to accepted-only mass accounting in `RB1-CORE-MASS`.

## 6. Time, forcing and events

The following distinctions are useful explanatory material beyond the simple statement that time is generic:

- physical state time;
- forcing support interval;
- solver step;
- event time;
- coupling window;
- reporting interval.

They need not coincide.

A state belongs to a time point. A flux rate belongs to time, while the transferred amount over an interval is:

`Q_[t0,t1] = integral(q(t) dt)`.

Forcing therefore requires temporal semantics. A value such as `10 mm` is incomplete without knowing whether it is an interval total, a rate, a pulse or another temporal representation. Under nonlinear processes, two forcing trajectories with the same integrated total need not produce the same physical state.

A useful event definition is a time point at which the physical/mathematical definition of forcing, properties, boundary conditions, topology or state transition changes discontinuously enough to require explicit handling.

Not every input-record boundary must become a mandatory solver boundary.

Calendar boundaries are not fundamental kernel boundaries, although individual process formulations may legitimately require calendar events or daily closures. Such requirements should be explicit properties of those processes rather than hidden global assumptions.

Useful qualification concepts include interval consistency, temporal additivity, restart sufficiency and reporting independence.

## 7. Process composition and interfaces

The discussion separated a physical process/interface from a software module/function call.

A physical interface represents a shared state dependency or transfer across a system boundary. Software ownership can be chosen later.

Three interaction types are conceptually useful:

1. state dependency without conserved transfer;
2. internal conserved transfer;
3. external exchange across the selected system boundary.

Execution order is not automatically physical causality. Sequential software evaluation can be a numerical decomposition of physically coupled processes. Stronger interaction may require iteration, but that belongs to numerical formulation and qualification.

A process should request physically meaningful hydraulic information, not solver-internal arrays. This supports alternative soil-water solvers behind a common physical interface and protects other process modules from HeadCalc-specific internals.

## 8. MultiSWAP and spatial/system composition

Some additional distinctions developed here are useful but should remain separate from the basic column foundation.

A physical tile/support is not the same as an execution batch or model template.

- **Tile/support**: physical representation of a land-surface fraction or response unit.
- **Template/execution class**: runtime grouping for efficient calculation.

Compatible columns may share an execution template while retaining distinct parameters, forcing and state. Conversely, a numerically difficult column may move to a different numerical execution class without changing its physical configuration.

For fixed, disjoint area fractions `f_i` with a common reference area:

`sum(f_i) = 1`

and an area-normalised conserved flux can be aggregated as:

`q_agg = sum(f_i * q_i)`.

Intensive states and nonlinear diagnostics do not automatically admit the same averaging rule.

Multiple SWAP columns do not create horizontal exchange between those columns. Any runoff routing, groundwater-mediated interaction or other horizontal exchange requires an explicit external composition component.

Dynamic tile fractions require a separate conservative state-remapping theory and should not be assumed covered by the fixed-fraction formulation.

## 9. Groundwater and deep-vadose composition

The bottom of the SWAP column is best treated as a physical interface first, not as a universal groundwater-recharge location.

Three distinct compositions remain useful:

1. local prescribed or analytical bottom boundary;
2. explicit external deep-vadose transfer/storage component;
3. direct dynamic groundwater coupling.

For direct coupling, the physical target remains head compatibility on a common interface within a qualified tolerance and equal/opposite water transfer across that interface.

Two unresolved theoretical details deserve continued attention in specialised coupling work:

- the spatial semantics/mapping between a SWAP bottom-interface head and a groundwater-model state such as a MODFLOW cell or layer head;
- the temporal support on which head compatibility is enforced, for example endpoint, internal coupling nodes or another admitted trajectory relation.

Flux aggregation and head distribution are separate operations and should not be conflated.

Response tangents such as `dH/dQ` or `dQ/dH` are useful numerical/coupling outputs. They are not new physics and should live in coupling/numerical authorities rather than the general conceptual foundation.

## 10. Reconciliation items to verify before any future canonical theory publication

The discussion identified several items that should not be silently normalised without source-bound review:

1. **Single-phase wording versus vapour transport.** Clarify whether the historical `single-phase` assumption means no independently solved gas phase, while vapour flux may still appear in an admitted closure, and whether vapour storage is neglected or represented.
2. **Isothermal wording versus soil-temperature physics.** Determine the exact scope of any isothermal assumption in the hydraulic derivation versus optional temperature-dependent processes or soil-heat modules.
3. **Hysteresis and restart state.** Ensure all constitutive memory needed for future evolution is represented in restart/committed state.
4. **Plant water storage.** Verify from authoritative theory whether the admitted SWAP formulation equates integrated root uptake to actual transpiration without an explicit plant-water buffer, and do not generalise that as a universal physical law.
5. **Stress combination.** Treat multiplicative or other stress-factor combinations as SWAP-specific closures, not universal physics.
6. **Bottom flux versus recharge.** Preserve the explicit non-identity already captured by F-DOC16.
7. **Daily process closures.** Distinguish legitimate process-specific calendar semantics from hidden global daily kernel assumptions.
8. **Equation/documentation defects.** Any suspected typo or ambiguity in historical/online documentation must be checked against authoritative source and implementation before correction is promoted.
9. **Groundwater interface geometry.** Define the common physical interface before asserting head equality between discretisations.
10. **Deep-vadose/direct transition.** Require both mass conservation and physically admissible state mapping; conservation alone is insufficient.

## 11. Documentation-structure recommendation

If a future public/manual rewrite is undertaken, the conceptual introduction can remain compact. A reasonable four-part explanatory structure is:

1. modelling purpose, system boundary and applicability;
2. spatial abstraction and representative SWAP column;
3. physical state, storage, conservation and time;
4. process interaction and relation to established SWAP process theory.

This should point into the existing qualified process theory rather than re-derive Richards flow, ET, crop, drainage and other process equations.

Specialised material should remain separate:

- spatial/system composition and MultiSWAP;
- groundwater/deep-vadose coupling;
- numerical coupling methods;
- runtime/data ownership/performance architecture;
- qualification and validation evidence.

The goal is to explain what kind of model SWAP is without turning the conceptual introduction into a description of the entire SWAP5 software platform.

## 12. Status-A relevance after F-DOC15 R1

This working note does not itself close a Status-A gap.

F-DOC15 R1 shows that `SCI-FOUND-01` and the three `PHYSICAL_SCIENCE` T0-T7 capabilities are already closed. The remaining relevant T0-T7 hybrid work is exactly:

- `RB1-CORE-MASS`;
- `RB1-ROOT-PARALLEL`.

Potential reuse from this note should therefore be bounded:

- the state/storage/conservation and accepted-only accounting reasoning may support future `RB1-CORE-MASS` authority;
- the physical-versus-execution separation may support `RB1-ROOT-PARALLEL`, while root-process science should be inherited from its existing qualified authority rather than rewritten;
- application-envelope, validation, sensitivity, uncertainty, parameter/provenance and user-guidance gaps remain separate Status-A work and cannot be closed by further conceptual prose.

## 13. Hard nonclaims

This note does **not**:

- reopen or replace F-DOC16;
- create a new scientific authority;
- change RB1 or current-canonical production source;
- change physics, numerical policy, solver tolerances or acceptance criteria;
- claim Status A or Status AA readiness/certification;
- count conceptual admissibility as validation;
- convert MultiSWAP functional compatibility into a performance/scaling claim;
- admit production groundwater predictor-corrector execution or a MODFLOW adapter;
- define a universal groundwater-head tolerance, application error budget or tile-splitting threshold.

Its sole purpose is preservation of useful conceptual reasoning and future traceability without creating authority competition.