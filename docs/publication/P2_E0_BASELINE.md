# Paper 2 E0 baseline

## Purpose

This document converts the currently admitted RossFast production envelope into the first explicit experimental baseline for Paper 2.

`E0` is not a claim of general solver equivalence. It is the smallest already-admitted condition set from which the scientific solver-admissibility study can expand.

Publication class: `PUB_P2_RESULT` for future solver-comparison outcomes, `PUB_SHARED_INFRASTRUCTURE` for the existing production seam itself.

## Canonical source of E0

Primary authority:

- `integration/f-ross/F-ROSS12_STATUS.json`
- production source PR #165
- post-admission governance reconciliation PR #168

F-ROSS12 is closed after production and postimage admission. The current status record states that the RossFast route is selected at the existing `soil_water_solver_t` request/result seam, retains the existing serialized production execution host, does not change the transaction ABI and does not silently fall back to Reference.

## E0 qualified envelope

The admitted restricted envelope currently contains:

```text
materials:
  B01
  B12
  O01
  O05
  O14
  O18

active_nodes: 16
cell_thickness_cm: 10.0
prescribed_flux_boundaries_only: true
distributed_source_sink: false
root_sink: false
groundwater_boundary: false
energy_or_soil_temperature: false
mixed_multiswap: false
```

This envelope is deliberately narrow and must not be generalized in the manuscript beyond the conditions actually tested.

## Existing production qualification

The admitted RossFast production route already proves several engineering properties that are prerequisites for Paper 2 but are not themselves the P2 novelty:

- actual RossFast execution inside the production transaction lifecycle;
- mass closure within the admitted engineering tolerance;
- no fallback to Reference HeadCalc on the RossFast route;
- propagation of the RossFast temporal certificate to the common trial outcome;
- material drift fails closed before commit;
- unsupported root physics fails closed before commit;
- Reference execution remains the default and remains available;
- no automatic solver fallback is permitted.

These properties establish experimental control. They do not establish scientific interchangeability with Reference.

## Existing exclusions

The current production record explicitly excludes:

- energy balance RossFast support;
- groundwater RossFast support;
- root or general source-sink RossFast support;
- heterogeneous-profile generalization;
- mixed Reference/RossFast MultiSWAP;
- automatic solver fallback;
- silent model selection.

Paper 2 must treat these as outside E0, not as untested members of the same admissible domain.

## E0 scientific question

Within the exact E0 physical and numerical envelope, how close are RossFast and the qualified Reference Richards solver in scientifically relevant state and flux trajectories across the already admitted materials and a deliberately varied set of initial and forcing conditions?

This question has not yet been answered by F-ROSS12. F-ROSS12 established route correctness, mass closure and fail-closed production admission. Paper 2 requires direct solver-to-solver scientific comparison.

## E0 independent variables

Without extending production capability, the first publication experiment should vary only dimensions already compatible with the admitted envelope.

Candidate dimensions:

- material: B01, B12, O01, O05, O14, O18;
- initial hydraulic state within physically valid ranges;
- magnitude and sign of prescribed top flux within the qualified boundary semantics;
- magnitude of prescribed bottom flux where permitted by the current adapter contract;
- interval duration and forcing sequence where the same temporal certificate remains valid;
- event sequencing, for example sustained flux versus pulses, provided no excluded boundary mode is introduced.

Do not vary node count, cell thickness, root sink, groundwater head boundary, heterogeneous profile or energy coupling in E0.

## E0 response variables

At minimum collect comparable Reference and RossFast values for:

- pressure head at all active nodes and selected summary depths;
- volumetric water content or an equivalent physically comparable state representation;
- profile water storage;
- integrated top flux;
- integrated bottom flux;
- storage change;
- water-balance residual;
- accepted interval endpoint;
- solver route/status;
- retries or internal substep counts when meaningfully comparable;
- wall or CPU cost only under a qualified benchmark environment.

Performance measurements must remain secondary until scientific discrepancy criteria are evaluated.

## E0 discrepancy metrics

The exact metrics should be frozen before broad execution. Candidate classes are:

### State discrepancy

```text
D_h = max or depth-weighted norm of head difference
D_theta = max or depth-weighted norm of water-content difference
D_storage = absolute and relative profile-storage difference
```

### Flux discrepancy

