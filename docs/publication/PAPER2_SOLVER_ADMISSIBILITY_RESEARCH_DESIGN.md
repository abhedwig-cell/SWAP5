# Paper 2 research design

## Working title

Scientific admissibility of alternative soil-water solvers in a process-based vadose-zone model

Alternative working title:

When is a faster soil-water solver scientifically interchangeable? Mapping the admissibility domain of solver substitution in SWAP

## Scope

This paper is a hydrological and numerical study. It is not a paper about SWAP5 migration architecture.

The scientific unit of analysis is the substitution of one qualified soil-water solver for another while holding the surrounding process-model context fixed as far as possible.

The central problem is not whether an alternative solver is fast. The problem is under which physical and numerical conditions solver substitution remains scientifically admissible.

## Primary research question

Under which physical and numerical conditions can an alternative soil-water solver replace the reference Richards solver in a complete process-based model without materially changing the simulated hydrological system?

## Primary novelty claim

The paper must not claim novelty from:

- the Ross method itself;
- having two solvers behind one interface;
- comparing runtime and accuracy;
- using HYDRUS-like or reference Richards solutions as benchmarks;
- demonstrating mass conservation alone.

The candidate contribution is a systematic, interpretable qualification of the solver-substitution domain inside a full process-based model, using a common model context to isolate solver-induced changes from changes in process physics, forcing ownership or application lifecycle.

The intended result is an admissibility domain, not a winner between solvers.

## Literature boundary

The paper must position itself explicitly against at least the following work:

- Ross, P. J. (2003), *Modeling Soil Water and Solute Transport - Fast, Simplified Numerical Solutions*, Agronomy Journal, https://doi.org/10.2134/agronj2003.1352. Ross already introduced the fast non-iterative method and demonstrated large computational gains.
- Crevoisier, Chanzy and Voltz (2009), *Evaluation of the Ross fast solution of Richards' equation in unfavourable conditions for standard finite element methods*, Advances in Water Resources, https://doi.org/10.1016/j.advwatres.2009.03.008. This study already tested Ross across soil types, initial states, grids and difficult hydrological conditions and reported substantial speed gains relative to HYDRUS-1D.
- Ireson et al. (2023), *A simple, efficient, mass-conservative approach to solving Richards' equation (openRE, v1.0)*, Geoscientific Model Development, https://doi.org/10.5194/gmd-16-659-2023. This establishes that accuracy, mass conservation, boundary-flux treatment and runtime are standard solver-evaluation dimensions.
- Kootanoor Sheshadrivasan and Langhammer (2026), *GWSWEX v1.0: a dual-solver 1D unsaturated zone model for mass-conservative groundwater recharge and runoff computation in distributed hydrological modelling*, Geoscientific Model Development, https://doi.org/10.5194/gmd-19-8233-2026. GWSWEX already demonstrates two interchangeable unsaturated-zone solvers behind one model interface and compares accuracy, mass balance and computational performance.
- SUMMA and related multiple-modeling-alternative frameworks establish that interchangeable numerical or process representations are not by themselves novel.

Therefore this paper is viable only if it explains where solver substitution is scientifically admissible, where it is not, and which physical or numerical conditions control that boundary.

## Hypotheses

### H1 - regime dependence

There is no universal classification in which the alternative solver is simply acceptable or unacceptable. Deviation from the Reference solver depends systematically on the hydrological and numerical regime.

### H2 - interaction effects

Material differences are controlled by interactions among hydraulic nonlinearity, initial state, boundary forcing, groundwater proximity, active source and sink processes, spatial discretization and temporal resolution rather than by soil class alone.

### H3 - admissible acceleration domain

A non-trivial subset of the tested state and forcing space exists in which the alternative solver remains within predeclared scientific tolerances for states, integrated fluxes and water balance while reducing computational cost.

### H4 - diagnosable exclusion domain

Outside the admissibility domain, solver deviations are associated with interpretable physical or numerical conditions, allowing fail-closed selection, routing or explicit qualification limits rather than silent use outside the validated envelope.

## Formal concept

Define a tested condition vector:

```text
x = (soil hydraulic properties,
     initial state,
     groundwater regime,
     top and bottom boundary conditions,
     precipitation and evaporation forcing,
     root and distributed sinks,
     profile heterogeneity,
     spatial discretization,
     temporal resolution,
     event structure)
```

Define an admissibility domain:

```text
E_adm = {x :
    D_state(x) <= epsilon_state,
    D_flux(x) <= epsilon_flux,
    D_mass(x) <= epsilon_mass,
    and no excluded scientific failure mode is triggered}
```

The exact discrepancy metrics and tolerances must be defined scientifically before interpreting the experiment.

The aim is not to prove universal equivalence. The aim is to characterize a bounded qualification domain and the mechanisms at its boundary.

## Experimental programme

### Stage A - restricted hydraulic core

Start from the currently admitted RossFast envelope and map behaviour in deliberately simple conditions.

Candidate factors:

- hydraulic material from coarse to fine;
- initial condition from dry to wet;
- prescribed top-flux intensity;
- drainage or prescribed bottom flux;
- grid spacing;
- requested interval and solver step policy.

Purpose: establish the base solver discrepancy structure before adding full process coupling.

### Stage B - known difficult Richards regimes

Target regimes known from the literature to stress Richards-equation solvers:

- infiltration into very dry soil;
- strong infiltration pulses and sharp wetting fronts;
- near-saturated fine-textured soils;
- rapid switching between infiltration and evaporation;
- coarse versus refined grids;
- layered hydraulic profiles if supported by the candidate solver.

Purpose: identify where apparent equivalence fails and whether failure is gradual, threshold-like or mechanism-specific.

### Stage C - process-context expansion

Add process interactions one controlled family at a time, for example:

- root water uptake;
- atmospheric evaporation and transpiration feedback;
- groundwater or head-controlled lower boundary;
- drainage interactions;
- heterogeneous soil profiles;
- other source and sink terms relevant to normal SWAP use.

Each expansion must preserve a comparable surrounding application lifecycle and must be independently qualified before it enters the publication evidence set.

### Stage D - realistic trajectories

Select representative long-running SWAP applications spanning contrasting hydrological regimes.

Purpose:

- test whether short controlled experiments predict long-run divergence;
- identify cumulative flux or event-timing differences;
- quantify computational gain only inside regimes already considered scientifically admissible.

## Experimental design

A naive full-factorial design will likely be wasteful. Use a staged design:

1. space-filling exploration over the simple hydraulic domain;
2. targeted boundary refinement where discrepancy increases;
3. hypothesis-driven stress tests around identified transition regimes;
4. realistic trajectories for external relevance.

The experiment should be designed before large-scale runs are generated. Otherwise the study risks becoming an anecdotal benchmark collection.

## Primary response variables

At minimum evaluate:

- pressure-head trajectory discrepancy;
- water-content trajectory discrepancy;
- integrated top flux;
- integrated bottom flux;
- storage change;
- evapotranspiration or root-uptake effects when active;
- groundwater exchange when active;
- event timing and extrema where scientifically relevant;
- full water-balance residual;
- solver failure, retry and exclusion route;
- computational cost.

Possible normalized metrics should be selected so that results remain interpretable across wet and dry regimes.

## Computational metric

Define speed only after scientific admissibility:

```text
speedup = T_reference / T_alternative
```

Speedup must never compensate for a failed scientific criterion.

The correct result form is:

> Within the declared admissibility domain, the alternative solver remains within the stated hydrological tolerances and reduces computational cost by X under the tested conditions.

The incorrect result form is:

> The alternative solver is X times faster and therefore preferable.

## Required failure analysis

The paper must investigate negative results, not hide them.

For conditions outside the admissibility domain, determine where possible whether divergence arises from:

- constitutive-function assumptions;
- wetting-front representation;
- near-saturation nonlinearity;
- time discretization;
- spatial discretization;
- boundary switching;
- source or sink coupling;
- groundwater coupling;
- accumulated trajectory divergence;
- solver implementation defect rather than method limitation.

A regime map without mechanism analysis is weaker than a smaller map with convincing explanation.

## Candidate figures

### Figure 1 - experimental parameter space

Show the tested physical and numerical axes and the staged expansion from the restricted hydraulic core to full SWAP process contexts.

