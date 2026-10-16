# F-ROMV computational-value go/no exploration

**Workstream:** F-ROM  
**Work unit:** F-ROMV  
**Status:** CONDITIONAL GO FOR NARROW RESEARCH; NO PRODUCTION ROM AUTHORITY  
**Canonical reconciliation base:** `50e7d1dece5b75d0103459d5c118d03a2665eea3` on `integration/f-ci-canonical`  
**Scope:** computational-value reassessment after the terminal ROM-1 `MATERIAL_SPECIFIC_ONLY` result

## 1. Decision in one paragraph

The current evidence does **not** justify a general SWAP5 reduced-order solver, a cross-material ROM, or a neural surrogate replacement for Reference Richards or RossFast. It does justify one further, deliberately narrow research question: whether **template-local, conservative reduced dynamics can create net value in repeated many-query workloads where the same qualified physical template is advanced many times from different reachable states and forcings**. This is compatible with, rather than a reversal of, ROM-1's terminal `MATERIAL_SPECIFIC_ONLY` result. The decisive missing evidence is computational, not representational: the repository does not yet contain a formally qualified end-to-end MultiSWAP performance decomposition showing that soil-water solve cost remains dominant after current RossFast, batching, scheduling and coupling optimizations. Therefore F-ROMV authorizes only a minimal discriminating experiment. It does not authorize production ROM implementation.

## 2. Terminology boundary

F-ROMV uses the terms as follows.

- **Numerical acceleration** preserves the governing model and accepted numerical semantics while executing them faster, for example optimized constitutive kernels, improved nonlinear strategy, batching, SIMD, parallelism, caching or RossFast where already scientifically admitted.
- **Emulator/surrogate modelling** approximates a map from inputs to requested outputs. It need not possess a reduced prognostic state or reproduce the model's internal dynamics.
- **Reduced-order modelling in the strict sense** replaces the full prognostic state/dynamics with a lower-dimensional state and an online evolution law.
- **Physical model reduction** simplifies the governing process representation itself, for example a conceptual bucket or two-layer formulation.
- **Parameter reduction** reduces the dimension of uncertain or variable input space, not necessarily the dynamic state.
- **State-space reduction** compresses the prognostic state while aiming to retain future-relevant information.
- **Operator approximation** approximates the discrete or continuous evolution/input-output operator, for example with Operator Inference or a neural operator. It can be a ROM, but is not automatically one.

A method is not admitted as a useful SWAP5 ROM merely because its state or network is small or its RMSE is low.

## 3. Computational problem definition

The only currently defensible ROM target is conditional:

> **Repeated advancement of many SWAP5 columns that share one already-qualified physical/model template, but occupy different reachable hydraulic states and experience different admitted forcing histories, when full-order or RossFast soil-water advancement remains a material share of end-to-end cost after ordinary numerical optimization and runtime batching.**

This problem has four necessary conditions.

1. **Many-query amortization.** The same template or narrowly defined regime is solved often enough that trajectory generation, fitting and qualification can be amortized.
2. **Solver-cost dominance.** Soil-water advancement, including difficult-tail retries, must remain a material part of wall time after current direct acceleration.
3. **Repeated low-dimensional structure.** Reachable accepted states must occupy a compact future-relevant state space within that template.
4. **Fail-closed composition.** Leaving the qualified state/forcing/boundary domain must route to RossFast or Reference rather than silently extrapolate.

If any of these conditions fails for the target workload, the ROM line is a no-go for that workload.

A single ordinary SWAP column run is **not** presently a convincing ROM problem. A general cross-material regional surrogate is also not supported.

## 4. Repository performance evidence

### 4.1 MultiSWAP measurement architecture

The canonical MP workload catalog remains measurement-first. It defines:

- MP-B01 single-column decomposition;
- MP-B02 homogeneous scaling at 64, 1024 and 16384 columns;
- MP-B03 mixed-template runtime;
- MP-B04 a difficult hydraulic tail with Newton, Jacobian, linear-solve, backtracking and retry counters;
- MP-B05 execution-class routing;
- MP-B06 optional-physics cost.

