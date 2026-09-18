# PUB-GC / COUPLE — living manuscript draft

## Working title

**Solver-autonomous finite-window coupling of vadose-zone and groundwater models: a conservative SWAP5–MODFLOW6 implementation**

Alternative working title:

**Hydrologically accountable partitioned coupling of independently time-integrating vadose-zone and groundwater models**

## Draft status

**Living research manuscript — first substantive draft, 2026-09-18**

This draft is intentionally result-conservative. It distinguishes:

- method statements already supported by the current SWAP5 coupling architecture and qualification chain;
- claims that still require publication-specific evidence;
- hypotheses that may later strengthen or narrow the paper.

The manuscript should evolve with the evidence. It must not promote a design intention into a scientific result.

---

## Abstract — working, result-neutral version

Coupling a detailed vadose-zone model to a regional groundwater model is not only a matter of exchanging recharge and groundwater head. The coupled system must reconcile different numerical time scales, preserve the physical meaning of exchange quantities, prevent rejected nonlinear iterations from contaminating model state, and ensure that water transfer is published exactly once after coupled convergence. Existing hydrological couplings, environmental modelling frameworks and generic co-simulation methods address important parts of this problem, but they make different assumptions about component ownership, temporal coordination and interface semantics.

We present a solver-autonomous finite-window coupling method for SWAP5 and MODFLOW6. Each component retains ownership of its internal numerical solution and state, while an internal coupling service coordinates repeated trials over a common coupling window. SWAP5 predictor and corrector evaluations start from one immutable accepted origin; MODFLOW6 remains within one prepared nonlinear solve; only the converged coupled state is allowed to cross the publication boundary. The interface distinguishes the SWAP lower-boundary flux, the MODFLOW-facing exchange flux, hydraulic head, storage/response information and the whole-window transferred water amount. This separation allows coupling convergence, state acceptance and mass publication to be treated as related but distinct operations.

The method is implemented through the MODFLOW6 application-programming interface and the SWAP5 transactional execution model. A restricted end-to-end qualification currently demonstrates one real SWAP column coupled to one live MODFLOW6 cell under a bounded near-equilibrium envelope. The broader research programme evaluates conservation, retry and restart behaviour, coupling-window sensitivity, hydrological response information, computational work relative to black-box multisecant coupling, and scalability. The intended contribution is not a new Newton or quasi-Newton algorithm, but a reproducible hydrological coupling contract that combines solver autonomy, finite-window iteration, typed physical exchange and exactly-once mass publication.

---

# 1. Introduction

## 1.1 Why vadose-zone–groundwater coupling remains difficult

The vadose zone and groundwater form one hydrological system, but they are commonly simulated with models that were developed for different spatial scales, process detail and numerical time scales. A one-dimensional vadose-zone model may resolve infiltration, evaporation, root-water uptake, capillary rise and rapidly changing vertical hydraulic gradients using short, adaptive internal timesteps, whereas a regional groundwater model integrates saturated flow over larger spatial domains and typically evolves on a coarser temporal grid. Coupling these models is therefore not equivalent to passing one recharge value downward and one groundwater level upward.

Three classes of difficulty are intertwined.

First, the exchanged quantities must have an unambiguous physical meaning. The hydraulic flux across the fixed lower boundary of a vadose-zone column need not be identical to the effective recharge or exchange quantity seen by a groundwater model over the same interval. Storage change within the part of the profile represented by the vadose-zone model can contribute to the groundwater-facing exchange. Hydraulic head, pressure head and groundwater-table depth are likewise related but non-identical variables and require an explicit vertical datum.

Second, the coupled problem can require nonlinear iteration. A groundwater head proposed by the saturated-zone model changes the vadose-zone solution, which changes the exchange flux, which can in turn change the groundwater solution. Sequential exchange is therefore not generally equivalent to a converged coupled solution. The severity of this feedback depends on hydrological state, hydraulic properties, coupling-window length and the numerical response of both components.

Third, iterative coupling creates a state-authority problem. If a vadose-zone model is advanced repeatedly over the same physical interval under different candidate groundwater heads, most of those trajectories are rejected coupling trials rather than accepted hydrological history. A coupling implementation must therefore distinguish computation from acceptance. The same applies to interface water transfer: a flux produced by an intermediate nonlinear iterate is not automatically an authoritative mass transfer.

These concerns become more important when independently developed models are coupled without merging their internal solvers. Such solver autonomy is attractive for maintainability and scientific traceability, but it requires a more explicit contract at the interface.

## 1.2 Existing coupling approaches provide important but incomplete precedents

Vadose-zone and groundwater coupling has a substantial history. HYDRUS-based MODFLOW packages established bidirectional exchange between a Richards-equation vadose-zone model and MODFLOW, including repeated feedback between groundwater level and recharge. MetaSWAP/SIMGRO developed a tightly integrated shared-state approach in which groundwater level and a dynamic storage relation are used to couple unsaturated-zone and groundwater response. These studies demonstrate that iterative vadose-zone–groundwater feedback, dynamic response coefficients and differences in internal hydrological representation are not new in themselves.

Environmental modelling frameworks address another part of the problem. OpenMI and later HydroCouple provide generic concepts for exchanging quantities among model components and for handling spatial and temporal mappings. The Basic Model Interface (BMI) similarly standardizes access to model state and execution. For MODFLOW6, the application-programming interface and XMI layer provide external control of model variables and nonlinear solution without requiring source-code fusion. These developments make modern, maintainable external coupling technically feasible.

A third body of work comes from partitioned multiphysics and co-simulation. Fixed-point iteration, relaxation, Aitken acceleration, interface quasi-Newton methods, Anderson acceleration, waveform iteration and interface-Jacobian methods all address the convergence of independently implemented components. FMI and preCICE include component state save/restore or checkpoint semantics that support repeated execution of a coupling interval. Recent quasi-Newton waveform methods further show that accelerated partitioned coupling is compatible with components that use different and adaptive internal time grids.

Taken together, this literature removes several broad novelty claims. Solver autonomy is not new. Rollback is not new. Iterative coupling is not new. Dynamic hydrological storage response is not new. Interface Jacobians and black-box quasi-Newton acceleration are not new. Multirate finite-window coupling is not new.

The remaining scientific opportunity is therefore not to repackage these ingredients as individually novel. It is to determine whether they can be assembled into a hydrologically explicit coupling contract that preserves physical exchange meaning, model-state authority and mass accounting while retaining the independent numerical ownership of both hydrological models.

