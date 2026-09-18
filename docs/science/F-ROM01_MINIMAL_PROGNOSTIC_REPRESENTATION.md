# F-ROM01 Minimal Prognostic Representation

## Status

**PROPOSED RESEARCH WORKSTREAM. NOT STATUS-A. NOT A PRODUCTION SOLVER.**

F-ROM01 starts a clean-sheet scientific investigation of a reduced-order soil-water solver for SWAP5. It does not continue the historical MetaSWAP implementation and does not continue the prototype Sequential Steady State (SSS) software described in the 2026 SWAP4-MODFLOW6 coupling report.

The historical methods are knowledge sources only. No MetaSWAP or SSS source code, data structures, coupling ownership, or algorithmic control flow is inherited by default.

Full Richards remains the full-order scientific reference inside the admitted SWAP5 physics. RossFast remains a separate alternative numerical route for the high-dimensional soil-water problem. F-ROM01 asks whether a third solver family can reduce the prognostic dimension of that problem while preserving the SWAP process contract within an explicitly qualified domain.

## Scientific objective

Identify the smallest prognostic representation that retains enough information to reproduce the future soil-water response required by SWAP.

The research question is:

> What is the smallest dynamic representation, including explicit memory if needed, that makes the relevant future response of the SWAP Richards reference sufficiently determined within a declared physical and application domain?

The representation is not prescribed in advance. Candidate coordinates may include integrated storage, pressure information, internal flux information, profile moments, physically interpretable modal amplitudes, or compact memory coordinates.

The work unit must be allowed to conclude that no useful low-order representation exists.

## Non-goals

F-ROM01 does **not**:

- implement a production reduced-order solver;
- modify Richards, RossFast, production solver selection, transaction semantics, retry policy, timestep policy, or commit semantics;
- modify SWAP physics to make a reduced model easier to fit;
- couple the research model to MODFLOW6;
- tune against De Raam, Flevopolder, or another regional case;
- reproduce MetaSWAP source code or the existing SSS prototype;
- assume that a steady-state database is the final representation;
- assume that two, three, eighteen, or any other fixed number of states is correct;
- claim that Richards is hydrological truth outside the SWAP model. Richards is the full-order reference for this reduction study.

## Knowledge inherited, software not inherited

The 2026 SWAP4-MODFLOW6 report records three observations that motivate F-ROM01:

1. the SSS prototype is an alternative soil-water solution concept inside the SWAP framework rather than a separate application model;
2. simple SSS tests can agree well with the historical MetaSWAP behaviour while longer regional calculations show material GLG discrepancies and out-of-table states;
3. several pieces of dynamic MetaSWAP behaviour were deliberately not reproduced in the prototype, including non-steady capillary behaviour and treatment around hydraulic restrictions.

These observations are treated as evidence that quasi-equilibrium information alone may be insufficient to define the transient prognostic state. They are **not** treated as proof of which additional state or memory mechanism is required.

The historical MetaSWAP literature is used to identify hard physical regimes and prior modelling experience. It is not implementation authority for F-ROM01.

## Relationship to the existing SWAP5 architecture

F-ROM01 must preserve the current architectural boundary:

```text
forcing + accepted start state + boundary conditions + interval
                            |
                            v
                    soil-water solver
                            |
                            v
 candidate end state + interval fluxes + diagnostics
```

A future reduced-order solver, if admitted at all, must remain behind the explicit soil-water solver compatibility contract. It must not acquire hidden dependencies on MODFLOW6, iMOD Coupler, RossFast internals, reference-Richards workspace internals, or production transaction policy.

The research harness may observe full Richards state and diagnostics because its purpose is scientific system identification. That observation surface is test/research infrastructure, not a production API.

## Architecture invariants preserved during research

F-ROM01 is constrained by the existing SWAP5 invariants and verification principles:

- committed state remains authoritative;
- research experiments do not change production state ownership;
- mass conservation is non-negotiable;
- physical options remain separate from numerical execution policy;
- the full-accuracy reference path remains available;
- alternative/research solvers remain explicit and fail closed outside their qualified scope;
- evidence qualifies only the domain actually tested.

