# Five-paper novelty stress test

Date: 2026-09-18  
Status: literature-based adversarial review checkpoint  
Branch at reconciliation start: `research/phd-five-paper-manifests-20260918@0434e0ee31678036bb79f2acd17b8168bc33cfa2`

## Purpose

This note deliberately tries to falsify the novelty claims of the five prospective PhD papers before further primary experiments are designed.

It does not admit a publication claim. A literature search can expose collisions with prior art but cannot prove novelty. The purpose is therefore narrower:

1. identify the strongest prior-art collision for each paper;
2. state which tempting claims are already occupied;
3. retain only a contribution that remains scientifically testable after that collision;
4. specify the comparator or control needed to distinguish that contribution;
5. sharpen the paper firewalls so that one primary inference is not reused by another paper.

Frozen experiment manifests remain authoritative for already preregistered work. This note proposes narrower research questions where necessary; it does not silently rewrite earlier preregistration.

## Stress-tested master matrix

| Paper | Strongest prior-art collision | Claims that should not be made | Defensible contribution after stress test | Required discriminator | Current assessment |
| --- | --- | --- | --- | --- | --- |
| PUB-ME | WaterGAP legacy reprogramming; FMI state save/restore; MOOSE stateful/rollback semantics; differential fault injection of modernized scientific software | modernization itself; rollback/checkpointing; old/new state storage; fault injection itself | prospective causal evidence that explicit candidate-to-accepted scientific-state authority changes which scientifically consequential contamination faults reach accepted history, under matched B0/B1 functionality | paired B0/B1 fault injection with no-fault equivalence and at least two mechanistically distinct boundary-crossing fault families | survives, but only as causal fault-containment study |
| PUB-SQ | Ross versus Newton literature; modern mass-conservative Richards integration; GWSWEX dual-solver API; general verification/validation and solver benchmarking practice | Ross algorithm; generic Ross-versus-Newton benchmark; dual-solver API; reference comparison as novelty | candidate-independent, prospective model-level admission of a solver over a bounded state/forcing/material domain, with fail-closed exclusions and cost only after equal scientific error is established | untouched inside/boundary/outside holdouts under thresholds frozen without candidate outcomes; REF-HIGH and equal-error cost | survives and is increasingly well evidenced; generality must not be overstated |
| PUB-GC | SWAP-MODFLOW coupling; SIMGRO shared-state coupling; HYDRUS-MODFLOW iterative feedback; current MetaSWAP-MODFLOW6 coupling; broader multirate waveform coupling | SWAP-MODFLOW coupling; N:1 mapping; iterative two-way feedback; different internal time steps; checkpoint/replay or time-window iteration as generic inventions | hydrologically explicit evidence for which finite-window exchange and acceptance semantics are necessary to obtain conservation, convergence and time-partition consistency in independently integrating vadose and groundwater models | fair established-style relaxed/sequential comparators, whole-window versus terminal exchange, window refinement to GC-REF, and MODFLOW6 transfer | survives only if the strict semantics produce measurable consequences at matched subsystem physics/error |
| PUB-RC | Aitken, Broyden, IQN-ILS and other black-box quasi-Newton partitioned coupling; multirate quasi-Newton waveform iteration | invention of quasi-Newton coupling; tangent/secant acceleration itself; black-box acceleration itself | an information-content and cost study asking whether a hydrologically interpretable low-order whole-window response provides net benefit beyond strong generic black-box acceleration | R0/R1/R2/R3 at identical PUB-GC error/conservation gates, including response acquisition cost and unseen holdouts | genuinely conditional; merge into PUB-GC if R1 matches R2/R3 |
| PUB-SG | decades of vadose-zone upscaling showing effective/equivalent parameters depend on flow regime, boundary condition and water-table position; existing multiple-SVAT-to-one-groundwater-cell schemes | N:1 itself; generic nonlinear upscaling failure; claim that equivalent parameters are regime dependent | isolate whether two-way dynamic shared-groundwater feedback changes the cross-regime transferability of an equivalent full-process vadose column, and identify the response transitions that create any additional aggregation-error boundary | explicit heterogeneous N:1 truth, frozen equivalent column, prescribed-head or one-way control, dynamic shared-groundwater treatment, holdout regime transitions, error decomposition | current RQ is too broad; standalone paper survives only after this narrowing |