## 1.3 The coupling gap addressed here

Many legacy hydrological couplings are scientifically useful but tightly bound to the internal implementation of the participating models. This can create long-term maintenance problems when one component evolves independently. At the other extreme, generic coupling frameworks deliberately abstract away domain-specific meaning and therefore cannot by themselves decide whether two exchanged arrays represent the same physical quantity, whether a trial flux should enter a water balance, or whether a component-specific storage response is an admissible approximation to the actual interface response.

The gap addressed in this study lies between these two traditions.

We seek a coupling method in which:

1. each hydrological model retains ownership of its internal state, solver, adaptive timestepping and process physics;
2. the coupler owns only the coupled iteration and the interface contract;
3. every repeated vadose-zone evaluation over one coupling window starts from the same accepted hydrological origin;
4. exchanged variables retain explicit hydrological semantics, including datum, sign, area and time support;
5. coupled convergence is distinguished from component convergence;
6. only the final accepted coupled state contributes authoritative interface mass;
7. optional response information can be exposed without transferring the component's internal Jacobian or time-integration algorithm to the coupler.

This combination is referred to here as **solver-autonomous, hydrologically accountable finite-window coupling**.

The phrase is descriptive rather than a claim that the underlying numerical ingredients are fundamentally new.

## 1.4 SWAP5 and MODFLOW6 as the test system

SWAP5 is a restructured successor of the SWAP vadose-zone model in which model state, trial calculation and state acceptance are explicitly separated. MODFLOW6 provides a modern groundwater platform with an external application-programming interface that supports repeated nonlinear solution within a prepared timestep.

This combination creates a useful test system. SWAP5 can replay one coupling window repeatedly from an immutable accepted checkpoint while preserving its own internal Richards solution and adaptive timestep control. MODFLOW6 can remain within one prepared nonlinear solve while the coupling service updates the groundwater-facing boundary response between nonlinear iterations.

The coupling plane is the fixed lower boundary of the SWAP column. Hydraulic head is the shared state variable at this plane, but the coupling method distinguishes the native SWAP lower-boundary flux from the effective exchange seen by MODFLOW6. This distinction is central because a numerically convenient interface is not necessarily a physically correct interface.

## 1.5 Contributions of this study

The contribution of this paper is methodological and hydrological rather than the invention of a new nonlinear solver.

First, we formalize a coupling contract that separates **component numerical ownership** from **coupled-iteration ownership**. SWAP5 retains its internal timestep and candidate-state machinery; MODFLOW6 retains its prepared nonlinear solve; the coupling service coordinates only the interaction between them.

Second, we define the interface in hydrological rather than purely numerical terms. Hydraulic head, SWAP lower-boundary flux, MODFLOW-facing exchange, storage/response information and accepted whole-window mass transfer are represented as distinct quantities with explicit time support and provenance.

Third, we extend rollback-safe partitioned coupling into an explicit hydrological state-authority and mass-authority rule: repeated predictor and corrector trajectories are tentative, whereas only a converged candidate may update committed model state and interface mass accounting.

Fourth, we treat response information as optional coupling information rather than as ownership of the internal solver. This allows the same coupling contract to support a black-box iteration and a response-informed iteration and permits a direct study of the computational value of exposing additional hydrological response information.

Fifth, we evaluate the method as a reproducible modelling capability, including conservative exchange, failure and retry behaviour, coupling-window sensitivity, coupled convergence, computational work and a path toward many-column regional coupling.

The paper therefore asks not whether any individual building block is unprecedented, but whether their integration produces a robust and transferable coupling method for independently time-integrating hydrological models.

## 1.6 Research questions

The central research question is:

> Can a vadose-zone model and a groundwater model be strongly coupled over finite windows while each retains ownership of its internal numerical solution, and while coupled state acceptance and interface mass publication remain physically explicit and conservative?

This is decomposed into five questions.

**RQ1 — Interface correctness.**  
Can the coupling distinguish and consistently transform the hydraulic head, native lower-boundary flux, groundwater-facing exchange, storage response and whole-window mass transfer required by the two models?

**RQ2 — State and mass authority.**  
Can repeated predictor and corrector trials be executed from one accepted origin without rejected trajectories contaminating committed model state or authoritative interface water balance?

**RQ3 — Coupled convergence.**  
Under which hydrological and numerical conditions is iterative coupling required, and how do coupling-window length and feedback strength affect convergence and solution error?

**RQ4 — Response information.**  
What does the finite-window response quantity exposed by SWAP represent relative to storage response and the actual head-to-exchange interface response, and when does supplied response information reduce total coupling work relative to black-box multisecant learning?

**RQ5 — Scalability.**  
Can the same coupling contract be composed across many SWAP columns and MODFLOW cells without changing the state-authority, mass-accounting or solver-ownership principles?

RQ5 concerns execution and mapping scalability. The separate physical question of when heterogeneous land units may be aggregated into an equivalent unsaturated-zone representation is outside this manuscript and belongs to the SCALE research line.

---

# 2. Coupling method

## 2.1 Ownership model

The coupling is partitioned. Neither model becomes a numerical subroutine whose internal solve is owned by an external master.

The ownership hierarchy is:

```text
coarse model orchestration
        |
        v
internal SWAP5-MODFLOW6 coupling service
        |
        +--> SWAP5 transactional participant
        |
        +--> MODFLOW6 prepared-solve participant
```

The coarse orchestrator decides when a coupled model interval is requested. Predictor/corrector logic remains below this level because it is part of the scientific coupling contract rather than generic workflow orchestration.

SWAP5 owns:

- its committed hydrological state;
- its internal process physics;
- the Richards solve and internal temporal discretization;
- candidate generation from a checkpoint;
- candidate discard and commit.

MODFLOW6 owns:

- groundwater state;
- the groundwater equations and nonlinear solver;
- the prepared timestep and prepared nonlinear solve;
- internal nonlinear iterate state.

The coupling service owns:

- the common coupling-window identity;
- construction and use of the SWAP coupling response;
- sequencing of MODFLOW and SWAP evaluations;
- the coupled convergence criterion;
- hand-off to whole-window publication.

This separation is a design requirement. The coupler is not allowed to reimplement SWAP-specific timestep, retry or Richards-solver logic.

