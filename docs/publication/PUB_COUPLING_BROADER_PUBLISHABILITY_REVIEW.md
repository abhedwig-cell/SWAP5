# PUB-GC/PUB-RC broader publishability review

## Status

Review date: 2026-09-18.

Conclusion:

**A peer-reviewed paper centered on the SWAP5-MODFLOW6 coupling method is scientifically plausible even if the constituent numerical techniques are not individually novel.**

The strongest publication route is not a claim of a new Newton, quasi-Newton, rollback, multirate or derivative method. The stronger route is a hydrological model-coupling method/development paper that combines these established ideas into a rigorously defined, reproducible and quantitatively evaluated coupling contract.

Strategic consequence:

- manuscript priority: **HIGH**;
- claim of fundamental numerical novelty: **LOW / NOT SUPPORTED**;
- claim of hydrological/model-coupling innovation through integration and operationalization: **PLAUSIBLE, REQUIRES EVIDENCE**;
- ACCELERATE should be treated as an important experiment within the central coupling paper unless its information-value result later becomes independently strong enough to justify separation.

## Why the broader paper is publishable in principle

Recent and established literature shows that coupling publications need not introduce a new mathematical solver to be publishable.

### SWAT+MODFLOW, GMD 2025

Bailey et al. (2025) published a new coupling of two existing model families, SWAT+ and MODFLOW. Peer review explicitly recognized that the model consists of existing components that were augmented and linked, yet judged that the combined development contained enough new material for publication in GMD.

The paper's contribution is primarily:

- a new integrated hydrologic modelling capability;
- explicit mapping and exchange of hydrologic quantities;
- new managed-water linkages;
- reproducible source code, tutorial and cases;
- hydrologic demonstration and water-balance analysis.

This is strong evidence that "existing components + a scientifically meaningful, reusable and well-documented new coupling" can constitute a valid model-development paper.

Reference:
Bailey, R. T., Abbas, S., Arnold, J. G., & White, M. J. (2025). SWAT+MODFLOW: a new hydrologic model for simulating surface-subsurface flow in managed watersheds. Geoscientific Model Development, 18, 5681-5697. https://doi.org/10.5194/gmd-18-5681-2025

### HydroCouple, Environmental Modelling & Software 2018

Buahin & Horsburgh (2018) built directly on OpenMI rather than inventing component modelling. Their contribution was to identify missing capabilities and define new interfaces and infrastructure needed for integrated water-resources modelling.

This supports a publication claim based on solving a concrete integration problem through a purposeful combination and extension of existing ideas, rather than requiring mathematical novelty.

Reference:
Buahin, C. A., & Horsburgh, J. S. (2018). Advancing the Open Modeling Interface (OpenMI) for integrated water resources modeling. Environmental Modelling & Software, 108, 133-153. https://doi.org/10.1016/j.envsoft.2018.07.015

### MODFLOW API, Environmental Modelling & Software 2022

Hughes et al. (2022) introduced the MODFLOW API/XMI to allow tight external coupling without modifying MODFLOW source code. The paper is architectural and interoperability-oriented rather than a new groundwater-flow equation.

It explicitly addresses the problem that older single-program MODFLOW couplings can become stale as component codes evolve. This is directly relevant to the SWAP5 design goal that SWAP and MODFLOW retain their own implementation and lifecycle.

Reference:
Hughes, J. D., Russcher, M. J., Langevin, C. D., Morway, E. D., & McDonald, R. R. (2022). The MODFLOW Application Programming Interface for simulation control and software interoperability. Environmental Modelling & Software, 148, 105257. https://doi.org/10.1016/j.envsoft.2021.105257

### ParFlow-LIS, HESS 2025

Abbaszadeh et al. (2025) published a newly coupled ParFlow-LIS/Noah-MP modelling framework. The peer-review record is particularly instructive. Reviewers requested a much clearer novelty statement and full description of the coupling, because the value of merely connecting two models was not self-evident. After the coupling details, motivation and scientific capabilities were clarified, the paper was accepted.