No production source mutation is required for ROM-1 unless a later work unit demonstrates that an observational seam is missing and a separate accepted interface decision authorizes it.

## Core decomposition

Let the full Richards state be

```text
x(t) = {h(z,t), theta(z,t), ...}
```

and let a candidate reduced representation be

```text
z(t) = P[x(t)] .
```

F-ROM01 tests whether there exists a small `z` for which relevant future outputs are sufficiently determined under the same future forcing and boundary conditions.

The study separates three questions that must not be conflated:

1. **State sufficiency**: what information must be carried from one interval to the next?
2. **Closure**: given that information, how should the state evolve?
3. **Reconstruction**: what vertical hydraulic information must be reconstructed for other SWAP processes?

F-ROM01 addresses the first question and only the diagnostic prerequisites of the third. Dynamic closure is deferred to a successor work unit.

## Candidate information families

No family is privileged a priori. The first tournament includes at least:

### Storage coordinates

Examples:

```text
Z1  = (S_total)
Z2  = (S_root, S_subsoil)
Z3S = (S_root, S_capillary, S_deep)
```

### Hydraulic coordinates

Examples:

```text
Z3Q = (S_root, S_subsoil, q_internal)
Z3H = (S_root, S_subsoil, h_summary)
```

### Profile moments

Examples:

```text
M1 = integral(z * theta(z) dz)
M2 = integral(z^2 * theta(z) dz)
```

used in candidates such as

```text
Z3M = (S_root, S_subsoil, M1)
```

### Memory coordinates

A memory coordinate is admitted as a candidate only when current-state coordinates leave reproducible history-dependent ambiguity. It may be represented by one or more compact relaxation states.

The work unit does not assume a fractional-memory formulation or any particular historical model. Long-history descriptors may be used as research upper benchmarks for information content, not as production commitments.

### Quasi-equilibrium plus transient deviations

A later candidate may represent

```text
x(z,t) = x_eq(z; xi(t)) + sum_i a_i(t) phi_i(z; xi)
```

where `x_eq` is a quasi-equilibrium reference profile and `a_i` are transient deviation amplitudes.

This formulation is a hypothesis. F-ROM01 must demonstrate whether such deviations are low-dimensional and relevant to SWAP outputs before they become solver design.

## Reference experiment surface

F-ROM01 begins with one-column Richards experiments only.

Excluded from the first identification stage:

- MODFLOW6;
- MultiSWAP scaling;
- regional tuning;
- dynamic crop phenology;
- new process physics.

The first material set should be small and deliberately contrasting:

1. a relatively homogeneous, well-drained material;
2. a material with stronger capillary behaviour;
3. a materially layered or hydraulically resistant profile when a qualified fixture is available.

Use existing qualified SWAP material/fixture authority where possible. Do not invent a new soil merely to make the research convenient.

## Experiment families

### E1: Equilibrium and near-equilibrium characterization

Purpose: identify the quasi-equilibrium surface and verify that candidate coordinates are not already ambiguous at equilibrium.

### E2: Pulse and step response

Apply bounded perturbations in:

- top flux;
- evaporative/root sink demand where the simplified process harness permits it;
- lower boundary flux or head through an already qualified boundary route.

Measure propagation, storage redistribution, bottom response, recovery, and regime change.

### E3: Bidirectional boundary response

Exercise both drainage and capillary directions. A reduced model that represents only downward recharge is not a SWAP soil-water solver.

### E4: Regime reversal

Construct downward-to-upward and upward-to-downward flow transitions. These are explicit adversarial cases because quasi-steady approximations can hide directional memory.

### E5: History collision

Generate different Richards histories that map to nearly the same candidate reduced state.

For a projection `P`, find pairs

```text
P(x_A) ~= P(x_B)
```

while the full profiles remain materially different.

Continue both from that point with identical future forcing and boundaries. Measure future divergence.

If relevant outputs diverge, the candidate state is insufficient.

### E6: Frequency response