## 2.2 Coupling window

Coupling is defined over a finite interval

```text
W = [t_n, t_{n+1}]
```

with duration `DeltaT`.

The interval is a communication and acceptance window, not an internal numerical timestep. SWAP5 may use multiple adaptive internal timesteps inside W. MODFLOW6 may perform multiple nonlinear iterations for the same groundwater timestep.

This distinction allows communication frequency to be varied without requiring both models to adopt a common internal timestep.

## 2.3 Fixed coupling plane and head transformation

The coupling plane is the fixed lower boundary of the SWAP soil column.

The shared state is hydraulic head at that plane:

```text
H_swap,bot = H_mf6
```

after explicit datum translation.

SWAP internally uses pressure head relative to the lower-face elevation. If `z_bottom` is the elevation of the coupling plane and `psi_bottom` is pressure head, then:

```text
H_interface = z_bottom + psi_bottom
```

with unit conversion applied explicitly where SWAP uses centimetres and the public coupling contract uses metres.

This equality does not imply that the MODFLOW hydraulic head is identical to a diagnostic phreatic water-table elevation inside SWAP. SWAP may resolve an unsaturated or saturated vertical profile between the fixed lower boundary and the location where pressure head is zero.

## 2.4 Distinct exchange quantities

The method distinguishes at least four quantities.

### 2.4.1 Native SWAP lower-boundary flux

`q_bot` is the hydraulic flux across the fixed SWAP lower boundary. It is a native lower-boundary quantity and can be prescribed during predictor trials.

### 2.4.2 Groundwater-facing exchange

`q_u` is the effective exchange supplied to the groundwater system.

In general:

```text
q_bot != q_u
```

because storage change represented inside the SWAP domain can contribute to the groundwater-facing transfer.

The public sign convention is normalized explicitly. A positive `q_u` denotes transfer from SWAP toward groundwater; any native SWAP or MODFLOW sign convention is translated by the relevant adapter.

### 2.4.3 Coupling/storage response

The initial response representation uses a local affine relation between groundwater head and exchange:

```text
q(H) = q_ref + s (H - H_ref)
```

where `s` is a local response slope.

Historically and in the F-GC30 line, the response coefficient `u` is constructed or interpreted such that:

```text
s ~= u / DeltaT
```

within its qualified envelope.

The publication study will explicitly test whether this quantity behaves as a storage response, as the actual finite-window interface derivative, or as a bounded approximation whose meaning depends on active process composition.

### 2.4.4 Whole-window transfer

The authoritative interface transfer is the accepted amount integrated over the complete coupling window:

```text
V_u = integral_W Q_u(t) dt
```

A mean rate may be derived as:

```text
Q_u,mean = V_u / DeltaT
```

but a terminal instantaneous flux is not silently substituted for the whole-window amount.

This distinction is required for consistent mass accounting across retries and accepted publication.

## 2.5 Accepted origin and SWAP trial semantics

At the beginning of a coupling window, the coupling service captures one immutable accepted SWAP origin.

Conceptually:

```text
committed SWAP state at t_n
        |
        v
capture checkpoint
        |
        +--> predictor trial
        +--> response/tangent trial(s)
        +--> corrector 1
        +--> corrector 2
        +--> ...
```

Every SWAP evaluation for this coupling window starts from the same checkpoint.

A corrector is therefore **not** the continuation of the preceding predictor or corrector. It is an alternative candidate trajectory over the same physical interval.

The production SWAP participant implements this through the existing SWAP5 transaction machinery:

```text
kernel committed state
    -> capture checkpoint
    -> advance interval from checkpoint
    -> candidate state
       -> discard candidate
       or
       -> non-mutating publication preflight
       -> commit candidate
```

Only the final accepted candidate may mutate committed SWAP state.

## 2.6 Predictor response

The predictor constructs the initial SWAP response for the active window from the accepted origin.

The original finite-difference form evaluates prescribed bottom fluxes around an initial predictor:

```text
q_1 = q_0 - delta_q
q_2 = q_0 + delta_q
```

and observes the resulting terminal hydraulic heads `H_1` and `H_2`.

The response coefficient is:

```text
u_FD = ((q_2 - q_1) * DeltaT) / (H_2 - H_1)
```

subject to a governed perturbation policy.

Current canonical development also supports an admitted accepted-trajectory analytic response within a restricted process envelope. The manuscript must distinguish response-construction method from coupling semantics: finite-difference and analytic response estimates may be alternative implementations of the same bounded interface-response contract, but they require independent qualification.

The response used by the groundwater backend is represented locally as:

```text
q(H) = q_ref + s (H - H_ref)
```

with explicit provenance linking the response to the accepted SWAP origin and coupling window.

## 2.7 MODFLOW6 prepared-solve lifecycle

The MODFLOW6 participant uses one prepared nonlinear solve per coupling window.

The qualified lifecycle is:

```text
prepare_time_step

prepare_solve
    XOLD <- accepted previous-time head

    solve iteration 1
    update coupling response
    solve iteration 2
    update coupling response
    ...
finalize_solve
```

`XOLD` remains the accepted previous-time groundwater head while `X` evolves as the nonlinear iterate.

This is important for the coupling transaction model. MODFLOW6 is not rolled back to the beginning of the timestep after every coupling iteration. Instead, SWAP correctors are replayed from the immutable SWAP origin while MODFLOW remains inside one prepared nonlinear solve.

The two participants therefore have different internal iteration semantics but share one coupling-window acceptance decision.

## 2.8 Coupled corrector iteration

Let the current affine SWAP response be:

```text
q_gw(H) = q_ref + s (H - H_ref)
```

At coupled iteration `k`:

1. publish the current affine response to MODFLOW6;
2. execute one MODFLOW nonlinear solve iteration;
3. obtain current groundwater head `H_k` and the realized groundwater-facing affine boundary flux `q_gw,k`;
4. run a SWAP corrector over the complete coupling window from the immutable accepted origin with `H_k` prescribed at the coupling plane;
5. obtain the corresponding SWAP exchange `q_swap,k`;
6. compute the coupling residual

```text
r_q,k = q_swap,k - q_gw,k
```

If the coupled criterion is not satisfied, the SWAP candidate is discarded. MODFLOW remains in its prepared solve, and the affine reference is updated using the latest SWAP response while the qualified slope policy is retained or refreshed according to the active response contract.