## PUB-ME: PRESERVE

### Prior-art collision

The generic modernization story is occupied. Nyenah et al. (2025) document the process and value of reprogramming the WaterGAP legacy global hydrological model, including modularization and scientific-output preservation.

State save/restore and lagged state are also established mechanisms. FMI 3.0.2 standardizes `GetFMUState` and `SetFMUState`, including repeated simulation from a restored communication point. MOOSE explicitly maintains stateful old/older properties and restores postprocessor values when a timestep is rejected before retry.

Fault injection is not novel either. Coleman et al. (2026, preprint) use differential fault injection to validate modernized GAMESS kernels.

### Consequence

PUB-ME must not claim that candidate/accepted separation, rollback, state restoration, modernization validation or fault injection are new mechanisms.

The potentially publishable claim is causal:

> under matched scientific functionality and matched conventional tests, explicit authority over the transition from candidate execution to accepted scientific history prevents or earlier localizes a prospectively specified class of scientifically consequential state-contamination faults.

That is narrower than "transactional architecture is better". It is also falsifiable.

### Recommended RQ

> Which scientifically consequential state-contamination faults can escape matched regression and invariant testing during staged model modernization, and to what extent does explicit candidate-to-accepted scientific-state authority prevent or earlier localize them?

This is only a small wording change from the current manifest, but "earlier localize" is preferable to the broader "expose" because it maps directly to a measurable secondary endpoint.

### Required evidence

Primary support should require:

- no-fault B0/B1 scientific equivalence;
- prospectively frozen fault instances;
- at least two mechanistically distinct fault families crossing the candidate/accepted boundary;
- accepted-state contamination as the hard primary endpoint;
- detection boundary and latency as secondary endpoints;
- no claim based only on a fault that an ordinary added unit test would trivially detect before acceptance.

### Kill condition

If B0 and B1 behave the same for all valid boundary-crossing fault families, or if B1 allows contamination on a path it claims to contain, the causal paper should be narrowed or abandoned. The modernization case study can remain valuable without supporting the stronger mechanism claim.

## PUB-SQ: REPLACE

### Prior-art collision

Hassane Maina and Ackerer (2017) already compare Ross and Newton-Raphson approaches and time-stepping strategies for Richards' equation. Current work such as Bootsma, van der Ploeg and Weerts (2026) further raises the standard for mass conservation and temporal error analysis. GWSWEX v1.0 (2026) already places two interchangeable unsaturated-zone solvers behind a unified API and verifies them against HYDRUS-1D.

Therefore neither "two solvers in one model" nor "Ross can be faster than another Richards solver" is sufficient novelty.

General verification and validation practice also predates this study. Prospectively defined tolerances, reference refinement and performance-at-accuracy are good scientific practice, not an invention by themselves.

### What remains distinctive

The strongest remaining contribution is the application of a candidate-independent admission contract to an established full process model:

1. define the scientific state and forcing domain without looking at new candidate outcomes;
2. construct the Reference-stable common domain;
3. freeze tolerances from Reference behaviour;
4. execute untouched candidate holdouts;
5. narrow the admitted domain on any valid failure rather than averaging failures away;
6. test fail-closed behaviour outside that domain;
7. compare cost only within a common accepted-error band.

The live evidence now supports this design more strongly than at the beginning of the stress test. P2E11/P2E11R showed that the original Se=0.98 extension could not simply be carried across the material axis. P2E13 then constructed a 36-material Reference-only common state domain. P2E14 froze thresholds at prospectively selected Se anchors 0.65, 0.85 and 0.96. P2E15 subsequently admitted all 180 previously unobserved material-axis candidate cases within that frozen domain.