The architecture explicitly requires per-column cost distributions, p90/p95/p99/max, the CPU share of the slowest one percent, retry incidence, batch divergence and separate persistent-state/worker-scratch accounting. This is the right evidence base for a ROM value decision.

However, the historical MP performance line still records the formal CPU baseline as infrastructure-blocked. MP-5 through MP-7 showed that the shared host could not meet the preregistered 1% timing-resolution target; MP-8 introduced an isolated-runner contract but did not establish a production CPU baseline. Consequently there is no repository-qualified end-to-end MultiSWAP cost decomposition that can presently prove a ROM bottleneck.

### 4.2 Current RossFast competitor

F-ROSS24 materially changes the comparator. On its bounded 216-case E0 characterization:

- 213 cases were paired-valid;
- RossFast was route-valid in all 216;
- the solver-only mean RossFast/Reference CPU ratio was approximately 0.823;
- the corresponding mean Reference/RossFast solver speedup was approximately 1.216;
- whole-child CPU and wall-time improvements were only approximately 4.36%;
- K2 accounted for 212/216 cases;
- K4/K8 fallback cases were individually slower than Reference;
- the result is explicitly a GitHub-hosted **screening**, not a formal end-to-end performance claim.

This means a ROM may not claim value by beating legacy Reference in isolation. It must be compared with the **then-current RossFast route** and with direct batching/parallelism. The F-ROSS24 difference between solver-only and whole-child improvements also warns that accelerating the solver can have little system value if non-solver work dominates.

### 4.3 Coupling already has a response reduction

F-GC40 already composes tile-local affine groundwater responses

`q_i(H) = q_i* + (u_i/dt)(H-H_i*)`

into a deterministic cell-level affine response. F-GC33 then converts that response exactly to MODFLOW6 `HCOF/RHS` terms. Therefore a ROM whose principal purpose is merely to approximate the same local `q(H)` relation would duplicate existing coupling architecture.

A groundwater-coupling ROM becomes interesting only if later profiling shows that repeated **nonlinear SWAP corrector/predictor advancement**, beyond the existing tangent/affine response, dominates coupled runtime.

## 5. Existing F-ROM scientific evidence

F-ROM-P correctly separated state sufficiency from computational value. ROM-0 then established accepted Reference-Richards trajectory authority and measured temporal/vertical numerical floors.

ROM-1 closed as `MATERIAL_SPECIFIC_ONLY`.

For B01:

- reachable-state library: 768 accepted states;
- discovery/held-out split: 512/256;
- Z1, Z2, Z4 and Z8 were predictively ambiguous on discovery evidence;
- the enriched `Z8_PLUS_G8` coordinate has dimension 9;
- discovery state separation: zero collisions;
- held-out inclusive state separation: zero collisions;
- no held-out-driven retuning;
- state sufficiency passed **within B01 scope**.

For B14 transfer:

- the frozen coordinate produced 351 state-space collisions;
- a frozen subset of 8 collision pairs was subjected to 192 future-probe records;
- those probes produced zero storage-ambiguity records at the frozen scale;
- therefore predictive insufficiency was **not** established, but predictive sufficiency was also **not** established;
- cross-material transfer was not admitted.

That distinction matters. The evidence does not prove that B14 intrinsically requires high-dimensional state. It proves that the B01-derived representation is not qualified for B14. The existing proposition correctly stopped before ROM-2.

The new computational-value hypothesis is therefore explicitly **template-local**. It does not reclassify the B14 result or reopen a global ROM claim.

## 6. Literature/state-of-the-art picture

The literature confirms that fast Richards surrogates are possible, but it does not remove the SWAP5 qualification problem.

### 6.1 Projection and reduced-basis methods

Galvis and Kang (2014, Journal of Computational and Applied Mathematics, DOI 10.1016/j.cam.2013.10.010) developed a reduced-basis/multiscale method for Richards flow in highly heterogeneous porous media. This establishes that reduced-basis ideas are not novel by themselves.