Around selected stable operating points, apply small periodic perturbations over a preregistered frequency range.

Measure gain and phase for relevant outputs. Fit increasing low dynamic orders only as diagnostic models. The objective is to determine how many dynamically relevant modes are visible, not to declare a production transfer function.

### E7: Process sufficiency

A candidate state that predicts bottom flux but cannot distinguish soil-water states required by root uptake, surface evaporation, oxygen stress, or another admitted SWAP process is not sufficient for that capability.

F-ROM01 therefore distinguishes:

```text
dynamic sufficiency
process sufficiency
reconstruction sufficiency
```

A candidate may qualify for a narrower capability envelope without qualifying for full SWAP process support.

## Required observations

Each full-order reference trajectory should preserve enough information to compute, where available and scientifically meaningful:

- pressure head profile;
- water-content profile;
- vertical flux information;
- total storage;
- root-zone storage under the frozen experimental root-zone definition;
- accepted top and bottom exchange;
- mass-balance residual;
- boundary values and forcing identity;
- route/status diagnostics;
- time and continuation identity.

Additional process outputs are added only when their owning process is deliberately included in a later experiment stage.

## Hard conservation rule

Reduced coordinates may approximate hydraulic closure, but accepted research comparisons may not conceal mass imbalance.

Where storage coordinates are used, their accounting must be traceable to the full-order accepted state and flux ledger.

Any future ROM must preserve:

```text
change in total storage = integrated external inflow - integrated external outflow + qualified sources/sinks
```

within the applicable SWAP5 hard accounting contract.

A correction term that merely hides a structural ROM mass error is not an acceptable closure strategy.

## Collision metrics

Collision analysis must separate at least:

- state-space proximity in the candidate representation;
- full-profile dissimilarity;
- future bottom-flux divergence;
- future storage divergence;
- timing/phase divergence;
- regime-direction disagreement;
- process-output divergence when that process is in scope.

A single annual RMSE is not sufficient evidence.

The analysis should report divergence at more than one continuation horizon. Initial candidates are one short, one intermediate, and one long horizon determined by the actual experimental timestep and stable runtime envelope. Exact horizons are preregistered before result inspection.

## Dynamic-order diagnostics

F-ROM01 uses two independent diagnostics:

1. profile/modal dimensionality, used only to characterize spatial representation;
2. input-output dynamic order, inferred from pulse, step, and frequency response.

A profile mode with small variance may still be important when it materially controls bottom flux, stress, or a regime transition. Variance explained is therefore not an admission criterion by itself.

## Quasi-equilibrium manifold analysis

If a usable quasi-equilibrium manifold exists, F-ROM01 may characterize

```text
x_eq = R_eq(xi, parameters, boundaries)
```

and the transient deviation

```text
delta_x = x - x_eq .
```

The analysis then asks:

- how large can `delta_x` become;
- which forcing regimes create it;
- whether a small number of deviation shapes explain the output-relevant transient information;
- whether those deviations relax on a small number of dominant timescales.

This does not make steady-state lookup the solver.

## Falsification-first admission of complexity

Complexity is added only to resolve demonstrated information loss.

A new coordinate is admissible for investigation only if:

1. a simpler candidate has a reproducible collision or process-sufficiency failure;
2. the added coordinate has an interpretable relation to the missing information;
3. held-out continuation tests show that it materially reduces that failure;
4. the improvement is not merely in-sample curve fitting.

This rule applies equally to extra spatial compartments, hydraulic coordinates, and memory states.

## Initial hypotheses

These are hypotheses, not requirements:

**H1**: Relevant one-column Richards input-output dynamics are low-dimensional over a practically useful SWAP domain.

**H2**: A small set of physically interpretable prognostic coordinates can capture the dominant dynamic information.

**H3**: If current-state coordinates are insufficient, a small number of explicit memory/deviation coordinates can recover most of the missing information.

**H4**: Required model order is small enough over a useful material/regime envelope to justify a third solver family next to Reference Richards and RossFast.

Every hypothesis may fail.