This chronology is scientifically more interesting than a broad equivalence statement because it demonstrates that the admissible comparison domain itself must be constructed independently of the candidate.

### Recommended RQ

> Under a prospectively frozen, candidate-independent scientific error contract, over what joint state, forcing and material domain can a numerically distinct Richards-equation solver be admitted as scientifically interchangeable within an established process model, and what computational advantage remains at matched scientific error?

The wording should remain explicitly conditional. "Scientifically interchangeable" must never mean universally interchangeable.

### Immediate experiment consequence

The next PUB-SQ primary design should be the already authorized inside/boundary/outside admissibility experiment. It should deliberately include:

- cases clearly inside the admitted domain;
- cases close to its scientifically defined boundary;
- predefined outside-domain cases such as excluded forcing/state classes where appropriate;
- no threshold changes after outcome inspection.

Only after the domain-boundary claim survives should equal-error performance become a primary claim.

## PUB-GC: COUPLE

### Prior-art collision

This paper faces the densest prior-art field.

Xu et al. (2012) already integrated SWAP and MODFLOW-2000 for shallow-water-table systems. Van Walsum and Veldhuizen (2011) describe SIMGRO coupling through shared state variables and explicitly address the accuracy/efficiency balance of coupled regional hydrology. Zeng et al. (2019) developed an iterative HYDRUS-MODFLOW feedback scheme across separated spatial and temporal scales, with rigorous interface water balance, relaxation and analysis of coupling error.

Current Deltares iMOD Coupler infrastructure also couples MetaSWAP and MODFLOW 6 iteratively. Public documentation and source show repeated MetaSWAP solve/exchange/MODFLOW solve/head-exchange operations within a MODFLOW time step. The public Python driver is enough to establish strong implementation competition, but not enough to conclude whether every internal MetaSWAP iteration is semantically an exact replay from one immutable accepted origin. That distinction must therefore be treated as an open comparison question, not asserted as prior-art absence.

Outside hydrology, waveform-iteration and partitioned multiphysics literature already covers repeated coupling over time windows, black-box subsolvers and different adaptive internal time steps. Time-window replay is therefore not safe as a generic numerical-method novelty claim.

### Consequence

PUB-GC cannot be framed as "a new SWAP-MODFLOW coupling" or "an iterative multirate coupling".

The strongest surviving question is empirical and semantic:

> Which finite-window exchange and acceptance semantics are actually necessary to make the composed hydrological result conservative, convergent and insensitive to admissible internal time-step partitioning?

The proposed strict contract is still a strong candidate mechanism:

- one accepted origin per coupling window;
- each subsystem evaluates a candidate response without authoritatively changing accepted history;
- exchange is defined over the whole window, not only by a terminal instantaneous quantity;
- one authoritative exchange ledger closes action/reaction;
- subsystem state commits only after coupled acceptance.

But these properties are not a publication result until fair comparators show a measurable consequence.

### Recommended RQ

> Which finite-window exchange and acceptance semantics are necessary for conservative, convergent and time-partition-consistent composition of independently time-integrating vadose-zone and groundwater models?

"Necessary" is intentionally stronger and more informative than simply asking whether a proposed contract is sufficient. The experiment matrix must determine which pieces matter and under which feedback regimes.

### Comparator requirements

A convincing PUB-GC should include, where scientifically fair:

- loose or sequential exchange;
- an established-style relaxed head/flux feedback comparator;
- terminal-flux exchange where the quantity is meaningful;
- restricted same-origin predictor/corrector;
- converged same-origin whole-window iteration;
- strict numerical reference construction via window/tolerance refinement.

The history-contaminated candidate comparator remains diagnostic only. It should not become a second PUB-ME paper inside PUB-GC.

### Publication threshold

