# F-ROMV2 D11 — post-D10 state-of-the-art reconciliation

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D11  
**Decision:** **FMC_SMVE_FAITHFUL_COMPARATOR_JUSTIFIED_VZAA_AND_ADAPTIVE_ROM_DEFERRED**

## 1. Why D11 exists

F-ROMV2 has now tested enough reduced-physics ideas that another ad-hoc closure would have little scientific value.

The evidence before D11 is unusually constraining:

- C2 demonstrated that a very small state can carry useful local hydraulic information, but its qualified state domain is too narrow for a broad accelerator.
- R8/R4/R2 established a transparent coarse-Richards fidelity sequence.
- D5 showed that two dynamic layer averages plus direct instantaneous Darcy closure are not enough.
- D7 showed that one total-storage coordinate plus a high-resolution quasi-steady profile is not enough.
- D8 showed that two independently conserved quasi-steady segments improve monotonically but still do not beat R2.
- D10 showed that the literature-faithful He et al. integrated two-layer core is also dominated by matched R2 in the shallow zero-pressure-head B01 experiment.

D11 therefore returns to the literature and asks which **different** reduction families still justify a clean experiment.

This is a literature and architecture-authority workunit only.

It does not implement a new model.

## 2. Decision rule

D11 does not rank all reduced models with one score.

Instead it applies prerequisite filters for the **next** bounded B01 research comparator.

A candidate class must have credible authority for all of the following:

1. explicit or structurally exact water accounting;
2. physically meaningful saturated-unsaturated lower-boundary interaction;
3. an online route that does not intrinsically require a full-order Richards trajectory;
4. an explicitly declared approximation rather than a hidden correction;
5. a plausible purpose-dependent benefit even when pointwise profile identity is relaxed;
6. equations and numerical semantics that can be frozen from primary sources before SWAP development evidence is consumed.

Under those prerequisites, one family remains sufficiently strong for immediate follow-up:

**finite-water-content / Soil Moisture Velocity Equation (FMC/SMVE).**

That is authorization for a research comparator, not an application or production conclusion.

## 3. FMC / SMVE

### Primary sources

- Ogden et al. (2015), *A new general 1-D vadose zone flow solution method*, Water Resources Research 51, 4282-4300. DOI: 10.1002/2015WR017126.
- Ogden et al. (2015), *Validation of finite water-content vadose zone dynamics method using column experiments with a moving water table and applied surface flux*. DOI: 10.1002/2014WR016454.
- Ogden et al. (2017), *The Soil Moisture Velocity Equation*, Journal of Advances in Modeling Earth Systems 9, 1473-1487. DOI: 10.1002/2017MS000931.

### Scientific identity

The finite-water-content approach is not simply a coarser Richards grid.

It starts from unsaturated Darcy flux and water conservation, applies a change of dependent variable and finite-water-content discretization, and advances moisture-content fronts/states with ordinary differential equations.

The published method is designed to represent:

- infiltration;
- falling moisture slugs;
- gravity and capillarity;
- response to fixed and moving water tables;
- bidirectional exchange with groundwater.

Its finite-volume construction makes water conservation part of the method itself.

That property is particularly important for SWAP5 because F-ROMV2 has already rejected architectures whose practical value depended on hidden correction or ambiguous mass accounting.

### Purpose-dependent fidelity

The method is also conceptually aligned with the governing F-ROMV2 proposition.

Published comparisons explicitly allow the water-content profile shape to differ from a Richards solution while testing integrated infiltration and flux behavior.

In the analytical/Richards comparisons reported by Ogden and co-workers, cumulative infiltration remained close even where the neglected diffusion-like contribution changed wetting-front shape.

This is exactly the distinction required by F-ROMV2:

> a deliberately reduced hydrological model is judged by the fidelity needed for its intended application, not by universal pointwise identity to the full Richards trajectory.

### Groundwater interaction

The moving-water-table validation is unusually relevant.

The published experimental comparison uses a soil column subjected to rising and falling water tables together with applied surface flux.

The finite-water-content method and HYDRUS-1D both reproduced water-content time series satisfactorily; the two methods showed different strengths in ponding/deponding timing.

This does not establish suitability for SWAP5.

It does establish that the class has primary-source authority for **two-way atmosphere-vadose-groundwater dynamics**, rather than merely free drainage.

### Computational precedent

The SMVE/FMC literature reports substantial acceleration relative to HYDRUS-1D for its own vector implementation.

That external result is useful only as motivation.

It is **not** imported as a SWAP5 speed claim.

Any SWAP5 cost claim still requires a same-runtime implementation and admitted performance protocol.

### Important open boundaries

D11 does not assume that every SWAP process maps directly to FMC/SMVE.

The first comparator must exclude root-water uptake and ET.

The existing FMC literature contains evapotranspiration formulations, but those are not automatically the same physical sink distribution as SWAP.

Likewise, the exact mapping between SWAP's arbitrary prescribed bottom pressure head and the published FMC/SMVE groundwater representation must be derived from primary-source authority before it is used.

## 4. VZAA

### Primary source

Sadeghi et al. (2026), *Vadose zone analytical algorithm (VZAA): a non-iterative algorithm for vadose zone soil moisture and groundwater recharge*, Journal of Hydrology 673, 135467.

VZAA is highly relevant to the broader SWAP5 problem.

It is non-iterative, is designed specifically for regional groundwater models, and allows bidirectional saturated-unsaturated exchange.

It therefore remains an important application-specific precedent.

### Why it is not D12

The published VZAA formulation conflicts with several current F-ROMV2 prerequisites.

Most importantly:

- the lower boundary is primarily an output coupled to the water table rather than a generally enforceable prescribed SWAP lower-boundary condition;
- groundwater-table motion uses a soil-specific empirical specific-yield factor whose calibration materially affects the result;
- published coarse discretizations can exhibit cumulative mass residuals that are large relative to the current SWAP5 integrity expectations;
- substantially finer vertical/time discretization improves those residuals, but then changes the computational-value question;
- root-water uptake is not yet part of the core published soil-moisture/flux relation.

D11 therefore does **not** reject VZAA scientifically.

It classifies VZAA as:

**regional-groundwater application precedent, deferred as a general SWAP5 reduced-model comparator.**

A later application-specific proposition could reopen it if the targeted boundary semantics and mass/error envelope are defined independently.

## 5. Adaptive structure-preserving aggregation

Sahoo and Liu's adaptive agro-hydrological model reduction is directly relevant to the C2 coverage problem.

Their method groups states with similar trajectories and builds structure-preserving reduced models for different operating regions.

This demonstrates that local/regime-dependent state aggregation is a serious alternative to a single global low-dimensional coordinate system.

However, the published adaptive workflow generates original-model trajectories when constructing operating-region models.

Its primary demonstrated benefit is reduction of state-estimation/MHE dimension.

As published, it is therefore not a standalone forward-model accelerator.

It is retained as a future architecture for a possible **adaptive local C2 successor**, not as the D12 physical comparator.

Any such successor would need:

- new blind-data governance;
- a frozen operating-region definition;
- a threshold policy not tuned on V01-V04;
- a forward route whose online cost does not hide full-order trajectory generation.

## 6. POD, DEIM and other projection ROMs

Projection ROMs remain technically possible.

The central problem is already visible in Richards-specific literature: reducing state dimension alone does not guarantee online speed because nonlinear residual and constitutive evaluation may still scale with the full model.

DEIM and related hyper-reduction can address this.

Broader conservative finite-volume ROM research also shows that reduced models can be constrained to conserve selected subdomain balances.

Nevertheless, for the current one-dimensional SWAP column the path is comparatively intrusive:

- basis construction;
- nonlinear hyper-reduction;
- conservation constraints;
- physical bounds;
- OOD detection;
- restart semantics;
- training-domain governance.

D11 therefore keeps conservative local hyper-reduction as a **secondary fallback** if FMC/SMVE does not produce a useful frontier point.

POD-only is not authorized as the next experiment.

## 7. ROM-assisted full-order solving

Using a ROM prediction as a full-order initial guess can accelerate nonlinear solves.

That is useful, but it belongs to the solver route rather than to the deliberately reduced hydrological-model route studied here.

F-ROMV2 therefore preserves the existing classification:

**solver comparator / handoff, not production reduced-model rescue.**

## 8. Why FMC/SMVE is the next comparator

The decision is not that FMC/SMVE is universally superior.

It is narrower:

> Of the remaining reviewed classes, FMC/SMVE is the only one that currently clears all prerequisites for a clean, bounded B01 comparator without first weakening F-ROMV2 integrity or hiding a full-order route online.

It offers a genuinely different trade-off from every model already tested:

- unlike C2, it has a physical state-evolution law rather than a local learned transition table;
- unlike R2/R4/R8, it does not solve the vertically discretized nonlinear Richards system;
- unlike D5/D8, it does not collapse profile dynamics to two instantaneous layer heads;
- unlike QS1/QS2, it retains explicitly moving moisture-content structures rather than instantaneously projecting the profile onto a quasi-steady manifold;
- unlike HE2, it has direct published moving-water-table validation and a finite-volume mass-conservation construction.

That is enough to justify D12.

It is not enough to claim success.

## 9. D12 authority

D12 is authorized as a staged literature-bound workunit.

### Stage 1 — equation authority

Reconstruct from the primary papers:

- state variables;
- front/bin ordering;
- flux equations;
- saturated and unsaturated boundary conventions;
- rising/falling water-table mechanics;
- layer-transition mechanics;
- treatment of coincident/colliding moisture fronts;
- numerical stepping;
- exact mass ledger.

No SWAP trajectory may be used to choose these equations.

### Stage 2 — published preflight

Before a SWAP B01 comparison, reproduce at least one published or analytically checkable FMC/SMVE benchmark.

The benchmark must show:

- finite, physically ordered water-content states;
- exact/explicit mass closure;
- correct infiltration or water-table direction;
- no hidden clipping or mass correction.

### Stage 3 — bounded B01 development comparator

Only after Stage 2 passes may a SWAP-matched development experiment run.

Initial scope:

- homogeneous B01;
- no root extraction;
- no ET;
- prescribed surface hydraulic forcing;
- only lower-boundary/groundwater semantics supported by the reconciled primary-source authority;
- R16 and admitted R2 comparators;
- exposed development evidence only.

Existing V01-V04 histories remain exposed and cannot become blind confirmation.

### Discretization firewall

The number/distribution of finite-water-content bins may not be tuned against SWAP outcomes.

It must be frozen from literature authority or from a pre-SWAP convergence rule.

### Code provenance

A clean-room implementation should be derived from the equations.

Public external code or datasets may be used as a secondary oracle only after provenance/license review.

They are not silently copied into SWAP5.

## 10. What D11 does not authorize

D11 does not authorize:

- a production FMC/SMVE implementation;
- a VZAA production or general research implementation;
- changing the F-ROMV2 mass-integrity contract;
- importing an external HYDRUS runtime ratio as a SWAP speedup claim;
- using published RMSE values as SWAP acceptance thresholds;
- root-water-uptake or ET claims;
- an adaptive clustered ROM trained on the exposed V histories;
- a POD/deep-learning escalation before FMC/SMVE discrimination;
- application acceptance.

Production ROM remains unauthorized.