## ROM-1 deliverables

F-ROM01 produces research infrastructure and evidence, not a production solver.

Required deliverables:

1. a frozen experiment contract;
2. a Richards response-harness using an already qualified full-order route;
3. a versioned response-data schema;
4. deterministic state projection functions;
5. a collision-pair generator;
6. a continuation/replay runner;
7. dynamic-order diagnostics;
8. a manifold/deviation diagnostic;
9. a result record containing model-order-versus-error evidence;
10. a go/no-go scientific decision for ROM-2 closure identification.

## ROM-1 qualification ladder

### Q0 Authority and non-mutation

- exact canonical baseline pinned;
- production/reference source delta is empty;
- full-order route and boundary route are identified;
- research outputs cannot commit production state.

### Q1 Harness reproducibility

- identical input produces identical accepted reference trajectory under the supported deterministic envelope;
- O0/O2 comparison is recorded where applicable;
- all run metadata needed for replay are preserved.

### Q2 Conservation and observation

- mass accounting is present and valid for every retained trajectory;
- all required observations are finite and dimensionally identified;
- rejected/failed reference cases are classified, not silently discarded.

### Q3 Collision construction

- at least one deterministic collision-search method is frozen before candidate comparison;
- train/discovery and held-out continuation cases are separated;
- proximity thresholds are preregistered.

### Q4 Minimum-representation evidence

- simpler candidates are falsified or retained by held-out continuation evidence;
- additional coordinates are justified by a named failure mode;
- output-specific sufficiency is reported rather than collapsed into one score.

### Q5 Dynamic-order evidence

- pulse/step and frequency diagnostics give a bounded estimate of relevant local dynamic order across the first material/regime set;
- modal variance is not substituted for output relevance.

### Q6 ROM-2 decision

One of:

```text
PROCEED_TO_ROM2
PROCEED_WITH_RESTRICTED_CAPABILITY
EXPAND_ROM1_EVIDENCE
NO_GO_LOW_ORDER_REDUCTION
```

No production admission follows directly from any ROM-1 decision.

## First implementation slice

The first implementation slice is deliberately narrow:

1. reuse the existing typed full-order Reference Richards solver seam;
2. introduce no production source changes;
3. add a research-only experiment driver that can:
   - construct a known material and initial state;
   - run a deterministic sequence of short accepted reference solves;
   - vary top and bottom forcing through already qualified request fields;
   - emit a stable machine-readable trajectory;
4. add a small analysis script for deterministic projections and collision-distance calculation;
5. freeze the experiment and output schema before broad sweeps.

The first slice is complete when the harness can produce and replay two distinct histories ending at deliberately similar simple storage coordinates and can continue both under the same forcing without production code changes.

## Dependency surface

Initial dependency surface:

- `src/solver/mod_soil_water_solver_contract.f90`;
- `src/adapter/mod_reference_richards_legacy_binding.f90`;
- reference-Richards state/workspace and constitutive providers used by the selected harness;
- the selected already qualified top and bottom boundary provider paths;
- mass-accounting fields of the typed solver result;
- research/test driver and analysis scripts introduced by F-ROM01.

RossFast is not a dependency for ROM-1 scientific identification. It may later be run on identical experiments as an independent full-order numerical comparator.

MODFLOW6 and groundwater coupling are not dependencies of ROM-1.

## Stop conditions

Stop and record a blocked/no-go result if:

- the full-order reference cannot expose the observations required for state identification without production semantic changes;
- the selected boundary route cannot exercise the needed bidirectional reference experiments;
- mass accounting is incomplete for the trajectories being compared;
- candidate low-order representations require so many states/memory coordinates that the research premise no longer offers meaningful reduction;
- scientific conclusions would require tuning on regional application results before the reduced dynamics are identified.

## Next work unit

If F-ROM01 supports low-order reduction, ROM-2 will identify and compare dynamic closures **at fixed accepted prognostic state definition**.

ROM-2 must not reopen state dimension and closure simultaneously unless ROM-1 evidence explicitly leaves that question unresolved.