## 2.9 Coupled convergence

Component convergence is necessary but not sufficient.

For the current scalar exchange form, coupled acceptance requires at least:

```text
|r_q,k| <= epsilon_q
AND
MODFLOW nonlinear convergence == true
```

A MODFLOW convergence flag alone is insufficient because SWAP may alter the exchange associated with the current head.

Conversely, a small SWAP-groundwater exchange residual is insufficient if the groundwater nonlinear equations themselves have not converged.

Additional head-increment or relative exchange criteria may be used as diagnostics or governed acceptance conditions, but their role must be stated explicitly rather than embedded as hidden constants.

## 2.10 Failure, retry and smaller windows

Failure before coupled convergence produces no authoritative publication.

If the coupling cannot converge within the admitted iteration budget, the current attempt can be abandoned according to an explicit execution policy. One admissible recovery route is to reconstruct from the last accepted state and retry a smaller coupling window.

A failed scientific attempt therefore has the following semantics:

```text
failed attempt
    -> discard reversible SWAP candidate
    -> invalidate abandoned MODFLOW runtime as required
    -> discard uncommitted ledger state
    -> reconstruct from last accepted boundary
    -> optionally retry with smaller W
```

The policy is fail-closed: iteration limits or physical tolerances are not relaxed merely to force acceptance.

## 2.11 Whole-window publication transaction

Once coupled convergence has been achieved, the model state is still not immediately authoritative.

A publication preflight verifies that:

- the retained SWAP candidate belongs to the expected accepted origin and exact window;
- MODFLOW is ready to publish the same timestep;
- the interface ledger is prepared for the same coupling identity and transfer.

Only after these reversible checks pass does execution cross the first irreversible publication point.

The qualified ordering is:

```text
MODFLOW finalize_time_step
        ->
SWAP commit retained candidate
        ->
commit prepared interface ledger
```

Each operation occurs exactly once.

Failures before this point are ordinary rollback/retry cases. A platform failure after the publication point is treated as a durability/restart problem rather than falsely represented as a scientifically safe rollback.

This distinction separates **scientific rejection** from **post-publication durability failure**.

## 2.12 Exactly-once interface mass authority

The coupling ledger records only the accepted transfer.

Predictor evaluations, tangent perturbations and rejected corrector trials may compute physically meaningful fluxes, but they contribute zero authoritative interface mass:

```text
V_authoritative =
    0                     for rejected trial
    V_u,accepted          for the committed coupled window
```

The same physical interface transfer is booked once on each component side after sign and unit normalization and must cancel in the combined-system accounting domain.

Managed groundwater abstraction, irrigation and other transfers are separate ledgers and must not be hidden inside natural lower-boundary exchange.

## 2.13 Multi-column mapping

Regional application requires many SWAP columns to interact with MODFLOW cells.

For multiple tiles `i` associated with one groundwater cell, each local response can be written:

```text
q_i(H) ~= q_i* + (u_i / DeltaT) (H - H_i*)
```

At a common cell reference head `H_ref`:

```text
q_i,ref = q_i* + (u_i / DeltaT) (H_ref - H_i*)
```

and, with area fractions `f_i`:

```text
q_cell,ref = sum_i f_i q_i,ref

u_cell = sum_i f_i u_i
```

so that:

```text
q_cell(H) ~= q_cell,ref + (u_cell / DeltaT) (H - H_ref)
```

This preserves the weighted sum of the tile-local affine responses even when predictor terminal heads differ.

This mapping is a numerical composition rule. It does **not** establish that heterogeneous land units may be replaced physically by one equivalent vadose-zone column. That separate aggregation question is outside this paper.

## 2.14 Response-information variants

The coupling contract is deliberately compatible with different amounts of response information.

A black-box variant may expose only the evaluated interface response. The coupling algorithm can then use relaxation or learn an approximate Jacobian from interface history.

A response-informed variant additionally exposes a local finite-window response estimate.

For one accepted SWAP state and window:

```text
V_u(H) = R_W(S_n, F_W; H)

J_R = dV_u / dH
```

The publication programme distinguishes:

- `u_FD`: the F-GC30-style response obtained from prescribed-flux perturbations;
- `J_S`: the whole-window storage response to head;
- `J_R`: the actual finite-window interface exchange response to head.

These quantities are not assumed to be identical.

The acceleration experiment compares the net value of supplied response information with a strong black-box multisecant baseline. Acquisition cost is counted in equivalent full SWAP-window evaluations.

## 2.15 Current qualified envelope

The present end-to-end application evidence is intentionally restricted.

Current canonical qualification includes:

- one real SWAP/FMR soil column coupled 1:1 to one live MODFLOW6 6.8.0 cell (F-GC44);
- two independently transactional real SWAP columns composed N:1 to one live MODFLOW cell, using identical physical parameterization to isolate runtime composition (F-GC45);
- two independently transactional real SWAP interfaces coupled 1:1 to two distinct cells in one live MODFLOW model and one prepared solve (F-GC46);
- the internal predictor/corrector coupling lifecycle;
- prescribed groundwater-head SWAP correctors;
- an admitted analytic accepted-trajectory response;
- whole-window publication boundaries;
- exactly-once SWAP and ledger publication.

The first scientific E1/E2 evidence envelope remains the one-column/one-cell near-equilibrium F-GC44 configuration. Current runtime qualification still excludes, among other claims/processes:

- heterogeneous N:1 aggregation science;
- active drainage;
- root extraction;
- macropores;
- snow;
- soil temperature;
- Ribasim coupling;
- irrigation allocation.

A larger prescribed-head perturbation has already exposed a boundedness issue by exhausting transaction retries in the real SWAP route. This is treated as evidence that the scientific/numerical envelope must be expanded through explicit qualification rather than by relaxing convergence rules.

The manuscript will therefore distinguish **method architecture**, **current qualified implementation**, and **future experimental envelope** throughout.

---

# 3. Experimental design — manuscript skeleton

## 3.1 E1 Interface identity and conservation

Purpose:

- verify `q_bot`, `q_u`, head transformation and whole-window transfer;
- demonstrate differentiated and integrated water-balance closure;
- quantify numerical tolerance.

Planned outputs:

- schematic of coupling plane and exchanged quantities;
- table of sign/unit/datum transformations;
- mass-closure figure over accepted and rejected trials.

## 3.2 E2 Transaction and exactly-once publication