The standalone methods claim survives only if at least one strict semantic choice changes a scientifically relevant outcome or robustness domain at matched subsystem physics/error, and the effect transfers to a minimal real MODFLOW 6 backend.

If all fair methods become indistinguishable once coupling windows are sensible, the broader numerical-method claim should be narrowed to a model-integration paper.

## PUB-RC: ACCELERATE

### Prior-art collision

Partitioned multiphysics has a mature acceleration literature. Aitken relaxation, Broyden-type methods, IQN-ILS and related interface quasi-Newton methods accelerate coupled black-box solvers using interface history. Delaissé et al. (2023) review this family explicitly. Kotarsky and Birken (2025) extend quasi-Newton waveform iteration to coupled problems with different adaptive time steps in the subsolvers.

Therefore derivative-informed or quasi-Newton coupling is not, by itself, a novelty.

### Contribution that survives

PUB-RC can remain distinct only as an information-content study:

> How much hydrologically meaningful interface information is worth exposing once a strong generic black-box accelerator is already available?

This is why the current R0/R1/R2/R3 ladder remains sound:

- R0: base residual/fixed-point information;
- R1: strong generic black-box acceleration, including Aitken and at least one serious quasi-Newton/history method;
- R2: local whole-window hydrological secant;
- R3: explicit local whole-window tangent;
- R4: richer response only if R2/R3 leave a demonstrated unresolved need.

### Recommended RQ

The current question largely survives:

> What is the lowest-order hydrologically meaningful whole-window response information that produces a reproducible net reduction in coupled-solve cost at matched coupled error and robustness beyond strong generic black-box acceleration?

"Net" matters because response acquisition is not free.

### Required endpoint

The primary endpoint should not be iteration count. It should be total work at the same accepted coupled error, including:

- SWAP evaluations;
- MODFLOW 6 evaluations;
- response/tangent evaluations;
- failed or safeguarded updates;
- coupling overhead;
- stable timing only as secondary evidence unless timing reproducibility is established.

### Kill/merge rule

If R1 matches R2/R3 after acquisition cost and safeguards are counted, that is a meaningful negative result. PUB-RC should then merge into PUB-GC or become thesis synthesis, not be forced into a standalone fifth article.

## PUB-SG: SCALE

### Prior-art collision

This is the paper whose current formulation changes most after the literature stress test.

The basic proposition that an equivalent representation may fail across hydrological regimes is old. Zhu and Mohanty (2002, 2003) show effective hydraulic behaviour changing with evaporation/infiltration conditions, boundary conditions and elevation above the water table. Vereecken et al. (2007) review effective and equivalent vadose-zone upscaling in heterogeneous soils. The 2019 review by Vereecken et al. concludes that grid-scale infiltration upscaling still lacks a consistent theoretical framework, but it also documents extensive prior knowledge that effective behaviour depends on subgrid heterogeneity and process regime.

Existing SIMGRO/MetaSWAP approaches also already permit multiple SVAT or vadose-zone units to interact with one groundwater representation. N:1 mapping itself is not new.

Therefore the current question:

> when does an equivalent single column cease to be transferable across hydrologic regimes?

is too broad to sustain a strong novelty claim.

### Sharpened scientific opportunity

The specific gap worth testing is the role of two-way dynamic shared-groundwater feedback.

With N explicit columns connected to one groundwater cell, the aggregate vadose response changes groundwater head, and that changed head feeds back into every column. This introduces an interaction path between subcolumns that is absent when groundwater head is prescribed. The scientific question is not merely whether heterogeneity matters, but whether this shared dynamic feedback creates or shifts a transferability boundary beyond the already-known dependence on boundary conditions and flow regime.

### Recommended RQ

> How does two-way dynamic shared-groundwater feedback alter the cross-regime transferability of a calibrated equivalent full-process vadose-zone column relative to explicit heterogeneous subcolumns, and which hydrological response transitions determine the resulting aggregation-error boundary?

This is materially narrower than the current manifest and should be treated as a proposed revision, not a retrospective reinterpretation of existing results.