```text
D_qtop = difference in cumulative top flux
D_qbot = difference in cumulative bottom flux
```

### Conservation

```text
D_mass = difference in mass-balance residual and confirmation that each route independently closes within its own hard acceptance requirement
```

A small difference between two equally poor mass balances is not admissibility evidence. Each solver must first satisfy the independent conservation requirement.

## Tolerance rule

Paper 2 must not derive tolerances from the observed RossFast error distribution after seeing the result.

Preferred order:

1. define what magnitude of state or flux difference is scientifically immaterial for the intended application class;
2. where possible connect that choice to numerical precision, model discretization, measurement relevance or established SWAP qualification tolerances;
3. then evaluate E0.

If multiple application classes need materially different tolerances, report more than one admissibility level rather than selecting whichever one makes the solver pass.

## E0 experimental design

A suitable first design is a bounded space-filling or stratified experiment across the allowed material, initial-state and flux-forcing domain.

Minimum principles:

- include all six admitted materials;
- include wet, intermediate and dry initial states where physically supported;
- include low, moderate and strong prescribed forcing;
- include both monotonic and changing forcing sequences where permitted;
- predeclare cases or the sampling algorithm;
- retain failed and excluded cases in the evidence record;
- distinguish a solver-method limitation from an implementation defect.

## E0 expected output

The first publication-grade result should be a table or dataset such as:

```text
case_id
material
initial_state_descriptor
top_flux_descriptor
bottom_flux_descriptor
interval_descriptor
D_h
D_theta
D_storage
D_qtop
D_qbot
mass_reference
mass_rossfast
cost_reference
cost_rossfast
admissibility_verdict
failure_or_exclusion_reason
```

This dataset becomes the evidence base for deciding where E1 should probe next.

## Expansion logic

Do not expand all missing process physics at once.

Suggested staged expansion:

### E1 - hydraulic stress expansion

Still simple process physics, but target the known difficult regimes from the Richards-equation literature, including dry infiltration, strong pulses and near-saturation behaviour where supported by the existing solver formulation.

### E2 - discretization and profile expansion

Only after separate implementation qualification, test whether admissibility changes with node count, cell thickness and heterogeneous profiles.

### E3 - source and sink expansion

Introduce root uptake and other distributed source/sink terms one family at a time.

### E4 - groundwater boundary expansion

Test head-controlled or groundwater-interacting lower boundaries only after that production capability is independently admitted.

### E5 - realistic full-model trajectories

Use representative long-running SWAP cases after the controlled-domain mechanisms are understood.

These labels describe the publication experiment, not mandatory production workunit names.

## Decision rule for expansion

Expand the domain only when the current stage answers one of these questions:

- Where is the solver difference clearly below the declared scientific tolerance?
- Where does the difference approach or cross the tolerance?
- Which physical or numerical descriptor appears to control that transition?
- Is an apparent failure caused by the Ross method, the adapter implementation, or an unsupported physical contract?

The next experiment should refine a boundary or test a mechanism, not simply add more cases.

## Performance boundary

No publication speed claim should be made from normal CI runners or from single timings.

SWAP5 already contains a measurement programme that has demonstrated why shared-host noise can invalidate small performance claims. Paper 2 should reuse that discipline.

Required before a strong speed claim:

- qualified performance host or equivalent controlled environment;
- same surrounding execution context where possible;
- predeclared sampling protocol;
- uncertainty on runtime estimates;
- no averaging of scientifically failed cases into a beneficial speedup.

## E0 publication verdict

Current status: `READY_FOR_EXPERIMENT_DESIGN_NOT_READY_FOR_SCIENTIFIC_CLAIM`.

Engineering prerequisites for a controlled dual-solver experiment exist. Direct scientific Reference-versus-RossFast evidence over a designed E0 parameter space is still missing.

## Next publication workunit

Suggested identifier: `PUB-P2E01`.

Scope:

1. pin exact Reference and RossFast production heads and the current E0 contract;
2. define physically meaningful initial-state and prescribed-flux ranges for all six materials;
3. predeclare discrepancy metrics and tolerances;
4. generate the E0 experiment manifest without changing solver science;
5. execute the smallest pilot required to validate metric extraction;
6. only then run the full E0 design.

No extension to root, groundwater, energy, heterogeneous profiles or mixed MultiSWAP belongs in PUB-P2E01.
