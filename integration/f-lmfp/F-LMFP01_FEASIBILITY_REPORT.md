# F-LMFP01 — Reduced-Order Layered MFP Soil-Water Solver Feasibility

**Workunit:** F-LMFP01  
**Working name:** LayeredMFP  
**Status:** feasibility study, no production admission  
**Decision:** **GO_PROTOTYPE**  
**SWAP5 basis:** `work/f-si17-process-hydraulic-view` at `fca2f497e465c4782ebc6e25756aff70cbb2554e`  
**SWAP 4.3.1 source input:** `/mnt/data/SWAP_4.3.1(6).zip`, SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`

## 0. Executive finding

A WOFOST-lineage, layered matric-flux-potential soil-water solver is scientifically and architecturally credible enough to justify a standalone prototype for SWAP5. The evidence is **not** strong enough to admit it as a production solver or to define a final application envelope.

The strongest argument for proceeding is not that the historical WOFOST routine is already a substitute for Richards. It is that its core reduced-order structure is useful:

1. conserved water storage is carried per soil layer;
2. pressure head, conductivity and matric flux potential are diagnosed from constitutive hydraulic relations;
3. vertical transfer is calculated locally at layer interfaces, rather than by one global nonlinear Richards solve;
4. heterogeneous layer interfaces are handled by a bounded scalar equal-flux construction;
5. the resulting cost is approximately linear in layer count with bounded local iteration, rather than being dominated by a column-wide Newton/Jacobian convergence history.

This makes the method a serious candidate for a **separately selected soil-water model** behind the existing SWAP5 common solver contract. It must never be an execution-policy fallback that silently replaces Richards.

Several WOFOST details are unsuitable as SWAP5 production rules without further evidence: the fixed one-day step, field-capacity gating, the fixed 0.50 upward-flow limiter, the composite `max(dry flow, wet flow)` closure, daily surface evaporation history, and the historical groundwater closure through `SUBSOL`. These are therefore treated as lineage/reference behavior, not as immutable physics.

The recommended next step is a clean standalone prototype with two modes:

- **Lineage reference mode:** reproduce the documented WATFDGW behavior closely enough to prove that the algorithm has been reconstructed correctly.
- **SWAP5 candidate mode:** use SWAP hydraulic constitutive functions, generic `[t0,t1]`, conservative finite-volume storage updates, explicit SWAP5 boundary semantics and transaction-safe trial execution.

Only the second mode is compared scientifically against SWAP5 FullRichards. No production kernel integration should occur before that comparison has established an empirical qualification envelope.

## 1. Source inventory, provenance and licensing

### 1.1 Rappoldt et al. layered WOFOST source

Primary technical reference:

C. Rappoldt, H.L. Boogaard, L. Brodský, R. Kodešová and C.A. van Diepen, **Extension of the WOFOST soil water submodel; Comparison with SWAP and technical documentation**, EcoCurves report 6, 2012. Public WUR repository: <https://edepot.wur.nl/687451>.

The report contains the technical derivation and, in Appendix C, the complete source of `SUBROUTINE WATFDGW`. The source header and revision history identify the lineage as:

- C.A. van Diepen, February 1989, revised July 1990, WATFD derived from the APPLE/WOFOST 4.1 lineage;
- T. van der Wal, 24 July 1997 amendments;
- H. Boogaard, 15 June 1998 amendments;
- C. Rappoldt, January 2008 major multilayer/F90 work;
- December 2008 major upward-flow and groundwater extension, explicitly described as replacing both `WATFD` and `WATGW`.

`WATFDGW` therefore is not merely a renamed `WATFD`. It is a later combined multilayer algorithm with explicit MFP-based interlayer transfer and optional groundwater influence.

**License caution:** the 2012 report itself contains reproduction restrictions. That report is adequate as a scientific and regression reference, but this workunit does **not** treat the Appendix C source text as code that may automatically be copied into SWAP5. A clean reimplementation of documented equations and behavior is preferred unless licensing is separately cleared.

### 1.2 Historical WOFOST 7.1 Fortran repository

Repository: <https://github.com/ajwdewit/WOFOST>.

The repository distributes WOFOST 7.1.7 source and is licensed under EUPL 1.1 or later. Its historical water routines include separate `WATFD`, `WATGW` and `SUBSOL` implementations.

Relevant distinction:

- `WATFD`: freely draining, simplified water balance, essentially rooted/lower compartments, not the later general multilayer MFP solver.
- `WATGW`: groundwater-influenced simplified balance with homogeneous-soil assumptions and equilibrium constructions.
- `SUBSOL`: stationary capillary/percolation transfer routine used to relate groundwater distance, hydraulic conductivity and stationary flow. It numerically integrates a stationary flow relation and searches the flow with bounded iteration. It is not a transient Richards solve and should not be mistaken for a direct MODFLOW coupling algorithm.

The old repository is valuable for provenance and regression, but the target LayeredMFP concept is primarily descended from the later `WATFDGW` formulation.

### 1.3 Current WOFOST / PCSE line

Current WUR WOFOST information states that the multilayer water balance is available in WOFOST 7.3 and 8.1, and that current WOFOST development/reference implementation is PCSE/WOFOST: <https://www.wur.nl/en/research/products-services/wofost-world-food-studies>.

PCSE repository: <https://github.com/ajwdewit/pcse>.

Current `pcse/soil/multilayer_waterbalance.py` contains class `WaterBalanceLayered`, explicitly described as a Python reconstruction of the layered WOFOST concept. It preserves the dry-flow/wet-flow/MFP logic and still states that the implementation is intentionally close to the earlier Fortran for verification.

Important limitation: the currently inspected PCSE implementation raises `NotImplementedError` when groundwater influence is active. It therefore cannot be used as evidence that the current Python production path has already solved the shallow-groundwater part of historical `WATFDGW`.

PCSE is licensed under EUPL 1.1 or later.

### 1.4 SWAP 4.3.1 source

The supplied archive contains a nested SWAP source archive. The inspected source identifies:

- `Version = '4.3.1'`;
- `VersionDate = '2026-06-30'`;
- license comment `GPL Version 2 or later`.

Relevant source units:

- `headcalc.f90`: nonlinear Richards solver with Newton iterations, tridiagonal Jacobian solve and backtracking;
- `MOD_MvG_functions.f90`: shared hydraulic constitutive functions including `watcon`, `moiscap`, `hconduc`, `dhconduc`, `prhead`;
- `boundbottom.f90`: bottom-boundary implementations including prescribed head (`SWBOTB=5`) and free drainage (`SWBOTB=7`);
- `rootextraction.f90`: root extraction using hydraulic state such as pressure head and water content.

This is important for the LayeredMFP design: the candidate solver does not need a second independent soil-hydraulic parameterization. It can derive its storage, head, conductivity and MFP from the same constitutive material models used by FullRichards.

### 1.5 Current SWAP5 architectural contracts

F-SI01 already defines `soil_water_solver_v1_boundary` with separate immutable hydraulic parameters, base physical state, boundary forcing, numerical configuration, worker workspace, candidate result, unrounded mass accounting and optional interface sensitivity. It reserves variants for `reference_richards`, `coarse_richards` and `reduced_order`.

F-SI15 keeps physical configuration separate from numerical configuration. This is directly compatible with the rule that choosing LayeredMFP is a physical/numerical model choice, not a performance-policy action.

F-SI17 defines a solver-neutral read-only process hydraulic view with pressure head, water content, ponding depth and groundwater level, without exposing HeadCalc/Newton/Jacobian internals.

The prescribed-bottom-head work in F-SI16 is **not** treated as a stable dependency of this report. On 8 September 2026 that branch was reopened after an authoritative B1.10 `qbot` oracle mismatch. LayeredMFP may therefore design the required semantics now, but direct prescribed-head production admission must wait for an owner-qualified common bottom-head contract.

## 2. Reconstruction of the WATFDGW concept

### 2.1 State at the start of a step

The physical core stores a volumetric moisture content or equivalent water amount for each soil layer. The historical routine also carries crop-zone aggregates, cumulative balances, surface storage, groundwater variables and process history. Those extra variables are not all intrinsic soil-solver state.

For a layer `i` of thickness `Δz_i`, the conserved layer amount can be written as

`W_i = θ_i Δz_i`.

From current `θ_i`, the historical algorithm obtains or looks up:

- matric pressure state, expressed through pF/head;
- hydraulic conductivity `K_i`;
- matric flux potential `Φ_i`.

### 2.2 Matric flux potential

The report defines matric flux potential as

`Φ(h) = ∫_{-∞}^{h} K(ξ) dξ`.

Under a stationary no-gravity approximation,

`q = - dΦ/dz`.

This transformation is useful under dry conditions because a large suction gradient is multiplied implicitly by the very small conductivity. MFP itself is material-specific and is generally discontinuous when the soil hydraulic material changes. Pressure head remains the physically continuous quantity at a material interface.

The original WATFDGW implementation tabulates MFP as a function of pF. The report describes numerical construction of those tables using Gaussian quadrature. That table construction is an implementation choice, not a requirement of the reduced-order principle.

### 2.3 Interlayer dry flow

For adjacent halves of the same hydraulic material, the documented dry-flow limit is proportional to the MFP difference over the distance between layer centres. In the WATFDGW source this appears in the form

`LIMDRY = 2 (Φ_upper - Φ_lower) / (Δz_upper + Δz_lower)`

with the historical sign convention.

For different materials, a single MFP difference is invalid because `Φ` is not continuous across the interface. WATFDGW instead solves for an interface matric state for which the flow through the upper half-layer equals the flow through the lower half-layer. The inspected implementation uses bisection with a maximum of 50 iterations and a flow tolerance of `0.001 cm d-1`.

This equal-head/equal-flux interface construction is one of the most generally reusable parts of the algorithm.

### 2.4 Wet gravitational flow

The wet-flow estimate is based on current conductivities and gravity. The documented expression is equivalent to a thickness-weighted harmonic conductivity across a face:

`LIMWET = (Δz_u + Δz_l) / (Δz_u/K_u + Δz_l/K_l)`.

It represents a unit downward gravitational gradient.

### 2.5 Composite downward and upward transfer

Historical WATFDGW constructs downward transfer by taking the larger of dry-flow and wet-flow candidates and then applying storage/capacity constraints:

`q_candidate = max(LIMDRY, LIMWET)`

for the downward case.

The final transfer is further limited so that a receiving layer does not oversaturate and a donating layer does not violate the algorithm's storage rules.

Upward transfer occurs only through the dry-flow branch when `LIMDRY < 0`. The amount is additionally limited by the amount required to bring two layers toward equal potential. The historical constant

`UpwardFlowLimit = 0.50`

limits the upward transfer to 50% of that equal-potential amount per daily step. The equal-potential amount is itself found by another bounded scalar iteration.

This means the algorithm is **not iteration-free**. It avoids a global nonlinear Richards solve, but heterogeneous interfaces and upward-equalization calculations can require bounded local iteration.

### 2.6 Sources, sinks and storage update

WATFDGW combines infiltration, evaporation, root uptake, layer flow and groundwater exchange into daily layer water changes. Its conceptual mass path is:

`state(t0)`

`+ top infiltration / irrigation`

`+ interlayer inflow - interlayer outflow`

`- evaporation - root uptake - other sinks`

`+/- lower boundary / groundwater exchange`

`= state(t1)`.

The historical code applies flux limits before integrating storage. This is preferable to clipping water contents after an update because post-update clipping would create or destroy water unless a compensating ledger is maintained.

### 2.7 Groundwater in WATFDGW

The 2008/2012 WATFDGW line contains optional groundwater influence. When the water table lies below the explicitly layered system, it can use the older stationary `SUBSOL` concept to obtain capillary rise/percolation. Capillary supply is then limited by equilibrium/profile water constraints.

This groundwater closure is useful as lineage evidence, but it is not sufficient as the SWAP5 direct-groundwater contract. It carries historical assumptions about stationary transfer to a groundwater table and daily water balance. LayeredMFP must instead be able to consume an explicit bottom boundary condition and return a conservative bottom flux.

### 2.8 Time step

Both the WATFDGW source and the current PCSE reconstruction are explicitly organized around a one-day water-balance step. Current PCSE code sets `delt = 1.0` in the rate calculation and documents that very thin top layers are problematic because rainfall can fill them within one daily step.

This daily dependence is material to reproducing WOFOST results, but there is no evidence that one day is mathematically fundamental to the MFP idea itself. The SWAP5 candidate must therefore remove the daily assumption and requalify every limiter that currently has per-day meaning.

## 3. Physical and numerical assumptions

The reconstruction separates reusable principles from WOFOST-specific assumptions.

### Reusable principles

- conserved storage per layer;
- constitutive `θ(h)`, inverse `h(θ)` and `K(h)`;
- MFP derived from the same `K(h)` relation;
- local interface transfer;
- continuity of head and water flux at heterogeneous interfaces;
- bounded local nonlinear solution instead of a column-wide Newton system;
- conservative pre-update flux limiting;
- explicit lower-boundary exchange.

### WOFOST-specific or currently unqualified assumptions

- one-day time step;
- minimum practical layer thickness tied to that daily step;
- hard field-capacity gates in flow limiting;
- fixed 0.50 upward equilibration fraction;
- `max(dry, wet)` as the general downward closure;
- daily rainfall/infiltration history used for soil evaporation;
- root-depth/layer-boundary restrictions;
- historical surface-storage and runoff ownership inside the water-balance routine;
- groundwater closure through stationary `SUBSOL` logic;
- pF-specific tables and pF-specific bisection variables.

None of these assumptions is automatically adopted by SWAP5 merely because it exists in WATFDGW.

## 4. Relation to Richards

FullRichards solves the transient pressure-head/storage relation with fluxes derived from hydraulic gradients and conductivity, globally coupled over the vertical discretization. SWAP 4.3.1 `headcalc.f90` confirms a column-wide Newton procedure with Jacobian construction, tridiagonal solve, possible alternative linear solve and backtracking.

LayeredMFP instead advances conserved layer storage with a local reduced-order face closure. It reconstructs head from storage and uses MFP plus conductivity to estimate exchange. Therefore it is **not** a coarse algebraic implementation of the same discrete Richards equations. It is a different reduced-order soil-water model and must be qualified as such.

This distinction is why execution policy must not select it silently.

## 5. Reuse of SWAP hydraulics

The recommended SWAP5 formulation uses a shared hydraulic-material provider for both FullRichards and LayeredMFP:

- `theta(h)` from the common constitutive provider;
- `h(theta)` from a validated inverse provider;
- `K(h)` from the common constitutive provider;
- `C(h)` where another process or sensitivity calculation needs capacity;
- `MFP(h)` derived from the same `K(h)` relation.

SWAP 4.3.1 already contains the corresponding legacy functions `watcon`, `prhead`, `hconduc` and `moiscap` across its supported hydraulic models. The SWAP5 target should expose equivalent solver-neutral constitutive evaluations rather than call legacy globals.

MFP should be a shared immutable material property/evaluator. A precomputed monotone MFP table is plausible and attractive for throughput, but must be generated once per hydraulic material, not stored per logical column.

Required constitutive tests include:

- `theta(h)` monotonicity and bounds;
- `h(theta(h))` round trip;
- `K(h)` positivity and dry/saturated limits;
- `C(h)` consistency where used;
- MFP numerical integral versus high-accuracy reference integration;
- stable dry-tail and saturation-end behavior.

## 6. Strong layer transitions

For a material boundary, do not average MFP values across the interface. The physically defensible reduced-order construction is:

1. assume a common interface pressure head `h*`;
2. calculate upper half-layer transfer using material A between `h_u` and `h*`;
3. calculate lower half-layer transfer using material B between `h*` and `h_l`;
4. solve the scalar residual `q_A(h*) - q_B(h*) = 0` within a bounded bracket;
5. use that single face flux with opposite signs in the two adjacent layer balances.

This preserves the WOFOST insight while making it independent of pF tables. The prototype must explicitly test whether a unique monotone root exists throughout the intended hydraulic envelope. If no safe bracket or root exists, the trial fails closed; it must not invent a blended flux.

## 7. Generic time and exact conservation

### 7.1 Conservative update

For layer `i`:

`W_i^{n+1} = W_i^n + Δt [q_{i-1/2} - q_{i+1/2} + S_i - U_i]`.

One face flux value is used exactly once as outflow of one layer and inflow of the adjacent layer. Boundary fluxes are entered once in the external mass ledger.

Mass acceptance is based on unrounded amounts. There is no tolerance that permits water disappearance as a performance concession.

### 7.2 Admissibility

Layer storage bounds and physical source/sink limits must be enforced before committing a trial. The candidate should prefer flux limitation, bounded substepping or trial rejection over post-update `theta` clipping.

### 7.3 Generic `[t0,t1]`

The public solver semantics are an arbitrary interval `[t0,t1]`. If the reduced-order closure requires smaller internal increments during an intense event, these are solver-internal substeps. They do not introduce a calendar day as a fundamental unit.

The prototype must investigate a stability/admissibility controller based on local storage and flux change, not on midnight or a fixed daily loop. No final controller formula is qualified by this workunit.

## 8. Transaction semantics

The conceptual interface proposed in the workunit request included `commit` and `rollback` on `SoilWaterSolver`. The current qualified SWAP5 F-SI/F-KT boundary indicates that this ownership should remain outside the solver.

Recommended semantics:

`advance_trial(base_state, parameters, forcing, boundary, [t0,t1], physical_config, numerical_config, workspace) -> trial_result`

where `trial_result` contains candidate physical state, realized fluxes, mass accounting, process hydraulic view, interface response and diagnostics.

The solver:

- may not mutate the committed input state;
- may not commit;
- may not rollback;
- may request retry/substep advice;
- may reuse numerical scratch/warm starts only if physical restart always uses the correct committed/base state.

F-KT/runtime performs checkpoint, trial, retry, commit and rollback. This keeps FullRichards, CoarseRichards and LayeredMFP transactionally interchangeable.

## 9. Candidate state and scratch model

### Persistent physical state per LayeredMFP column

Prefer the smallest conservative representation:

- layer water amount `W_i` or an equivalent exactly convertible water-content state;
- any additional state only if it represents real physical memory that cannot be reconstructed from committed state and parameters.

Groundwater level should not be duplicated as private solver state when it is a boundary/coupler state owned elsewhere.

Surface storage should remain with the surface process unless the common physical-state contract explicitly owns it.

### Shared immutable parameter data

- layer geometry/template;
- hydraulic material IDs;
- constitutive parameter sets;
- MFP evaluator/table per material;
- root/process mapping metadata where immutable.

### Worker/job scratch

- reconstructed `h_i`, `theta_i`, `K_i`, `MFP_i`;
- dry/wet face candidates;
- local interface brackets and iteration state;
- equal-potential calculations;
- trial layer amounts;
- limiter/admissibility data;
- temporary source/sink arrays;
- tangent workspace;
- diagnostics counters.

No Newton vectors or Jacobian are required for LayeredMFP itself. Scratch is `O(Nlayer)` per active worker/job, not per logical column.

## 10. Process-facing outputs and shared solver interface

Other SWAP processes must consume solver-neutral information, not LayeredMFP internals. The common result/view should be able to provide, as applicable:

- water content profile;
- reconstructed pressure-head profile;
- ponding/surface state through the owning surface-process contract;
- groundwater level where physically defined;
- vertical face fluxes;
- realized top and bottom flux;
- realized distributed sinks/sources;
- drainage exchange;
- full storage and mass ledger;
- solver identity and diagnostics;
- optional bottom-interface sensitivity.

F-SI17 already demonstrates the intended direction for process-facing hydraulic state. LayeredMFP should produce the same semantic view as FullRichards.

## 11. Bottom boundary and MODFLOW coupling

### 11.1 Required bottom modes

LayeredMFP should ultimately support at least semantically:

- free drainage;
- prescribed bottom flux;
- prescribed bottom head.

The current F-SI13 admitted common route is limited to free-drainage modes. Prescribed-head production integration remains an external dependency because F-SI16 is currently reopened.

### 11.2 Direct MODFLOW contract

For a direct coupling trial with imposed MODFLOW head:

`H_b = H_MF`

is provided as boundary data to LayeredMFP. The solver returns a conservative `q_b`. The coupler enforces/checks

`q_SWAP = - q_MF`

under the shared sign convention and accepted coupling tolerance. The bottom flux is part of the exact LayeredMFP mass ledger.

The historical `SUBSOL` path is not used as the production MODFLOW contract. It may be retained only as a lineage regression oracle for stationary capillary-rise cases.

### 11.3 Deep vadose

LayeredMFP does not remove the need for invariant 18. If the modeled SWAP soil column ends far above deep groundwater, its bottom flux may feed the separate conservative transfer-zone component. Runtime/coupler owns that composition.

## 12. Interface sensitivities

A useful LayeredMFP advantage is plausible but not yet proven: bottom-interface response may be cheaper to differentiate than a full Richards column solve.

Candidate quantities:

`dq_b/dH_b`

and, where locally invertible,

`dH_b/dq_b`.

Potential production approach:

1. express the active bottom-face closure as a local scalar relation;
2. differentiate it analytically or by implicit differentiation while the active limiter regime is unchanged;
3. propagate any necessary storage sensitivity through internal substeps;
4. mark the tangent unavailable at limiter/regime discontinuities rather than return a misleading derivative.

Reference/fallback qualification uses symmetric `+ΔH/-ΔH` perturbations. Reciprocating `dq/dH` to obtain `dH/dq` is only valid when the local slope is nonzero, stable and the response is locally one-to-one.

This is currently a **feasible hypothesis**, not a qualified capability.

## 13. Material deviations from WOFOST to be tracked

| Topic | WOFOST reference | Proposed SWAP5 LayeredMFP | Reason | Expected physical effect | Expected numerical effect | Required test |
|---|---|---|---|---|---|---|
| Time | Fixed daily step | Generic `[t0,t1]`, bounded internal substeps if required | Invariant 9/10 | better event-scale representation | new timestep controller | split-step and timestep sweep |
| Hydraulics | WOFOST pF/SM/K/MFP tables | shared SWAP `theta(h)`, `h(theta)`, `K(h)`, optional `C(h)`, derived MFP | invariant 21 | consistent material physics with FullRichards | different interpolation/integration errors | constitutive oracle |
| MFP integration | historical tabulation/Gaussian quadrature | validated shared material evaluator/table | no per-column duplication | none if accurate | faster repeated lookup | high-accuracy quadrature comparison |
| Heterogeneous interface | pF-based bisection | common-head `h*`, equal-flux scalar solve | solver-neutral materials | same continuity principle | bounded root solve | strong K/retention contrast |
| Downward closure | `max(LIMDRY,LIMWET)` | preserve in lineage mode; candidate change only with evidence | heuristic must be tested | potentially material | may alter regime switching | FullRichards flux comparison |
| Upward limiter | fixed `0.50` equilibrium fraction | preserve lineage; treat as unvalidated in candidate | daily heuristic | affects capillary rise rate | strong dt dependence possible | capillary rise + dt sweep |
| Field-capacity gating | explicit historical limiter | lineage exact; candidate may require storage/admissibility based alternative | avoid hard agronomic threshold as transport law unless justified | potentially material | smoother or different switches | drainage/capillary tests |
| Oversaturation prevention | WATFDGW FlowMX logic | conservative face limiting and/or reject/substep | hard mass guarantee | avoids clipping artefact | transactional retry path | closed-column mass tests |
| Groundwater | WATFDGW + `SUBSOL` stationary closure | explicit bottom head/flux boundary contract | invariant 12 | supports direct coupler semantics | local boundary response | Hb sweeps + coupled harness |
| Surface storage/runoff | inside WOFOST water balance | owned by SWAP surface process | invariant 21/28 | preserves SWAP surface physics | cleaner solver core | ponding/infiltration coupling |
| Soil evaporation history | daily DSLR/rain history in WOFOST | owned by SWAP evaporation/surface process | not intrinsic soil-solver state | preserves SWAP process physics | removes hidden state | evap-only regression |
| Root uptake | WOFOST root/layer bookkeeping | external SWAP root sink provider mapped conservatively to layers | invariant 21/22 | preserves SWAP uptake/stress | source/sink input | root-depth and stress tests |
| Root-depth alignment | max root depth on layer boundary | fractional conservative sink mapping if needed | decouple crop geometry from reduced layers | less artificial geometry constraint | mapping cost | moving-root tests |
| I/O/task flags | `ITASK`, files/run control in routine | no files, parsers or calendar in solver | invariants 2/29 | none | cleaner/reentrant | static dependency gate |
| Groundwater within profile | historical equilibrium logic | SWAP5-specific saturated/storage formulation to be determined | direct coupling requirement | **open scientific issue** | may require additional state/closure | rising/falling water-table tests |

Any future material change must add a row rather than silently diverge from the lineage reference.

## 14. Expected performance and scalability

### 14.1 Work per layer/face

For same-material faces, the dominant operations are constitutive lookups and a fixed amount of arithmetic. For heterogeneous interfaces and upward equalization, the historical algorithm can perform bounded scalar iterations, up to 50 in the inspected reference implementation.

Therefore the expected complexity is approximately

`O(Nlayer × bounded local face work)`

plus any internal substeps.

There is no LayeredMFP column-wide Newton vector, Jacobian construction or tridiagonal Newton correction loop.

### 14.2 Predictability

LayeredMFP is promising specifically because local iterations can be bounded and diagnosed. This should make tail cost more controllable than FullRichards in difficult columns. That conclusion remains empirical until benchmarks include p50, p95, p99 and maximum cost over difficult ensembles.

A bounded-cost contract must not silently change physical model when a cap is reached. A failed LayeredMFP trial can be rejected or reported outside its envelope. Whether runtime subsequently selects another **explicitly configured** model is an orchestration decision, not a hidden performance-policy action.

### 14.3 Memory

Persistent memory is `O(Nlayer)` conserved storage per logical column plus compact required physical state. Immutable hydraulic material data is shared.

Scratch is `O(Nlayer)` per active worker/job.

This is compatible with SoA storage, material/template batching and hundreds of thousands of logical columns.

### 14.4 SIMD/GPU

Potential is good for homogeneous batches because the same face formulas repeat independently over many columns. Divergence sources include:

- upward versus downward flow;
- same versus different material interface;
- active storage limiter;
- surface/bottom boundary regime;
- varying local iteration counts;
- varying internal substep counts.

The first implementation should target deterministic CPU batches and SoA-friendly data. SIMD/GPU optimization should follow only after qualification establishes stable branches and material-grouping strategies.

### 14.5 Speedup claim

No numerical speedup factor is claimed by this report. The source evidence supports a lower-dimensional, locally bounded computation, but actual performance relative to FullRichards depends on layer count, constitutive evaluation cost, local bisections, substeps and qualification constraints.

## 15. Initial qualification envelope hypothesis

### Promising, but not yet admitted

- matrix-flow dominated mineral soils;
- moderate layer counts and layer thicknesses compatible with the chosen internal time scale;
- free drainage;
- capillary redistribution without very fast saturation-front dynamics;
- slowly to moderately varying groundwater heads after explicit qualification;
- crop simulations where conserved storage, root-zone water availability and integrated fluxes are primary outputs.

### Mandatory stress tests before exclusion or admission

- sharp infiltration fronts;
- ponding;
- perched groundwater;
- strong K contrast;
- strong retention contrast;
- rapidly varying bottom head;
- heavy clay/B12-like problem columns;
- shrink/swell or crack-sensitive soils;
- macropore cases;
- cases where other processes require accurate local pressure-head trajectories.

These are **not** declared failures in advance. FullRichards remains the reference until tests demonstrate where LayeredMFP is or is not adequate.

## 16. Prototype plan

### Prototype A: WOFOST lineage reconstruction

Purpose: answer “did we understand WATFDGW correctly?”

Characteristics:

- isolated from SWAP5 production kernel;
- one-day reference step;
- historical dry/wet flow rules;
- historical 0.50 upward limiter;
- historical field-capacity/storage limits;
- same-material and heterogeneous-interface bisections;
- optional reconstruction of selected historical groundwater cases where reference inputs/results can be recovered;
- regression against WATFDGW report cases and current PCSE free-drainage behavior where semantics overlap.

No architectural design is inferred from this mode.

### Prototype B: SWAP5 LayeredMFP candidate

Purpose: answer “is the reduced-order principle physically useful relative to FullRichards?”

Characteristics:

- SWAP hydraulic material provider;
- conserved layer storage;
- generic `[t0,t1]`;
- solver-neutral top, distributed sink/source and bottom boundary inputs;
- explicit trial result and mass ledger;
- F-KT-compatible no-mutation semantics;
- process-facing reconstructed `theta` and `h`;
- diagnostics for every limiter, interface iteration and internal substep;
- optional bottom response/tangent experiment.

The prototype should be written so that it can later be discarded without affecting the production kernel if the physical qualification fails.

## 17. Qualification matrix

### A. Lineage reconstruction

- WATFD free-drainage sanity cases for provenance only;
- WATGW/SUBSOL stationary groundwater sanity cases for provenance only;
- selected WATFDGW free-drainage cases from the 2012 report;
- selected WATFDGW groundwater cases when exact inputs/reference outputs are available;
- PCSE `WaterBalanceLayered` daily free-drainage A/B cases;
- compare layer water contents, interlayer flows, bottom flow, surface storage and cumulative balance.

### B. Constitutive and interface oracle

For every admitted SWAP hydraulic material/model:

- `theta(h)`;
- `h(theta)` round trip;
- `K(h)`;
- optional `C(h)`;
- MFP high-accuracy reference integral;
- dry and saturated limits;
- same-material face flux;
- heterogeneous interface head continuity;
- heterogeneous interface flux continuity;
- solver bracket/failure behavior.

### C. FullRichards physical comparisons

Hydraulic basics:

- hydrostatic profile;
- free drainage;
- infiltration in dry sand;
- infiltration in clay;
- drainage after saturation;
- capillary rise;
- falling groundwater level;
- rising groundwater level;
- varying groundwater level.

Heterogeneity:

- sand over clay;
- clay over sand;
- strong K-contrast layer;
- strong retention-contrast layer;
- exploratory thin transition layers.

Atmosphere/crop:

- evaporation only;
- root uptake;
- drought stress;
- wet period followed by drought;
- long drought followed by intense rainfall.

Difficult cases:

- heavy clay/B12-like columns;
- ponding and runoff interaction;
- perched-water tendency;
- rapid bottom-head changes;
- later, matrix-only isolation of macropore/crack cases before any combined-physics claim.

### D. Outputs compared

At minimum:

- `theta(z,t)`;
- reconstructed `h(z,t)`;
- vertical `q(z,t)`;
- bottom flux;
- recharge;
- capillary rise;
- drainage;
- evaporation;
- transpiration;
- layer/root uptake;
- storage;
- surface fluxes;
- complete water balance;
- timestep sensitivity;
- runtime and work counters.

Do not qualify on crop yield or end-state storage alone.

### E. Time and transaction tests

- one interval versus two half intervals;
- logarithmic timestep/event-scale sweep from short event-resolving steps toward daily scale;
- repeated same base-state trial determinism;
- rejected trial leaves committed state unchanged;
- retry from committed state reproduces the correct physical trajectory;
- A/B/A order independence;
- scratch poisoning/reset;
- exact internal face antisymmetry;
- closed-profile zero-source conservation.

### F. MODFLOW/interface tests

- prescribed `H_b` sweep and returned `q_b`;
- mass ledger at each bottom-boundary trial;
- local monotonicity of `q_b(H_b)`;
- analytical/implicit tangent versus central finite difference;
- explicit detection of limiter switches where tangent is unavailable;
- predictor/corrector over generic coupling windows;
- rollback and rerun from the same committed SWAP state;
- check `H_SWAP = H_MF` and `q_SWAP = -q_MF` within qualified numerical tolerance while water mass closes exactly.

### G. MultiSWAP performance tests

Use homogeneous and deliberately mixed batches at increasing column counts, including at least hard-tail ensembles. Record:

- operations/constitutive evaluations per layer-step;
- local interface iterations;
- internal substeps;
- limiter activations;
- retries;
- p50/p95/p99/max wall cost per column/window;
- persistent bytes per column;
- scratch bytes per worker;
- branch/regime distribution;
- throughput versus FullRichards;
- tail-cost ratio and predictability.

No performance qualification should rely only on mean runtime.

## 18. Open scientific questions

1. Is `max(dry, wet)` the best reduced closure when calibrated against SWAP FullRichards across both dry redistribution and gravity-dominated wet flow?
2. Can the historical fixed 0.50 upward limiter be replaced by a timestep-aware conservative criterion without degrading capillary-rise behavior?
3. Is field capacity a defensible transport limiter in the SWAP5 candidate, or should it disappear from the transport law except where an explicitly modeled process requires it?
4. What is the best saturated/partially saturated state representation when a groundwater table moves through a coarse LayeredMFP layer?
5. How coarse may layers be before root uptake, evaporation fronts or strong hydraulic transitions are misrepresented?
6. Conversely, how thin may layers be before the reduced closure becomes timestep-limited enough to lose its performance advantage?
7. Does a unique and well-conditioned interface-head root exist across all SWAP hydraulic model combinations intended for LayeredMFP?
8. Can `dq_b/dH_b` be computed robustly through multiple internal substeps and active limiters?
9. Which process-facing head accuracy is actually required by irrigation, drainage, oxygen stress, crop stress and other modules?
10. What empirical envelope can be stated in terms of dimensionless hydraulic/time-scale indicators rather than soil names alone?
11. Can a conservative error indicator detect when LayeredMFP leaves its qualified envelope without comparing to FullRichards at runtime?
12. What should happen architecturally when an explicitly selected LayeredMFP run is outside its admitted envelope? This must be an explicit model/configuration decision, not a hidden execution-policy fallback.

## 19. SWAP Core Architecture Invariant audit

| Invariant | Assessment | Feasibility consequence |
|---|---|---|
| 1 one kernel | COMPATIBLE | LayeredMFP is another solver implementation inside the same kernel contract, not another SWAP version. |
| 2 kernel no I/O | REQUIRED | Prototype and target use data objects/providers only. Historical ITASK/file concerns are not ported. |
| 3 explicit data separation | COMPATIBLE | state, parameters, forcing, numerical config and result remain separate. |
| 4 compact persistent state | STRONG FIT | conserved layer storage is the principal per-column state. |
| 5 scratch per worker | STRONG FIT | face arrays, MFP values, brackets and trial buffers are worker/job scratch. |
| 6 scalable layout | STRONG FIT | SoA/material-template batching is natural. |
| 7 transaction steps | REQUIRED GATE | solver returns trial only; F-KT owns commit/rollback. |
| 8 cheap recomputation/warm start | STRONG FIT | local trial scratch can be reused, physical restart always from committed state. |
| 9 generic time | WOFOST GAP, TARGET REQUIREMENT | daily assumption must be removed and requalified. |
| 11 coupling core functionality | COMPATIBLE | bottom response, rollback and interface diagnostics are designed from prototype stage. |
| 12 explicit groundwater interface | CONDITIONAL | semantic design fits; prescribed-head common route is not currently fully qualified. |
| 13 mass absolute | HARD GATE | one conservative face ledger, no post-update clipping loss. |
| 14 interface sensitivities | PROMISING, UNPROVEN | local closure may make tangents cheaper; must be verified. |
| 15 coupling cost | PROMISING | local response may avoid multiple full column solves. No performance claim yet. |
| 16 MultiSWAP primary | STRONG FIT | compact state and bounded local work are attractive, benchmark required. |
| 18 deep vadose external | COMPATIBLE | LayeredMFP does not absorb the transfer-zone responsibility. |
| 20 alternative solvers | PRIMARY PURPOSE | explicit `FullRichards / CoarseRichards / LayeredMFP` implementations behind one contract. |
| 21 reuse SWAP physics | REQUIRED | common hydraulics, root sinks, drainage and surface processes. |
| 22 no HeadCalc internals | REQUIRED | consume/produce solver-neutral hydraulic provider/view only. |
| 23 physics vs policy | HARD RULE | LayeredMFP selection is explicit; REFERENCE/BALANCED/THROUGHPUT never switch models silently. |
| 24 predictable cost | PROMISING | local iterations/substeps can be bounded and diagnosed; no silent physics fallback. |
| 25 reference mode | REQUIRED | FullRichards remains scientific reference throughout qualification. |
| 26 diagnostics | REQUIRED | per-step route, substeps, face iterations, limiters, retries, cost and balance. |
| 27 optional functionality scales | STRONG FIT | no MFP/solver scratch stored in inactive columns. |
| 28 runtime/coupler composition | REQUIRED | tiles, MODFLOW mapping and deep-vadose routing stay outside solver. |
| 29 no silent dependencies | WOFOST GAP, TARGET REQUIREMENT | remove day/calendar/file/direct-MODFLOW assumptions. |
| 30 audit every change | REQUIRED | maintain explicit WOFOST-to-SWAP5 deviation ledger and qualification mapping. |

Additional invariants 10, 17 and 19 are also compatible: generic coupling windows remain possible; tile aggregation remains runtime-owned; deep-vadose/direct-coupling transitions must retain the common mass ledger.

## 20. Feasibility decision

### Decision: GO_PROTOTYPE

Evidence is sufficient to justify an isolated prototype because:

- the MFP concept and historical algorithm are documented in enough detail to reconstruct;
- current WOFOST still treats the layered balance as a relevant reduced-complexity model class;
- SWAP already has the constitutive hydraulic machinery needed to avoid duplicate soil physics;
- SWAP5 already reserves a reduced-order solver behind the common interface;
- the state/scratch structure is well aligned with MultiSWAP;
- bounded local solves offer a credible route to better tail-cost predictability;
- direct bottom response and tangents appear technically plausible.

The decision is **not** `GO_WITH_RESTRICTIONS` because no production restriction envelope has yet been scientifically established. It is also not `NEEDS_MORE_EVIDENCE`, because the remaining uncertainty is best resolved by the proposed prototype and FullRichards comparison rather than by more desk study alone.

### Explicit non-claims

This workunit does not claim that:

- WATFDGW is physically equivalent to Richards;
- current PCSE implements the historical groundwater branch;
- LayeredMFP is already valid for shallow groundwater or MODFLOW coupling;
- the historical 0.50 limiter or field-capacity rules are scientifically optimal;
- LayeredMFP is iteration-free;
- any particular speedup factor is achieved;
- any difficult clay, ponding, perched-water or strong-contrast regime is already excluded or admitted;
- prescribed bottom head is presently admitted on the SWAP5 common production route;
- the Appendix C WATFDGW source may be copied into SWAP5 without a separate license/provenance check.

The next scientific gate is therefore not production integration. It is a reproducible standalone prototype that first proves lineage reconstruction and then tests the reduced-order hypothesis against FullRichards.