This is a close analogue for the publication risk of SWAP5-MODFLOW6: the coupling architecture cannot remain implementation detail or be delegated to another document. The paper itself must explain exactly what the coupling does, why existing approaches are insufficient for the intended use, and what new capability results.

Reference:
Abbaszadeh, P. et al. (2025). Coupling the ParFlow Integrated Hydrology Model within the NASA Land Information System: a case study over the Upper Colorado River Basin. Hydrology and Earth System Sciences, 29, 5429-5452. https://doi.org/10.5194/hess-29-5429-2025

### ParFlow-land coupling review/development, GMD 2026

Yang et al. (2026) is also informative. A reviewer considered parts of the recoupling incremental and argued that a high-level sustainable framework was insufficient. The reviewer specifically wanted the implementation of sustainable coupling in enough detail to benefit the wider community. The editor ultimately accepted the revised paper after improved framing, literature positioning and coupling detail.

This indicates that coupling architecture can itself have publication merit, but only when the paper makes the implementation and transferable lessons concrete rather than presenting architecture as aspiration.

Reference:
Yang, C. et al. (2026). 20 years of trials and insights: bridging legacy and next generation in ParFlow and Land Surface Model Coupling. Geoscientific Model Development, 19, 1849-1866. https://doi.org/10.5194/gmd-19-1849-2026

## What is not new

The broader framing does not revive novelty claims already falsified in the ACCELERATE review.

The following remain prior art:

- component interfaces and plug-and-play environmental modelling: OpenMI, BMI, HydroCouple;
- external MODFLOW control and tight coupling: MODFLOW API/XMI;
- checkpoint/restore and repeated integration of a coupling window: FMI and preCICE;
- implicit partitioned coupling with solver rollback: preCICE;
- component-specific/subcycled time stepping: OpenMI/BMI practice, preCICE, waveform methods;
- black-box and derivative-informed coupling acceleration: IQN/Anderson, interface-Jacobian co-simulation, FMI;
- hydrological iterative feedback coupling: HYDRUS-MODFLOW and MetaSWAP/MODFLOW;
- dynamic storage/response coefficients: MetaSWAP and transient specific-yield literature;
- hydrological coupling-convergence regime analysis: Schüller et al. (2025).

Therefore the manuscript must not claim that any one of these ingredients is invented by SWAP5.

## Candidate innovation bundle

The potential innovation is the combination and formalization of the following as one hydrological coupling method.

### 1. Solver-autonomous coupling

SWAP5 and MODFLOW6 retain ownership of:

- state;
- numerical solution;
- internal adaptive time stepping;
- retry logic;
- process physics.

The external coupling layer owns only the coupled iteration and exchange contract.

This is not unique in generic multiphysics, but is a deliberate response to the maintainability problem of embedded/single-program hydrologic couplings.

### 2. Hydrologically typed interface semantics

The interface does not exchange anonymous numerical arrays. It distinguishes:

- hydraulic head at a fixed coupling plane;
- q_bot, the native SWAP lower-boundary flux;
- q_u, the MODFLOW-facing hydrologic exchange;
- storage/response information;
- whole-window transferred water amount;
- datum, area, units and sign convention;
- managed groundwater abstraction/irrigation from natural exchange.

This semantic precision is a candidate transferable contribution because incorrect aliasing of hydrological quantities can produce apparently functioning but physically inconsistent couplings.

### 3. Finite-window response semantics

The coupling object is the response of a complete internally integrated vadose-zone model over a coupling window, not merely an instantaneous constitutive derivative.

The component can substep internally and expose only the hydrologically relevant whole-window result and optional response information.

### 4. Rollback-safe hydrological strong coupling

Generic rollback/checkpoint coupling exists in FMI and preCICE. The candidate contribution is its hydrological specialization:

- every predictor, perturbation and corrector is replayed from one accepted origin;
- trial states are non-authoritative;
- convergence decides which participant states become accepted;
- rejected iterations cannot contaminate later hydrological state.

### 5. Exactly-once conservative exchange publication

Only the accepted coupled candidate contributes authoritative interface mass.

The central invariant is not simply numerical mass conservation during one solver call but conservation across:

- predictor attempts;
- perturbation trials;
- coupled correctors;
- retry;
- rollback;
- restart;
- final commit.

OpenMI literature has shown that temporal coupling and interpolation can create mass-balance error, so explicit coupling-accounting semantics are scientifically relevant.

### 6. Optional response exposure without solver exposure

SWAP5 may expose a compact finite-window response quantity without exporting the full Richards Jacobian or internal time-integration machinery.

The generic concept is prior art. The scientific question is whether a hydrologically meaningful compact response provides useful and reproducible acceleration in this coupling.

### 7. Scalable mapping

The same contract should support one-to-one and eventually multiple land-surface units coupled to a groundwater discretization without changing the scientific ownership model.

The physical validity of N:1 aggregation belongs to PUB-SG / SCALE, not to this paper.

## Cross-community gap

The strongest candidate gap is not a missing numerical technique. It is a gap between two literature communities.

### Environmental/hydrological coupling frameworks

OpenMI, BMI, HydroCouple, SWAT+MODFLOW and similar systems emphasize:

- interoperability;
- spatiotemporal mapping;
- exchange-variable definitions;
- ease of model integration;
- domain applications.

Hydrologic studies have also demonstrated feedback loops, time-step misalignment and mass-balance problems.

### Generic partitioned multiphysics/co-simulation

FMI, preCICE and interface quasi-Newton literature emphasize:

- implicit iterative coupling;
- checkpoint/rollback;
- convergence acceleration;
- multirate integration;
- waveform coupling;
- generic interface algorithms.

### Candidate SWAP5-MODFLOW6 contribution

The paper can be valuable if it demonstrates a coupling contract that brings the numerical discipline of modern partitioned co-simulation into a physically typed, conservative vadose-zone/groundwater coupling without transferring ownership of either component's numerical solution to the coupler.

This is best framed as **hydrologically accountable partitioned co-simulation**, not as invention of the generic constituent techniques.

## Publication forms and journal fit

### Geoscientific Model Development

**Strongest current fit.**

GMD explicitly accepts model components, modules, coupling frameworks and other software tools with geoscientific applications, and development/technical papers on numerical integration, performance and reproducibility.

A SWAP5-MODFLOW6 paper can therefore be publishable even if the acceleration result is modest, provided:

- the model/coupling version is identifiable;
- the scientific and numerical coupling method is fully described;
- source code and configuration are archived;
- standard/synthetic and realistic cases are evaluated;
- limitations are explicit.

### Environmental Modelling & Software

**Plausible, potentially stronger but with a higher generalization burden.**

EMS explicitly seeks generic frameworks, model integration, software evaluation and environmental software, but asks for generalizable insight and quantitative evidence.

For EMS, a paper limited to "SWAP5 coupled to MODFLOW6" is weaker. The paper should derive transferable design principles, for example:

- hydrologically typed exchange contracts;
- accepted/trial/committed state ownership;
- exactly-once mass publication;
- finite-window response exposure;
- information cost versus black-box relearning.

### HESS or Journal of Hydrology

**Plausible if hydrological scientific results dominate.**

A strong real-world or controlled hydrological case must show new understanding or capability, not merely software correctness.

### Advances in Water Resources

**Not the default target.**

Its scope emphasizes fundamental scientific advances. The current coupling-method contribution alone is not sufficient. A strong theoretical result on finite-window coupling, response-information sufficiency, convergence or scaling could change that assessment.

## Minimum evidence package for a strong central paper

The paper should not rely on one case.

### E1. Interface correctness

Demonstrate and explain:

- q_bot versus q_u;
- head/pressure-head datum translation;
- sign and area conversion;
- whole-window versus terminal flux;
- interface mass closure.