A 2015 thesis applying Petrov-Galerkin POD directly to Richards reported that the nonlinear terms prevented significant speedup without additional treatment. This is consistent with the general hyper-reduction issue: projecting the state is insufficient when nonlinear constitutive/residual evaluation still requires full-order work.

Recent hydro-mechanical ROM literature uses POD-DEIM specifically because nonlinear full-order assembly otherwise remains an online bottleneck.

### 6.2 Nonintrusive surrogates and neural operators

Kamil, Soulaïmani and Beljadid (2025, Journal of Computational Physics, DOI 10.1016/j.jcp.2025.114156) use a physics-informed DeepONet to map initial moisture and emitter flux to transient Richards solutions. Once trained, inference is very fast, but extrapolation required fine-tuning with physics or data.

Zhu et al. (2026, Advances in Water Resources, DOI 10.1016/j.advwatres.2026.105487) combine a CNN surrogate with a finite-difference Richards residual and test variable initial/boundary conditions across twelve soil types against HYDRUS-1D. The work explicitly treats error accumulation, transfer learning and catastrophic forgetting. It is strong evidence that a parameterized Richards surrogate is technically feasible, but it remains a proof-of-concept surrogate for its tested 1D settings rather than evidence of fail-closed, mass-ledger-preserving general SWAP capability.

A 2026 review of physics-informed methods in porous-media flow identifies operator learning as useful for many-query problems, but still lists robustness, scale-up, uncertainty and deployment integration as open issues.

### 6.3 Surrogates for repeated inference/UQ

Gaussian-process surrogates have been combined with iterative Ensemble Kalman filtering for hydraulic-parameter estimation in unsaturated flow. Other work combines nonlinear dimension reduction and GP inference for UQ, including a 3D Richards example. This supports **ensemble/inverse workflows** as a plausible surrogate target, but those are output-emulator uses and do not automatically justify replacing the SWAP prognostic state.

### 6.4 Hybrid ROM-assisted full-order solving

Kadeethum et al. (2022, Scientific Reports, DOI 10.1038/s41598-022-22407-6) use ROM predictions as nonlinear-solver initial guesses, including a Richards problem. Across their four nonlinear PDE examples they report 18-73% nonlinear-solver acceleration while retaining the full-order solve as authority. This is particularly relevant to SWAP because it separates **approximate prediction** from **accepted physics**.

### 6.5 Direct solver/HPC competition remains strong

Richards itself is not an automatic justification for a ROM. Direct numerical methods continue to scale and improve. For example, a Code_Saturne CDO implementation demonstrated nearly linear HPC scaling to 98,304 cores on a 1.7-billion-cell Richards problem. That problem is very different from SWAP's independent 1D columns, but it demonstrates the larger point: ROM must win against direct numerical and parallel solutions for the actual target workload, not against a hypothetical unoptimized baseline.

## 7. Hydrological and numerical barriers

A SWAP ROM is unusually vulnerable to failures that a global RMSE can hide.

### Strong constitutive nonlinearity

`theta(h)`, `K(h)` and their derivatives can vary over orders of magnitude. Dry states and wet-end states therefore occupy very different numerical and physical regimes.

### Wetting fronts and near-saturation transitions

Sharp moving gradients are difficult for global linear bases. Near saturation, small pressure-head errors can change boundary behavior or flux substantially.

### Direction reversals and groundwater interaction

The accepted ROM-0 laboratory deliberately included lower-head rise/fall and flow-direction reversal. These are exactly the situations where a low-dimensional state must encode enough profile information for future fluxes, not merely reproduce current storage.

### Hysteresis and memory

If hysteresis is active, current `theta` or storage alone may not identify the hydraulic branch. Reversal history becomes prognostic information. A ROM must either carry that memory explicitly or be restricted to non-hysteretic capability.

### Threshold processes

Ponding/runoff activation, stress onset, oxygen limitation, drainage switching, freezing and other process thresholds can convert a small state error into a discrete process difference. This makes event classification and event timing first-class error metrics.

### Optional and coupled physics

Macropore state, thermal/frost state, solute state, crop/root state and management state are not represented by the initial nine-dimensional B01 hydraulic coordinate. A pure-hydraulics ROM cannot silently claim those capabilities.