### Critical new control

The experiment needs a causal control that the current matrix does not yet make prominent enough:

1. explicit heterogeneous N:1 columns with shared dynamic groundwater;
2. the same columns under a prescribed groundwater-head trajectory or otherwise one-way groundwater boundary;
3. a calibrated equivalent full SWAP column, frozen after calibration regime R_A;
4. holdout regimes that cross drainage/capillary-rise, groundwater-depth, forcing and root-zone-response transitions.

The difference between dynamic shared-groundwater and prescribed-head treatments helps isolate the incremental feedback mechanism. Without that control, any observed transferability failure can be dismissed as the boundary-condition dependence already established in the upscaling literature.

### Standalone-paper kill rule

A standalone PUB-SG is weak if:

- transferability failure is fully explained by known prescribed-boundary upscaling behaviour;
- two-way groundwater feedback adds no reproducible shift in the error domain;
- differences remain below coupling/solver/reference uncertainty;
- no interpretable response-transition boundary emerges.

A negative result can still be scientifically useful for the thesis and practical model design.

## Revised paper firewalls

### ME versus GC

PUB-ME owns the general causal inference that candidate-to-accepted authority contains scientific-state faults.

PUB-GC may rely on accepted-origin replay, but its primary inference must be hydrological coupling accuracy, conservation, convergence or time-partition consistency. A deliberately history-contaminated run is diagnostic, not a primary GC novelty result.

### SQ versus SG

PUB-SQ establishes solver uncertainty/admissibility. PUB-SG must operate within a solver configuration whose numerical error is below the aggregation-effect scale. It does not re-argue solver equivalence.

### GC versus RC

PUB-GC owns the base coupling problem and its strict reference. PUB-RC may not reclaim same-origin, whole-window exchange or conservation. It owns only the incremental cost/robustness consequence of additional response information.

### GC versus SG

PUB-GC may establish N:1 conservation and coupling correctness. PUB-SG owns the hydrological consequence of representing heterogeneity explicitly versus through a frozen equivalent column.

## Revised doctoral research architecture

The literature stress test strengthens the branched architecture:

```text
                               REPLACE / PUB-SQ
                              /
PRESERVE / PUB-ME -----------+
                              \
                               COUPLE / PUB-GC
                                  |          \
                                  |           SCALE / PUB-SG ?
                                  |
                           ACCELERATE / PUB-RC ?
```

PUB-RC and PUB-SG are conditional for different reasons:

- RC depends on a positive incremental value of hydrological response information beyond strong generic numerical acceleration.
- SG depends on an incremental effect of two-way shared-groundwater feedback beyond already-known regime-dependent vadose-zone upscaling.

The core doctoral body should therefore remain viable without either conditional paper.

## Proposed overarching research question

The previous modernization-oriented wording remains somewhat too close to the software-development story. After the stress test, a more durable umbrella is:

> How can changes in the numerical representation, solution and composition of an established process-based hydrological model be made scientifically testable and conditionally admissible rather than assumed equivalent?

This maps cleanly to:

- PUB-ME: change in state/acceptance architecture;
- PUB-SQ: change in numerical solver;
- PUB-GC: change from isolated to composed models;
- PUB-RC: change in interface information;
- PUB-SG: change in spatial representation.

It also permits negative results. A change may fail admission without invalidating the doctoral programme.

## Priority after this stress test

### Core line

1. PUB-ME: materialize the matched B0/B1 research-only harness and preserve the causal freeze.
2. PUB-SQ: preregister the inside/boundary/outside admissibility experiment. Keep P2E14 thresholds immutable.
3. PUB-GC: prioritize the experiments that discriminate exchange/acceptance semantics rather than further architecture for its own sake, then transfer to an admitted MODFLOW 6 backend.

### Conditional line

4. PUB-RC: strengthen R1 before any response-assisted primary test. A weak generic comparator would invalidate the novelty argument.
5. PUB-SG: revise the research question and add the prescribed-head/one-way control before building a large heterogeneity matrix.