### E2. Transaction correctness

Directed failure tests must show:

- identical accepted origin for repeated trials;
- rejected candidates leave no state;
- retry and restart do not duplicate mass;
- exactly one coupled exchange is published on acceptance.

### E3. Coupled numerical correctness

Use a controlled one-column/one-groundwater-cell problem to compare:

- loose/sequential exchange;
- iterative black-box coupling;
- response-informed coupling where available;
- a high-iteration or otherwise well-converged reference.

Vary coupling-window length and feedback strength.

### E4. Response interpretation

Resolve the relation among:

- u_FD;
- storage response J_S;
- actual finite-window interface response J_R.

This is essential because a storage coefficient and coupling Jacobian are not automatically the same object.

### E5. Efficiency without misleading iteration counts

Report:

- total SWAP window solves;
- MODFLOW solves;
- response-information acquisition cost;
- wall-clock time;
- coupled convergence and failures.

Include cold and warm black-box multisecant histories if ACCELERATE remains in the paper.

### E6. Hydrological stress cases

Include state/process regimes where coupling could realistically become difficult:

- shallow groundwater and capillary coupling;
- rapid recharge;
- strong ET;
- fine/slow profile;
- boundary or process switching.

Also include a weak-coupling negative control.

### E7. At least one realistic application

A regional or representative application is needed to demonstrate that the formal coupling contract remains usable beyond synthetic qualification.

This case need not carry all novelty. Its role is relevance and external validity.

### E8. Scalability characterization

If regional-scale performance is part of the claim, demonstrate:

- many-column execution;
- MODFLOW cell mapping;
- computational scaling;
- deterministic aggregation and conservation.

Do not claim physical validity of spatial aggregation without PUB-SG evidence.

## Proposed central paper structure

1. **Problem**: existing groundwater-vadose couplings are often embedded, loosely coupled, or insufficiently explicit about state, time and mass semantics.
2. **Prior art**: hydrological model coupling plus generic partitioned/co-simulation methods.
3. **Coupling contract**: solver autonomy, interface quantities, finite windows, state authority and exchange accounting.
4. **Coupling algorithms**: predictor/corrector, black-box and optional response-informed forms.
5. **Verification**: synthetic correctness, rollback and conservation.
6. **Numerical characterization**: convergence, information value and cost.
7. **Hydrological demonstration**: representative SWAP5-MODFLOW6 case.
8. **Scalability and limitations**.
9. **Transferable design principles**.

## Recommended programme decision

The broad coupling-method paper should become the **priority central coupling manuscript**.

PUB-GC / COUPLE and PUB-RC / ACCELERATE should not be allowed to drift into overlapping manuscripts.

Recommended structure:

```text
CENTRAL COUPLING PAPER
    solver-autonomous finite-window SWAP5-MODFLOW6 coupling
    + hydrologically typed conservative transaction semantics
    + coupling verification
    + response-information experiment

ACCELERATE
    retained as a named hypothesis / experiment inside the central paper
    unless later evidence demonstrates a clearly independent,
    generalizable information-value result strong enough for a second paper.
```

This resolves the duplicate-publication risk while preserving the high-priority manuscript even if the narrow acceleration novelty is weak.

## Current verdict

**Broader publication viability: PLAUSIBLE TO STRONG for GMD; PLAUSIBLE for Environmental Modelling & Software if generalization is demonstrated.**

The paper does not need to pretend that the mathematical building blocks are new.

Its strongest defensible proposition is:

> A rigorous vadose-zone/groundwater coupling method can be innovative through the way established partitioned-coupling ideas are assembled into a hydrologically typed, rollback-safe, conservative, solver-autonomous finite-window contract, provided that the resulting capabilities and trade-offs are demonstrated quantitatively and shown to be reusable beyond one implementation detail.

That proposition remains to be tested, but it is sufficiently credible to justify prioritizing the manuscript and the associated evidence programme.