### Figure 2 - discrepancy distributions

State and integrated-flux discrepancies across the explored regimes, with the predeclared qualification tolerances visible.

### Figure 3 - admissibility map

A two-dimensional or reduced-dimensional representation of the solver-substitution domain. Candidate axes could combine forcing intensity, hydraulic nonlinearity, initial saturation, groundwater proximity or another empirically supported reduction.

Do not force a visually simple map if the data show that the boundary is genuinely high-dimensional.

### Figure 4 - accuracy versus computational cost

Only qualified cases should be interpreted as useful speedups. Failed cases remain visible but must not contribute to a claim of beneficial acceleration.

### Figure 5 - representative failure mechanisms

Show several cases close to and outside the qualification boundary and explain the physical or numerical origin of the divergence.

### Figure 6 - realistic long-run trajectories

If justified by the results, show representative full-model cases to test whether the controlled-domain findings transfer to operational trajectories.

## Candidate tables

### Table 1 - prior solver literature and remaining research gap

Columns: study, solver comparison, physical scope, model context, performance analysis, qualification-domain analysis, remaining difference from this study.

### Table 2 - experimental factors and levels

Include scientific reason for each factor and stage of admission.

### Table 3 - admissibility criteria

Columns: metric, physical interpretation, tolerance, reference basis, failure meaning.

### Table 4 - regime-specific solver qualification

Columns: regime class, cases, state criterion, flux criterion, mass criterion, runtime effect, verdict, limitation.

## Current starting envelope

The current RossFast production integration is intentionally restricted. Its admitted envelope currently includes a small material set, fixed node count and spacing, prescribed-flux boundaries, and excludes root sinks, groundwater boundaries, energy or soil-temperature coupling and mixed MultiSWAP execution.

This restricted envelope is the starting point E0, not the final claim.

Publication development should expand E0 through explicit scientific workunits. Each expansion should state:

- which new physical or numerical condition is being admitted;
- what Reference comparison is required;
- what discrepancy metric and tolerance applies;
- what failure mode would exclude the condition;
- whether the evidence is publication-grade or only engineering qualification.

## What the paper must not contain

Do not use as primary results:

- the SWAP4.3.1 to SWAP5 migration history;
- migration slices M0-M8;
- transaction architecture novelty;
- the full legacy-equivalence suite;
- general state-ownership diagrams;
- evidence that merely shows that a second solver can be wired behind the same interface.

Those belong to Paper 1 or to shared infrastructure.

Paper 2 may cite the common execution architecture as the experimental platform and then move directly to solver science.

## Publication threshold

A simple benchmark result is insufficient.

The paper should proceed to manuscript only if at least one of the following is achieved:

1. an interpretable solver-admissibility domain is established and validated across controlled and realistic cases;
2. a generalizable solver-selection or exclusion principle can be inferred from physical and numerical descriptors known before execution.

If the study yields only mean speedup plus small average error, it is too close to existing Ross, openRE and dual-solver literature to justify the intended paper.

## Journal route

Primary ambitious target: *Water Resources Research* if the work produces a hydrologically interpretable and generalizable admissibility result.

Alternative target: *Advances in Water Resources* if the contribution becomes more fundamentally numerical.

Fallback target: *Geoscientific Model Development* if the result remains primarily a thoroughly evaluated dual-solver model-development study.

## Explicit publication firewall

The transaction lifecycle, state ownership, qualification-gated migration method and legacy-behaviour preservation are infrastructure inherited from Paper 1. They must not be reintroduced as novel findings here.

Paper 2 owns:

- solver discrepancy as a function of physical and numerical regime;
- solver-admissibility criteria;
- accuracy and conservation trade-offs between Reference and alternative solver;
- computational benefit inside the qualified domain;
- physical or numerical explanation of the exclusion domain;
- any scientific solver-selection rule inferred from those results.

## Current readiness

Status: research design established, experimental evidence still insufficient for manuscript.

The existing production RossFast seam demonstrates that controlled solver substitution is technically possible. The publication question is now scientific: how far can the qualified envelope be expanded, where does it fail, and can those boundaries be understood and predicted?