## Literature anchors used for the stress test

### PUB-ME
- Nyenah, E. et al. (2025). The process and value of reprogramming a legacy global hydrological model. Geoscientific Model Development, 18, 5635-5669. https://doi.org/10.5194/gmd-18-5635-2025
- Coleman, E., Shen, Y., Sosonkina, M., & Xu, P. (2026). Validating LLM-Modernized Scientific Software Through Differential Fault Injection. arXiv:2608.14527.
- Functional Mock-up Interface 3.0.2, Modelica Association Project FMI, 2024.
- MOOSE Framework documentation, Stateful Material Properties and Restore on Rejected Timesteps.

### PUB-SQ
- Hassane Maina, F. & Ackerer, P. (2017). Ross scheme, Newton-Raphson iterative methods and time-stepping strategies for solving the mixed form of Richards' equation. HESS, 21, 2667-2683. https://doi.org/10.5194/hess-21-2667-2017
- Bootsma, H. P., van der Ploeg, M. J., & Weerts, A. H. (2026). Why modified Picard works: Mass-conservative and higher-order time integration for the Richardson-Richards equation. Advances in Water Resources, 213, 105327. https://doi.org/10.1016/j.advwatres.2026.105327
- Kootanoor Sheshadrivasan, V. & Langhammer, J. (2026). GWSWEX v1.0. Geoscientific Model Development, 19, 8233-8267. https://doi.org/10.5194/gmd-19-8233-2026

### PUB-GC
- Xu, X. et al. (2012). Integration of SWAP and MODFLOW-2000 for modeling groundwater dynamics in shallow water table areas. Journal of Hydrology. https://doi.org/10.1016/j.jhydrol.2011.07.002
- van Walsum, P. E. V. & Veldhuizen, A. A. (2011). Integration of models using shared state variables: Implementation in the regional hydrologic modelling system SIMGRO. Journal of Hydrology, 409, 363-370. https://doi.org/10.1016/j.jhydrol.2011.08.036
- Zeng, J. et al. (2019). Capturing soil-water and groundwater interactions with an iterative feedback coupling scheme: new HYDRUS package for MODFLOW. HESS, 23, 637-655. https://doi.org/10.5194/hess-23-637-2019
- Deltares iMOD Coupler public MetaSWAP-MODFLOW 6 documentation and source, consulted 2026-09-18.

### PUB-RC
- Delaissé, N. et al. (2023). Quasi-Newton Methods for Partitioned Simulation of Fluid-Structure Interaction Reviewed in the Generalized Broyden Framework. Archives of Computational Methods in Engineering, 30, 3271-3300. https://doi.org/10.1007/s11831-023-09907-y
- Kotarsky, J. & Birken, P. (2025). A Time-Adaptive Multirate Quasi-Newton Waveform Iteration for Coupled Problems. International Journal for Numerical Methods in Engineering. https://doi.org/10.1002/nme.70063

### PUB-SG
- Zhu, J. & Mohanty, B. P. (2002). Upscaling of soil hydraulic properties for steady state evaporation and infiltration. Water Resources Research. https://doi.org/10.1029/2001WR000704
- Zhu, J. & Mohanty, B. P. (2003). Effective hydraulic parameters for steady state vertical flow in heterogeneous soils. Water Resources Research. https://doi.org/10.1029/2002WR001831
- Vereecken, H. et al. (2007). Upscaling Hydraulic Properties and Soil Water Flow Processes in Heterogeneous Soils: A Review. Vadose Zone Journal, 6, 1-28. https://doi.org/10.2136/vzj2006.0055
- Vereecken, H. et al. (2019). Infiltration from the Pedon to Global Grid Scales: An Overview and Outlook for Land Surface Modeling. Vadose Zone Journal, 18, 1-53. https://doi.org/10.2136/vzj2018.10.0191