Directed tests:

- reject predictor;
- reject corrector;
- exhaust iteration budget;
- fail publication preflight;
- retry a smaller window;
- restart at an accepted boundary.

Primary claim:

> rejected coupling calculations cannot contaminate committed hydrological state or authoritative interface mass.

## 3.3 E3 Coupling-window and feedback experiment

Use a controlled one-column/one-cell system in which feedback strength and coupling-window duration can be varied.

Compare:

- sequential/loose exchange;
- converged iterative exchange;
- short-window reference;
- longer-window alternatives.

Measure:

- accepted head;
- exchange;
- storage;
- residual;
- component work;
- convergence/failure.

## 3.4 E4 Response identity

From one accepted SWAP state and forcing window determine:

```text
u_FD
J_S = dDeltaS/dH
J_R = dV_u/dH
```

over qualified perturbation sequences.

Determine:

- numerical derivative plateau;
- local linearity radius;
- response drift between accepted windows;
- path dependence when head trajectories share endpoints.

## 3.5 E5 ACCELERATE oracle and black-box comparison

Minimum methods:

- fixed point;
- Aitken;
- IQN/Anderson with cold history;
- IQN/Anderson with admissible warm-history reuse;
- zero-cost oracle response;
- practical supplied-response method.

Primary metric:

```text
total equivalent component work
```

rather than iteration count alone.

The zero-cost oracle test is an early falsification gate: if high-quality free response information gives no material advantage over the black-box multisecant baseline, an expensive practical response cannot justify an acceleration claim.

## 3.6 E6 Hydrological stress regimes

Candidate stress dimensions:

- groundwater proximity;
- recharge pulse;
- strong evaporation/transpiration regime;
- coarse versus fine hydraulic response;
- coupling-window duration;
- process/boundary switching where admitted.

Include a weak-coupling negative control.

## 3.7 E7 Realistic application

A representative application should demonstrate that the method remains usable outside the synthetic qualification system.

Its role is:

- hydrological relevance;
- external validity;
- operational cost characterization.

It does not need to carry every novelty claim.

## 3.8 E8 Regional execution and scaling

If included in the paper, quantify:

- number of SWAP columns;
- mapping to MODFLOW cells;
- deterministic reduction;
- mass closure;
- runtime scaling.

Do not use this experiment to claim the physical validity of spatial aggregation without the separate SCALE analysis.

---

# 4. Results

## 4.1 Interface identity and conservation in the first real coupled window

The first publication-specific experiment reused the restricted F-GC44 real-SWAP/live-MODFLOW6 configuration rather than expanding the hydrological envelope. One FMR/SWAP reference-Richards column was coupled to one MODFLOW6 6.8.0 cell over a `1.0e-4 day` (8.64 s) window under the near-equilibrium forcing used for end-to-end qualification.

The predictor response was internally consistent but demonstrated why the coupling quantities cannot be treated as aliases. The imposed native lower-boundary predictor flux was

```text
q_bot = 1.0000000000000000e-6 cm/day
```

whereas the reconstructed groundwater-facing predictor exchange was

```text
q_u = -9.6588521204796776e-7 cm/day
```

with coupling response

```text
u = 3.4029360372790930e-5.
```

Substitution into the F-GC30 relation

```text
q_u =
  u (H_end-H_start) 100 / DeltaT_day
  - q_bot
```

reproduced the reported `q_u` to representation precision.

The same real predictor trial returned complete canonical mass accounting. Storage start and end were both `1.0430631535459627` in the native storage basis, interval inflow and outflow were both `1.0e-10`, and both storage change and the independently assembled canonical residual were zero in this equilibrium case. This is a deliberately easy balance case; its role is to verify accounting identity and interface semantics, not to establish broad hydrological accuracy.

The live coupled solve converged in two outer iterations. The accepted values were

```text
H                 = -0.71499996773317653 m
q_SWAP            = -1.2708557527755854e-13 m/s
q_GW              = -1.2708580747683645e-13 m/s
q_SWAP - q_GW     =  2.3219927791065243e-19 m/s.
```

The final accepted SWAP bottom amount was `-1.0980193703981059e-10 cm`, corresponding to `-1.0980193703981059e-12 m`. The committed interface ledger recorded exactly `-1.0980193703981059e-12 m`. Independently integrating the accepted public SWAP rate over 8.64 s gave `-1.0980193703981057e-12 m`, equal to the ledger amount to representation precision.

An initially preregistered sign hypothesis expected the public rate and native accepted amount to have opposite signs and was falsified by the first execution. Code-trace adjudication showed two explicit sign transformations between the native SWAP bottom exchange and the public outward-from-SWAP rate, so the signs must in fact agree. The production coupling implementation was unchanged; the failed hypothesis and corrected algebra remain recorded as part of the evidence trail.

These results support interface and accounting consistency only inside the restricted near-equilibrium envelope. They do not establish equivalence of `q_bot` and `q_u`, nor do they demonstrate conservation under all process combinations or stronger groundwater perturbations.

## 4.2 Rejected trials have zero hydrological authority

A second experiment used both deterministic failure injection and the real SWAP participant to test the distinction between trial computation and authoritative model history.

The existing F-GC41 failure-injection suite comprised seven passing tests. SWAP, MODFLOW and ledger preflight failures all occurred before publication and resulted in no participant publication; invalid window identity touched no participant; MODFLOW publication readiness was non-mutating; and timestep finalization was one-shot. A failure after the first irreversible publication operation was explicitly not classified as a rollback-safe scientific retry.

The real SWAP/live-MODFLOW route then tested the actual committed state and interface ledger. At the beginning of the window:

```text
SWAP revision          = 0
SWAP committed time    = 0
ledger commit count    = 0
ledger committed mass  = 0.
```

This complete authority tuple remained unchanged after a real prescribed-head SWAP trial, after discarding that trial, after preparing a retained SWAP candidate plus its interface ledger, after aborting that prepared publication, and before and after discarding every non-final coupled corrector.

After convergence, all publication preflights were likewise non-mutating. The observed publication sequence was:

```text
MODFLOW finalize_time_step:
    SWAP revision = 0
    ledger count  = 0

SWAP commit:
    SWAP revision = 1
    SWAP time     = DeltaT
    ledger count  = 0

ledger commit:
    SWAP revision = 1
    ledger count  = 1
    ledger mass   = accepted final interface transfer.
```