### Transaction/retry semantics

Training data must come from **accepted committed trajectories**, not failed solver attempts. A closure trained on attempt states can learn numerical policy rather than physical dynamics.

### Accumulated mass and flux bias

A tiny systematic one-step flux bias can create unacceptable seasonal storage or groundwater-exchange drift. Exact or explicitly bounded ledger accounting is therefore more important than a small instantaneous profile RMSE.

## 8. Error and output hierarchy

For any future experiment, the following quantities are treated differently.

**Hard or nearly-hard invariants**

- accepted total water accounting;
- nonnegative/physically admissible water contents;
- committed-state/transaction semantics;
- correct boundary-mode identity;
- fail-closed material/template identity;
- no hidden correction flux used solely to erase accumulated ROM mass error.

**Hydrologically consequential observables**

- cumulative top and bottom exchange;
- sign changes of bottom flux;
- timing of wetting/saturation/ponding or stress events;
- total, upper-band and lower-band storage;
- extrema and recovery time after forcing transitions;
- long-horizon drift.

**Potentially approximable diagnostics**

- full pressure-head and moisture profiles, only if future predictive sufficiency remains demonstrated;
- local instantaneous flux details that do not alter downstream process activation or cumulative budgets.

RMSE alone is never a sufficient admission metric.

## 9. Candidate ROM directions

### A. Template-local conservative state-space ROM with hybrid fallback

This is the strongest strict-ROM candidate.

Use one qualified physical/model template at a time. Start from the already supported B01 `Z8_PLUS_G8` representation rather than assuming a global POD basis. Learn or derive a low-dimensional evolution law with forcing/boundary inputs, carry total storage or an equivalent conservative ledger explicitly, and hard-gate material identity, boundary mode, timestep and state/forcing domain. Outside-domain cases route to RossFast/Reference.

Candidate closures include low-order Operator Inference, constrained state-space regression, local Gaussian-process dynamics or another simple structured model before any neural architecture is considered.

**Why it remains plausible:** MultiSWAP naturally contains repeated columns and can amortize per-template offline work; ROM-1 already provides bounded within-material state-sufficiency evidence.

**Why it is not yet admitted:** no closure evidence, no long-horizon evidence, no qualified computational break-even, no proof that enough columns share a template, and no end-to-end bottleneck proof.

### B. ROM-assisted full-order nonlinear solving

Use a reduced predictor only to generate an improved full-state initial guess, timestep proposal or regime estimate; then let Reference/RossFast execute and own accepted physics.

**Why it is attractive:** scientific risk is much lower because mass balance and acceptance remain with the admitted solver. Literature shows this can reduce nonlinear iterations and rescue some difficult nonlinear solves.

**Why it may be redundant:** SWAP's current RossFast route already attacks numerical cost, and this chat is not allowed to own RossFast/solver research. This direction is retained only as a comparison or handoff if the discriminating experiment shows a large difficult-tail cost that current solver work does not remove.

### C. Output-specific surrogate for many-query ensemble/data-assimilation work

For calibration, UQ, data assimilation or optimization, emulate only a declared set of outputs rather than the whole prognostic state. Gaussian processes, response surfaces or neural operators may be suitable.

**Why it is plausible:** the literature already shows strong value of surrogates in repeated inverse/UQ unsaturated-flow workflows.

**Why it is not a general SWAP ROM:** it is an emulator. It cannot automatically replace stateful SWAP evolution or coupled process physics.

## 10. Directions rejected at this stage

- **One global cross-material SWAP ROM:** rejected by current ROM-1 qualification boundary.
- **Production neural operator as first choice:** rejected because architecture popularity is not evidence; current literature still requires bounded training domains/fine-tuning and does not supply SWAP's mass/event/fail-closed guarantees.
- **Global linear DMD:** rejected as first candidate because strongly forced nonlinear wetting/drying and switching processes violate the simplest linear-evolution assumptions.
- **Plain POD/Galerkin without hyper-reduction:** rejected because reducing state dimension alone does not remove nonlinear constitutive/residual cost.
- **PINN as a per-run replacement solver:** rejected as the initial value proposition. Instance-specific training/optimization competes poorly with an already available 1D numerical solver unless a many-query operator is actually learned.
- **Groundwater `q(H)` surrogate alone:** rejected as duplicated scope because F-GC40/F-GC33 already own an affine response and exact backend transformation.
- **Average-output emulator called a ROM:** rejected terminologically and scientifically if it cannot retain future-relevant state, cumulative water accounting and regime transitions.