A second MODFLOW timestep finalization was rejected by the one-shot lifecycle.

Within this envelope, a computed trial flux is therefore demonstrably not an authoritative hydrological transfer. Authority is acquired only after coupled acceptance and the ordered publication transaction.

The experiment does not test recovery from a platform failure after the irreversible publication point; that remains a durability/restart question rather than a rollback-safe scientific retry.

## 4.3 Coupling-window and feedback characterization

The preregistered E3 experiment evaluated 48 combinations of three coupling-window durations (`10^-4`, `10^-3` and `10^-2` day), four native predictor/boundary-flux levels (`10^-6`, `10^-3`, `10^-2` and `10^-1 cm/day`) and four MODFLOW horizontal conductivities (0.01, 0.1, 1 and 10 m/day). Each valid case compared a loose/sequential pass with a fully iterative solve from the same accepted SWAP origin. No E3 calculation was published as authoritative model state or interface mass.

Twelve of the 48 cases produced a valid real-SWAP predictor and converged coupled solution. These were exactly the twelve combinations using the original low predictor flux of `10^-6 cm/day`. All 36 higher-flux cases failed during SWAP predictor construction, before MODFLOW feedback was evaluated. The initial matrix therefore encountered the current predictor/component-response envelope before reaching the intended high-flux coupling regime. These failures cannot be interpreted as failure of the outer coupling iteration.

Within the twelve valid cases, the loose interface mismatch increased with coupling-window duration and with the tested groundwater-fixture conductivity. The maximum relative loose flux mismatch was 1.77, and the largest absolute loose residual was `2.80e-12 m/s`, approximately 2800 times the fixed `10^-15 m/s` coupling residual tolerance. Iterative coupling reduced all twelve valid cases below the qualified flux criterion, requiring between two and five outer iterations.

The corresponding change in groundwater head was nevertheless extremely small. The largest difference between the loose and iteratively converged head was only

```text
5.55e-9 m,
```

while the largest change in SWAP interface rate was `1.92e-14 m/s`. Even the largest absolute loose residual, `2.80e-12 m/s` over the `1e-2 day` window, corresponds to only about `2.42e-9 m` of unclosed water depth over that window (`2.42e-6 L` for the one-square-metre fixture). The current low-flux qualification regime therefore demonstrates a distinction between strict numerical interface consistency and hydrologically material state correction. Strong iteration is effective at enforcing the coupled interface equation, but this particular near-equilibrium fixture is not evidence that the resulting groundwater-head correction is practically important. The fixed `1e-15 m/s` criterion should consequently be interpreted here as a qualification tolerance rather than an operational hydrological-error threshold.

The conductivity trend should not be generalized as a physical statement that larger aquifer conductivity implies stronger vadose-zone–groundwater coupling. Coupling strength depends on the product of the groundwater and vadose-zone response operators. The derivative structure is examined separately in the response-characterization work.

A post-E3 predictor-envelope diagnosis was therefore performed before selecting a stronger hydrological feedback case. The original 48-case outcome is retained unchanged; the diagnostic scan is a separate follow-up and does not retroactively redefine the preregistered matrix.

The E3-D scan evaluated 21 predictor-only combinations between `10^-6` and `10^-3 cm/day`. Fourteen cases produced a valid predictor response and seven failed. All seven failures occurred at the same qualification stage, `PREDICTOR_WHOLE_WINDOW_TRIAL_INCOMPLETE`, before tangent construction, interface-response assembly or MODFLOW participation. The largest demonstrated predictor flux was `3e-5 cm/day` for the `1e-4 day` window and `1e-4 cm/day` for both the `1e-3` and `1e-2 day` windows; the next tested points failed. The initial E3 jump directly from `1e-6` to `1e-3 cm/day` had therefore skipped a substantial valid interval.

The successful predictor cases also show that the exposed response coefficient is not static. Across the low-flux control points, `u` increased from approximately `3.40e-5` at `1e-4 day` to `2.69e-4` at `1e-3 day` and `1.19e-3` at `1e-2 day`; at the longer windows it also varied measurably with predictor flux. This observation motivates, but does not replace, the formal `u_FD` versus `J_S` versus `J_R` analysis in E4.

E3-D therefore localizes the high-flux blocker to the real SWAP whole-window predictor execution rather than the outer coupling algorithm. The exact internal cause of that incomplete trial is treated in a separate diagnostic step and is not inferred from the stage code alone.


The E3-D2 mechanism diagnosis resolved that failure boundary. The three failed predictor points returned the canonical status `TRANSACTION_FAILED`, with no mass rejection and no unavailable temporal certificate. The dominant rejection mechanism changed with window length. At `10^-4 day, q=10^-4 cm/day`, nine of eleven attempts were solver rejections and one was a temporal rejection. At `10^-3 day, q=3e-4 cm/day`, four solver and five temporal rejections exhausted eight retries before any substep was accepted. At `10^-2 day, q=3e-4 cm/day`, eight temporal rejections and one solver rejection exhausted the retry budget. Conversely, the largest valid `10^-2 day, q=10^-4 cm/day` predictor required 59 attempts, 45 temporal retries and 14 accepted substeps. The high-flux boundary is therefore a real bounded component-transaction envelope rather than a failure of response assembly or groundwater coupling.

A second preregistered refinement, E3-R, then removed the original background groundwater gradient and tested only predictor fluxes already demonstrated valid by E3-D. Twenty of 24 cases completed the loose-versus-iterative comparison. At `10^-3 day`, increasing the predictor flux by a factor 100 to `10^-4 cm/day` produced converged solutions for all four groundwater conductivities. Loose interface residuals were approximately `-3.72e-12 m/s`, and strong coupling required three to five outer iterations. The resulting loose-to-iterative groundwater-head corrections, however, remained only `1.60e-9` to `1.83e-9 m`; the largest associated SWAP exchange correction was `6.11e-15 m/s`.

The long-window, higher-flux cases reached a different boundary. At `10^-2 day, q=10^-4 cm/day`, three of four loose diagnostic prescribed-head correctors failed, even though the proposed groundwater heads differed from the predictor reference by only approximately `9e-9` to `2.3e-8 m`. For `K=1 m/day`, the loose corrector remained valid but the iterative solve reached a SWAP corrector failure at outer iteration four when the candidate head was only about `5.67e-8 m` from the predictor reference. Thus the current real-SWAP corrector envelope can become limiting before a materially large groundwater-head feedback is produced.

Taken together, E3, E3-D, E3-D2 and E3-R provide a bounded answer to RQ3. Strong iteration demonstrably improves finite-window interface closure whenever valid component candidates remain available, but the physical groundwater-head correction is negligible in the current near-equilibrium fixture. Attempts to create a stronger response through longer windows and larger fluxes encounter the SWAP predictor/corrector execution envelope before they produce a materially large head response. A positive strong-feedback case therefore requires a different admitted hydrological state or groundwater-response geometry rather than looser numerical tolerances.

## 4.4 Response interpretation

**Evidence status:** concept and response infrastructure exist; publication-specific `u_FD` versus `J_S` versus `J_R` study required.

## 4.5 Response information and computational value

**Evidence status:** not yet established.

This result determines whether ACCELERATE remains only a section of this manuscript or later supports a separate paper.

## 4.6 Realistic and regional behaviour

**Evidence status:** runtime composition has progressed, while realistic hydrological application evidence remains to be assembled. F-GC45 qualifies a two-real-SWAP-column to one-live-MODFLOW-cell N:1 runtime composition using identical physical columns. F-GC46 additionally qualifies two real SWAP interfaces coupled 1:1 to two distinct live MODFLOW6 cells within one groundwater model and prepared solve. These results demonstrate composition capability but are not evidence for heterogeneous spatial aggregation or regional hydrological validity.

---

# 5. Discussion

## 5.1 The contribution is a coupling contract, not a new nonlinear solver

The present method should not be interpreted as a new fixed-point, Newton or quasi-Newton algorithm. Partitioned iteration, rollback/checkpointing, MODFLOW external control, dynamic hydrological response and interface acceleration all have established precedents. The contribution pursued here is narrower and more domain-specific: these ideas are assembled into a coupling contract in which independently time-integrating hydrological components retain numerical ownership while the physical meaning, temporal support and publication authority of exchanged water are made explicit.

The E1/E2 results show why this distinction is not merely software terminology. A real SWAP corrector can compute a physically meaningful bottom exchange while the authoritative SWAP revision and interface ledger both remain unchanged. Only after coupled acceptance and ordered publication does that exchange become model history. In a water-balance model this makes state authority and mass authority part of the scientific coupling definition rather than only an implementation concern.

## 5.2 Generic orchestration is necessary but not sufficient

Generic co-simulation infrastructure can coordinate time, data exchange, iteration and rollback, but it cannot infer the scientific identity of the exchanged quantities. In the present coupling, the distinction between `q_bot`, the effective groundwater-facing exchange, a terminal flux and a whole-window transferred amount is material. The E1 result showed that even in the simple near-equilibrium case the predictor `q_bot` and reconstructed `q_u` are not numerical aliases.

A reusable hydrological coupling therefore requires two layers at once: generic execution discipline and domain-specific interface semantics. Removing the former risks state and retry errors; removing the latter risks a numerically functioning but physically misidentified exchange.

## 5.3 Solver autonomy trades interface complexity for component independence

Embedding SWAP inside MODFLOW, or the reverse, can simplify direct access to internal variables. It also couples the lifecycle of one model to implementation details of the other. The solver-autonomous design instead leaves Richards solution, adaptive SWAP timestepping, groundwater nonlinear solution and component state ownership inside the respective models.

The cost of that choice is a stricter external contract. The coupling layer must explicitly define checkpoint origin, finite-window response, convergence, datum and sign transformations, and the publication transaction. The present results do not establish that this design is universally superior to embedded coupling. They demonstrate that it can be made explicit and testable while preserving component independence.

## 5.4 Numerical interface convergence is not identical to hydrological relevance

The first E3 matrix provides an important negative control. Across the twelve valid low-flux cases, a one-pass affine response could violate the fixed `1e-15 m/s` interface criterion by a large factor. The largest relative loose mismatch was 1.77 and the largest absolute loose residual was `2.80e-12 m/s`. Strong iteration reduced the accepted interface residual below the qualification criterion in two to five outer iterations.

The resulting physical correction was nevertheless extremely small. The maximum loose-to-iterative groundwater-head difference was only `5.55e-9 m`, and the largest exchange-rate correction was `1.92e-14 m/s`. Integrated over the longest tested window, the largest loose residual represents only approximately `2.42e-9 m` of water depth.

This result matters for both coupling design and performance assessment. An absolute interface tolerance can be useful as a qualification rule because it gives a reproducible algebraic acceptance condition. It should not automatically be interpreted as a hydrological-error threshold. Likewise, iteration count by itself does not establish that a coupling problem is scientifically difficult. Later convergence policies should therefore be evaluated against state and mass impact in addition to algebraic residual reduction.

The result also prevents a misleading positive claim: the current near-equilibrium F-GC44-derived fixture is a weak-feedback control, not evidence that strong coupling is always hydrologically necessary.

The E3-R refinement strengthens that negative control. Increasing the valid predictor flux by 30–100 times raises the absolute interface mismatch and the work required for coupled closure, yet the largest loose-to-iterative groundwater-head correction remains only `1.83e-9 m` in the zero-background-gradient fixture. At the longest window and highest demonstrated predictor flux, the prescribed-head SWAP corrector becomes unavailable for head perturbations of only order `10^-8` to `10^-7 m`. The limiting phenomenon is therefore currently component admissibility, not an outer iteration that remains unconverged despite valid component responses.

This distinction is methodologically important. A coupling algorithm should not be judged by cases in which one participant cannot produce a valid candidate over the requested window. Conversely, successful reduction of a strict interface residual does not by itself establish hydrological importance. The present evidence therefore supports retaining both an algebraic convergence criterion for reproducible qualification and separate state/mass-impact metrics for scientific interpretation.

## 5.5 The component qualification envelope constrains the coupled experiment

The original E3 matrix attempted substantially larger predictor fluxes, but those cases did not reach MODFLOW. E3-D localized all observed failures to incomplete real-SWAP whole-window predictor execution before tangent construction or groundwater coupling. A denser scan demonstrated a non-trivial valid interval between the original low-flux control and the first failed points.

This distinction is important. A failed coupled experiment cannot be interpreted as coupling instability when one component has not produced a valid finite-window response. The admissible coupling domain is bounded first by the scientific/numerical envelopes of the participating components and only then by the convergence properties of the outer coupling algorithm.