## 11. Minimal discriminating experiment

The next experiment must answer **value before architecture**.

### Target

One B01-qualified physical template, using accepted current-canonical trajectories and held-out forcing/reversal histories. This intentionally tests the only material for which state sufficiency is already qualified. It does not claim transfer.

### Competing routes

1. current admitted Reference Richards;
2. current admitted RossFast where the B01 case lies inside its qualified envelope;
3. a scientifically consistent spatially coarsened Richards comparator;
4. one deliberately simple conservative nine-state closure using `Z8_PLUS_G8`;
5. the same reduced route with fail-closed fallback to RossFast/Reference.

The first closure should be structured and low-capacity, for example linear/bilinear Operator Inference or constrained regression with explicit forcing terms. A neural operator is not the first discriminant.

### Workload

Use many independent B01 columns with diverse **held-out reachable states and forcings**, not identical copies. Run enough columns that online costs are measurable and an offline/online break-even can be estimated. Repeat short one-step predictions and longer rollouts containing wetting, drying, lower-head movement and direction reversals.

### Required scientific metrics

- exact or hard-gated water ledger;
- cumulative top/bottom exchange error;
- total and band-storage errors relative to the ROM-0 numerical floor;
- bottom-flux sign error and reversal timing;
- event timing where a boundary regime changes;
- long-horizon accumulated drift;
- invalid-state count;
- outside-domain detection rate;
- fallback fraction.

### Required computational metrics

- online CPU per accepted interval;
- end-to-end wall time for the many-column workload;
- p50/p95/p99/max per-column cost;
- share of cost from the slowest 1%;
- fallback overhead;
- offline trajectory/fitting cost;
- amortization count `N_break_even = C_offline / (C_baseline_online - C_hybrid_online)`, when the denominator is positive;
- confidence/resolution floor on timing from an admitted isolated host.

### Kill criteria

The research line stops if any of the following occurs:

1. the simple closure cannot survive held-out reversal/long-horizon tests without hydrologically meaningful event or cumulative-budget error;
2. safe OOD gating causes fallback so frequently that online cost is not materially below the best direct route;
3. spatially coarsened Richards lies on an equal or better cost-error frontier;
4. RossFast plus existing batching removes enough cost that realistic amortization cannot recover the ROM offline cost;
5. the required state/domain partition proliferates into many special cases, destroying practical template-level reuse.

### Positive criterion

A positive result requires all of the following, not merely low RMSE:

- hydrologic error remains inside a predeclared envelope informed by the ROM-0 numerical floor;
- no hidden mass correction is needed;
- OOD behavior is fail-closed;
- held-out long-horizon and reversal evidence passes;
- online cost is resolved below the best admissible direct comparator;
- break-even lies within a realistic repeated-workload size.

## 12. Go/no-go

### General production ROM

**NO-GO.**

There is no current authority for a general production ROM, no admitted cross-material representation, no closure, and no qualified end-to-end performance bottleneck demonstrating system value.

### Further ROM research

**CONDITIONAL GO, one narrow experiment only.**

The justified question is not whether SWAP can be replaced by a generic surrogate. It is whether **material/template-local state reduction can exploit repeated structure already present in a many-column workload and remain conservative, fail-closed and cheaper than RossFast/direct alternatives after amortization**.

If the minimal discriminating experiment fails, F-ROMV should close as `ROSSFAST_OR_DIRECT_RUNTIME_VALUE_DOMINATES`, `COARSE_RICHARDS_SUFFICIENT` or `NO_PRACTICAL_AMORTIZATION`, whichever the evidence supports. There should be no automatic progression to a more complex neural architecture.