The response coefficient also varied strongly with window duration in the E3-D ready cases. That observation is consistent with treating `u` as a finite-window response quantity rather than as a static soil property. Its exact relationship to storage response and to the actual prescribed-head interface derivative remains an E4 question.

## 5.6 How much response information should be exposed?

The current evidence is not yet sufficient to decide whether component-provided response information is computationally preferable to black-box learning. E3 establishes two prerequisites for that later comparison. First, the low-flux control shows that sophisticated acceleration would have little scientific value in a regime where the coupled state correction itself is negligible. Second, E3-D shows that response information has its own qualification envelope and changes with window duration.

E4 therefore first determines what the supplied response actually represents. Only after that identity is established should E5 compare supplied response against IQN/Anderson-style learned interface information. If a strong black-box method performs as well at lower information cost, the simpler interface should be preferred. Conversely, a reproducible advantage of fresh response information after state or regime change would justify the additional response contract.

A negative ACCELERATE result would still strengthen the central coupling paper because it would place an empirical upper bound on how much internal response information this class of coupling needs.

---

# 6. Conclusions — placeholder

The final conclusion should be written only after E1–E8 evidence is assembled.

It should distinguish:

1. what the coupling method demonstrably guarantees;
2. the qualified hydrological and numerical envelope;
3. what response information contributes;
4. which limitations remain;
5. what aspects generalize beyond SWAP5–MODFLOW6.

---

# Working references

- Abbaszadeh, P. et al. (2025). Coupling the ParFlow Integrated Hydrology Model within the NASA Land Information System: a case study over the Upper Colorado River Basin. *Hydrology and Earth System Sciences*, 29, 5429–5452. https://doi.org/10.5194/hess-29-5429-2025
- Bailey, R. T., Abbas, S., Arnold, J. G., & White, M. J. (2025). SWAT+MODFLOW: a new hydrologic model for simulating surface–subsurface flow in managed watersheds. *Geoscientific Model Development*, 18, 5681–5697. https://doi.org/10.5194/gmd-18-5681-2025
- Buahin, C. A., & Horsburgh, J. S. (2018). Advancing the Open Modeling Interface (OpenMI) for integrated water resources modeling. *Environmental Modelling & Software*, 108, 133–153. https://doi.org/10.1016/j.envsoft.2018.07.015
- Degroote, J., Haelterman, R., Annerel, S., Bruggeman, P., & Vierendeels, J. (2010). Performance of partitioned procedures in fluid–structure interaction. *Computers & Structures*, 88, 446–457. https://doi.org/10.1016/j.compstruc.2009.12.006
- Delaissé, N., Demeester, T., Fauconnier, D., & Degroote, J. (2022). Surrogate-based acceleration of quasi-Newton techniques for fluid–structure interaction simulations. *Computers & Structures*, 260, 106720. https://doi.org/10.1016/j.compstruc.2021.106720
- Hughes, J. D. et al. (2022). The MODFLOW Application Programming Interface for simulation control and software interoperability. *Environmental Modelling & Software*, 148, 105257. https://doi.org/10.1016/j.envsoft.2021.105257
- Modelica Association Project FMI. *Functional Mock-up Interface Specification 3.0.2*. https://fmi-standard.org/docs/3.0.2/
- Nachabe, M. H. (2002). Analytical expressions for transient specific yield and shallow water table drainage. *Water Resources Research*, 38(10), 1193. https://doi.org/10.1029/2001WR001071
- Rüth, B., Uekermann, B., Mehl, M., Birken, P., Monge, A., & Bungartz, H.-J. (2021). Quasi-Newton waveform iteration for partitioned surface-coupled multiphysics applications. *International Journal for Numerical Methods in Engineering*, 122, 5236–5257. https://doi.org/10.1002/nme.6443
- Schüller, V., Birken, P., & Dedner, A. (2025). Convergence properties of iteratively coupled surface-subsurface models. *GEM - International Journal on Geomathematics*, 16, 9. https://doi.org/10.1007/s13137-025-00265-4
- Sicklinger, S. et al. (2014). Interface Jacobian-based Co-Simulation. *International Journal for Numerical Methods in Engineering*, 98, 418–444. https://doi.org/10.1002/nme.4637
- Twarakavi, N. K. C., Simunek, J., & Seo, S. (2008). Evaluating interactions between groundwater and vadose zone using the HYDRUS-based flow package for MODFLOW. *Vadose Zone Journal*. https://doi.org/10.2136/vzj2007.0082
- van Walsum, P. E. V., & Veldhuizen, A. A. (2011). Integration of models using shared state variables: implementation in the regional hydrologic modelling system SIMGRO. *Journal of Hydrology*, 409, 363–370. https://doi.org/10.1016/j.jhydrol.2011.08.036
- Yang, C. et al. (2026). 20 years of trials and insights: bridging legacy and next generation in ParFlow and Land Surface Model Coupling. *Geoscientific Model Development*, 19, 1849–1866. https://doi.org/10.5194/gmd-19-1849-2026
- Zeng, J., Yang, J., Zha, Y., & Shi, L. (2019). Capturing soil-water and groundwater interactions with an iterative feedback coupling scheme: new HYDRUS package for MODFLOW. *Hydrology and Earth System Sciences*, 23, 637–655. https://doi.org/10.5194/hess-23-637-2019

---

## Internal repository evidence pointers

Current method text should remain reconciled with:

- `docs/integration/F-GC39_PREPARED_SOLVE_COUPLING_SERVICE_CONTRACT.md`
- `docs/integration/F-GC40_MULTISWAP_MODFLOW6_CELL_RESPONSE.md`
- `docs/integration/F-GC41_WHOLE_WINDOW_ACCEPTANCE_RETRY.md`
- `docs/integration/F-GC42_WHOLE_WINDOW_SERVICE_COMPOSITION.md`
- `docs/integration/F-GC43_PRODUCTION_SWAP_PARTICIPANT.md`
- `docs/integration/F-GC44_REAL_SWAP_MODFLOW6_END_TO_END.md`
- `docs/publication/PUB_RC_ACCELERATE_RESEARCH_DESIGN.md`
- `docs/publication/PUB_RC_ACCELERATE_LITERATURE_REGISTER.md`
- `docs/publication/PUB_COUPLING_BROADER_PUBLISHABILITY_REVIEW.md`
