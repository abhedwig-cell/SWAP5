# SWAP5-MODFLOW6 coupling concept synthesis

Date: 2026-09-21  
Status: RESEARCH SYNTHESIS, NO PRODUCTION CHANGE  
Research branch: `work/f-gc-dummy-swap-shared-storage@a0fe38bfa107e40c5f1ff0e840a479f42c8a5d53`  
Canonical authority reconciled at start: `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`

## 1. Start from one physical bucket

Take a unit-area 10 m vertical column. The surface elevation is 10 m, the initial groundwater head is 8 m, so the groundwater table is 2 m below surface. Let the physically active drainable storage coefficient be

```text
S = 0.20
```

and add 10 mm water with no ET, drainage, runoff, lateral flow, capillary resistance or other process.

The complete physical balance is simply

```text
Delta V = 0.010 m
Delta H = Delta V / S = 0.010 / 0.20 = 0.050 m
H1 = 8.050 m
```

Everything in this note is a controlled elaboration of that statement.

This thought experiment is **not architecture-neutral**. By declaring that SWAP and MODFLOW simultaneously describe the same groundwater system and that there is one groundwater level, it defines a shared-phreatic physical contract: one state and one physical storage volume. It is therefore a direct oracle for Contract S below. It is not, by itself, an oracle for the current mode-5 lower-interface coupling, which represents a different state unless an explicit equivalence limit is proven.

The first question in a coupled model is therefore not "what HCOF should be used?" It is:

> Which physical water volume does each model represent, which state controls that volume, and does the coupled residual count that physical volume exactly once?

Only after that question has an answer can an exchange coefficient or Jacobian be interpreted physically.

## 2. Vocabulary: keep the objects separate

The same dimensions can belong to different physical objects. Unit agreement is necessary for addition to one residual, but it is not semantic identity.

| Object | Typical unit | Kind | Physical meaning / ownership | Coupled residual role |
| --- | --- | --- | --- | --- |
| Physical state `H` | m | state | A measurable system state such as phreatic head. A physical state exists once, even if several numerical components hold copies. | Enters storage laws, boundary laws and process laws. |
| Shared state | m | state relation | One physical state constrained to be common to two submodels. Sharing a head does not imply sharing all internal states. | One unknown or one consistency condition, depending on numerical formulation. |
| Internal SWAP state `m` | state-specific, often m water equivalent or profile variables | state | Physical memory needed by the vadose-column response but not represented by MODFLOW head alone. | Enters SWAP storage/process response; normally not a MODFLOW state variable. |
| Physical stored volume `V` | m3, or m for unit-area water depth | volume | Water inventory of a declared physical domain. Every physical volume must be owned exactly once in the complete balance. | Its accepted change is a storage term. |
| Physical external flux `q_ext` | m/s; `Q_ext` m3/day | flux | Rain, pumping, lateral groundwater inflow, ET, drain discharge, etc. Crosses the boundary of the complete system being balanced. | Source or sink of the complete-system residual. |
| Internal transfer | m/s or m3/day | flux | Transfer between two states that both belong to the complete coupled system. | Appears with opposite signs in component balances and cancels from the complete-system balance. |
| Finite-resistance exchange `q_ex` | m/s | flux | A real flow between two physically distinct states, e.g. `q_ex=C(h_swap-h_gw)`. | Opposite signs in the two component residuals; cancels from the total system. |
| Storage response `dV/dH` | m2 volumetric, or dimensionless for unit-area storage depth | derivative of volume | Derivative of a physical inventory law. Physical only when `V(H,...)` itself is physically declared. | Contributes to the residual Jacobian through storage. |
| Process response `dET/dH`, `dq_drain/dH` | 1/s for areal flux/head | derivative of external flux | Sensitivity of a real source/sink process to head. | Jacobian contribution, but not storage. |
| Corrector response `dq_swap/dH` | 1/s | derivative of returned coupling flux | Finite-window response of the SWAP corrector/output to the coupling head. It may combine storage, process and memory effects. | Can be a valid coupling tangent without being a physical storage coefficient or interface conductance. |
| Numerical tangent / Jacobian | residual-unit per m | derivative of residual | Derivative of the equation the nonlinear/linear solver is currently solving. It may be a sum of several physical derivatives and numerical linearizations. | Solver object. |
| MODFLOW `HCOF` | m2/day for the current API term | affine coefficient | Backend coefficient in `Q(H)=HCOF*H-RHS`. It carries the chosen tangent into MODFLOW. | Numerical representation of a flux law. |
| MODFLOW `RHS` | m3/day | affine intercept coefficient | Completes the reference-point representation of the same affine flux law. It is not by itself "the recharge". | Numerical representation of a flux law. |
| Mass-ledger quantity | m3 or m water equivalent | integrated accounting quantity | Accepted storage change or accepted time-integrated external/internal flux with explicit sign and ownership. | Acceptance evidence; not automatically a prognostic state. |

Two additional distinctions are important.

First, **software ownership is not automatically physical volume ownership**. Current production authority says SWAP/FMR owns SWAP committed/candidate state and `Modflow6PreparedSolveSession` owns the live MODFLOW solve lifecycle. That does not by itself decide whether a specific groundwater storage volume is physically represented by SWAP, MODFLOW or a declared partition of both.

Second, **a shared head is not a complete shared state**. DSW11, DSW15 and DSW20 demonstrate this directly: equal phreatic head can coexist with different internal memory and therefore different future response.

Third, **computational representation is not physical storage ownership**. A SWAP predictor may simulate water and pressure throughout a saturated part of its one-dimensional profile in order to calculate a response, while the coupled residual may assign accepted regional groundwater storage to MODFLOW. Numerical overlap of state representation is therefore not by itself proof of physical storage double counting. Double counting occurs only when the same physical inventory change is included twice in the coupled mass residual.

## 3. Three coupling families

### 3.1 Shared-state h-link

There is one physical phreatic state `H`. There is no physical resistance between a "SWAP groundwater head" and a "MODFLOW groundwater head", because they are not two physical heads.

The most general transparent balance is

```text
V_total(H,m) = V_swap(H,m) + V_mf(H)
Delta V_total / dt = Q_external,total
```

where the partition `V_swap + V_mf` is allowed only when the two terms represent disjoint parts of one physical inventory.

For the memoryless linear bucket,

```text
V_total(H) - V_total(H0) = S_total (H-H0)
```

and therefore

```text
S_total = S_swap + S_mf
```

is valid if and only if `S_swap` and `S_mf` are a partition of one physical storage volume.

DSW01-DSW04 prove that arbitrary repartition of one declared `S_total=0.20` is physically invariant. DSW19 proves that duplicating the same storage is not a harmless implementation choice: the solver can converge to the wrong head.

A shared-state formulation can still contain internal SWAP memory:

```text
state = (H, m_swap)
```

The shared part is only `H`. `m_swap` can store water or encode profile history and must be continued consistently if it changes the next-window response.

### 3.2 Finite-resistance q-link

There are two genuinely distinct physical states:

```text
h_swap != h_gw
```

and a physical exchange law, for example

```text
q_ex = C (h_swap - h_gw)
```

For unit area, `q_ex` has units m/time and `C` has units 1/time.

The component balances are

```text
dV_swap/dt = Q_ext,swap - q_ex
dV_gw/dt   = Q_ext,gw   + q_ex
```

so the exchange cancels when both storages are included:

```text
d(V_swap+V_gw)/dt = Q_ext,swap + Q_ext,gw
```

Here two storage laws are legitimate because they belong to two physically distinct domains.

DSW08 and DSW18 prove the distinguishing limit signature:

- increasing storage reduces head response to a fixed net volume;
- increasing q-link conductance reduces the head difference and increases internal exchange.

As `C -> infinity`, the two heads can approach a common limit. That limit becomes equivalent to a shared-state formulation only when the two storage volumes remain physically disjoint and their sum is the intended common-head storage law. Infinite conductance does not repair duplicated storage ownership.

### 3.3 Boundary / sequential exchange

One model supplies a state as boundary condition and the other returns a flux. A simple example is:

```text
H_gw^n -> vadose model -> q_bottom
q_bottom -> groundwater model -> H_gw^(n+1)
```

This is not automatically a shared-state h-link and not automatically a physical q-link.

The key questions are temporal:

- is the supplied head frozen over the window?
- is the returned flux an instantaneous flux, a window average or an integrated volume?
- is there outer iteration?
- if there is iteration, what common residual is being closed?
- how is state updated when the boundary changes?

The HYDRUS-MODFLOW literature provides a clear example: the groundwater table is used as a vadose-zone boundary and the computed bottom flux is passed back as recharge. Beegum et al. (2018) explicitly describe artifacts when the groundwater table changes stepwise between MODFLOW time steps and note that the coupled mass balances are then maintained separately rather than as one fully integrated balance.

Sequential exchange can be useful and correct. It simply has different semantics from declaring one common physical unknown.

## 4. DSW01-DSW20 concept matrix

The matrix below uses only the qualified testbank and its diagnosed strict-gate exceptions. DSW05 and DSW09 preserve their original failed numerical certification gates; their physical questions are nevertheless resolved by the explicitly qualified diagnostics.

| DSW | Conceptual question | Evidence / result | What it establishes |
| --- | --- | --- | --- |
| DSW01 | What happens if dummy-SWAP response and MODFLOW storage overlap? | analytic + live one-cell oracle | The 10 mm / 0.20 physical answer is +5 cm. The positive-`u` overlap probe is not the consistent one-storage partition. |
| DSW02 | Can one physical storage be split between numerical components? | storage ownership partition sweep | Yes. Any consistent split of the same total 0.20 gives the same 8.05 m result. Counting the same storage twice gives the predicted half response. |
| DSW03 | Does storage ownership depend on where external forcing enters? | MODFLOW-owned source sweep | No. The same partition invariance holds when the external source enters through MODFLOW. |
| DSW04 | Do SWAP-side and MODFLOW-side forcing superpose in the linear control? | 6 mm SWAP-side + 4 mm MODFLOW-side live cases | Yes. 3 cm + 2 cm = 5 cm exactly within the live oracle. This isolates forcing ownership from storage ownership. |
| DSW05 | Is the physical linear response timestep invariant? | original strict certificate failed; DSW05W diagnostic qualified | Physical head is timestep invariant to machine precision. The preserved failure is an IMS residual-certificate issue, not hydrological timestep dependence. |
| DSW06 | Does affine reference head have physical meaning? | exact reanchor sweep `H_ref=7..10 m` | No, not for one unchanged affine law. Exact reanchoring leaves HCOF/RHS and the physical solution invariant. |
| DSW07 | What is the actual assembled residual/Jacobian? | exact residual + centered finite difference | For consistent storage partition the Jacobian is total storage/time. For the DSW01 positive-`u` overlap, the storage and API slopes cancel, producing zero Jacobian and an identically zero residual in the preregistered construction. |
| DSW08 | What changes when a real interface resistance exists? | conductance sweep `10^-3..10^3 /day` | Two heads and a physical exchange flux are legitimate. High conductance collapses the head gap toward the common-head limit. |
| DSW09 | Can nonlinear storage be represented by repeated affine reanchoring? | physical oracle supported; original default solver gate failed; DSW09R/X/Y diagnose numerics | Yes for the transparent nonlinear law. External nonlinear residual closure and MODFLOW subsystem certification are separate objects. |
| DSW10 | Is a local tangent the same as stored volume? | depth-varying storage with integrated oracle | No. The correct physical oracle is the integral of the storage law; the tangent is only its local derivative. |
| DSW11 | Is shared head a complete coupled state? | same head, different internal memory | No. Hidden/internal vadose memory can change the next response at identical phreatic head. |
| DSW12 | Can an ET response have storage-like units? | head-dependent ET sink | Yes. `dET/dH` can have the same dimensions as storage/time or conductance while remaining an external sink response. |
| DSW13 | Can drainage have the same issue? | threshold drain sink | Yes. Drain conductance is a physical sink derivative, not shared storage and not interface conductance. |
| DSW14 | Can storage, forcing, ET and drainage coexist without semantic collapse? | composed live case | Yes, if ownership and signs stay explicit. Equal derivative units do not merge the processes. |
| DSW15 | Does forcing order matter? | early/late forcing, memoryless versus memory surrogate | Not in the linear memoryless control. It does with internal memory, even at equal total input and exact total mass closure. |
| DSW16 | How do multiple SWAP columns map to one MODFLOW cell in the linear family? | 3-tile N:1 area-weighted oracle | HCOF/RHS responses sum area-weightedly and are permutation invariant. This is algebra, not proof of heterogeneous Richards upscaling. |
| DSW17 | Is transfer between vadose memory and groundwater net recharge? | bidirectional equal/opposite transfer | Not for the complete system. It changes component inventories/head but cancels from the complete-system ledger. |
| DSW18 | Can storage and q-link conductance be distinguished by limits? | side-by-side sensitivity families | Yes. Their limit signatures are different even when coefficient dimensions look similar. |
| DSW19 | Does solver convergence establish coupling correctness? | three deliberately wrong but converged equations | No. Duplicate storage, wrong storage-response sign and reversed forcing all converge deterministically to physically wrong states. |
| DSW20 | Can the concepts be maintained over multiple unequal windows? | five-window manufactured trajectory | Yes. Explicit head + memory continuation and complete window/cumulative ledgers close to machine precision under ET, drainage, lateral input and internal transfer. |

## 5. What is now actually proven

Within the transparent DSW01-DSW20 scope:

1. **Storage ownership is a physical-domain statement.** One physical water volume may be partitioned numerically, but the complete coupled balance may count it only once.
2. **Shared head and finite-resistance exchange are different coupling families.** The former has one physical head; the latter has two states connected by a physical flux law.
3. **A shared head does not eliminate SWAP memory.** The minimum coupled state can be `(H, internal SWAP state)`, not merely `H`.
4. **An internal transfer is not an external source.** It must cancel from the complete coupled mass balance.
5. **A tangent is not its parent physical quantity.** `dV/dH`, `dET/dH`, `dq_drain/dH` and `dq_corrector/dH` may share dimensions and all enter a Jacobian, while representing different physics.
6. **HCOF/RHS are an affine numerical representation.** Exact reanchoring does not change the underlying physical law.
7. **Subsystem convergence, coupled residual closure and physical mass closure are distinct acceptance objects.**
8. **Linear N:1 response aggregation is exactly area weighted.** No broader heterogeneous hydrological transferability follows from that algebra.

The testbank does **not** prove that production SWAP-MODFLOW6 must use an h-link. It also does **not** prove that production `u` is physical storage, non-storage, or a finite-resistance conductance.

## 6. Production affine response mapped onto this vocabulary

The current production source constructs

```text
u   = dt / (dH_bot,end / dq_bot)
q_u = u * (H_bot,end - H_bot,start) / dt - q_bot
```

with `q_bot` positive into SWAP and public `q_u` positive outward from SWAP.

F-GC40 then represents the tile/cell response as

```text
q_u(H) ~= q_ref + (u/dt) (H-H_ref)
dq_u/dH = u/dt
```

and F-GC33 converts it to

```text
Q(H) = HCOF*H - RHS
HCOF = A * dq_u/dH
```

after unit conversion.

This establishes the **mathematical** meaning of production `u`: it is the inverse finite-window head sensitivity to the imposed SWAP lower-boundary predictor flux, scaled by the window duration.

It does not yet establish one unique **physical decomposition**. In real SWAP the observed terminal-head sensitivity can include:

- water-content/profile storage change;
- movement of the phreatic surface;
- changes in top and internal fluxes;
- root uptake;
- drainage;
- other state-dependent sinks/sources;
- effects of internal profile memory;
- the finite-window trajectory itself.

Therefore `u/dt` should first be described as the **production affine response slope**. Existing real-SWAP evidence below makes that wording more precise: it is the partial slope of the historical affine `q_u(H)` extension when predictor `u` and `q_bot` are held fixed. It is not, in general, the total derivative across neighbouring predictor trajectories and it is not automatically the derivative of the accepted corrector flux.

The fact that the field name contains `storage_coefficient` is historical/structural evidence, not sufficient proof of physical storage ownership.

### 6.1 Algebraic meaning of `q_u`

The historical equation can be rearranged without interpretation:

```text
q_u = u * Delta H / dt - q_bot

u * Delta H / dt = q_u + q_bot
```

Here native `q_bot` is positive **into** the SWAP profile. Therefore `-q_bot` has the sign of a bottom-outward flux.

If, for a bounded regime, `u * Delta H` approximates the accepted SWAP storage change, then

```text
q_u
~= storage-change rate + bottom-outward rate
```

and the SWAP water balance says that this sum is the **net contribution of the non-bottom processes** over the same window.

That statement explains MAP03 directly. In its storage-dominated fixture:

```text
d(storage change)/dH        ~= +u
d(bottom-outward amount)/dH ~= -u
d(their sum)/dH              = 0
```

so a head-independent non-bottom forcing produces almost no **total** variation of reconstructed `q_u` across neighbouring predictor trajectories. MAP07 measures exactly that cancellation.

Thus `q_u` should not be described as though it were simply the physical lower-boundary exchange returned by SWAP. It is a response-condensed balance term constructed from storage/head response and the predictor bottom flux.

### 6.2 Historical design evidence for the balance-condensation interpretation

A 2024 SWAP-MODFLOW proof-of-concept presentation provides useful historical design evidence, although it is not current production authority.

The presentation distinguishes:

- a MODFLOW-to-SWAP net flux representing regional flow and local drainage;
- a SWAP-to-MODFLOW recharge-like flux between unsaturated and saturated water;
- a coefficient `u` controlling how the MODFLOW head responds;
- a SWAP groundwater level that is not assumed equal to the MODFLOW head because of resistance within the phreatic layer.

Its predictor diagram explicitly says: determine the bottom flux from MODFLOW, run SWAP, hold `u` fixed and calculate recharge `Q_u` once, then iterate MODFLOW. The coefficient is estimated from two SWAP simulations with perturbed lower-boundary flux:

```text
u = (q2-q1) * dt / (H2-H1)
```

where `H` is described as the hydraulic head at the bottom of the SWAP column.

Combined with the production equation, this supports the bounded interpretation:

> `u` and `q_u` are a local finite-window condensation of the SWAP column into a groundwater-balance response pair. `u` carries the head response; `q_u` is the matching recharge/balance intercept. Neither object is, by definition alone, the real SWAP bottom-exchange flux.

This also explains why the current production affine line can have a positive partial slope `+u/dt` while the actual prescribed-head corrector bottom-outward flux has a negative local slope. They are derivatives of different objects.

The historical presentation is consistent with this interpretation but does not settle current physical domain ownership. The current mode-5 implementation has since made the exchanged state a typed lower coupling-plane head, and MAP11/MAP12 remain the controlling evidence for that current contract.

## 7. Reconciliation with existing real-SWAP evidence

The branch already contains a substantial real-SWAP response campaign. It must be reconciled before any new response experiment is proposed.

The results are mutually consistent once **state change**, **state sensitivity**, **corrector flux sensitivity** and **affine iteration slope** are kept separate.

### 7.1 Production `u` is not a static storage amount

DSW21 retrospectively showed that the F-GC44 predictor can have zero net whole-window storage change while `u` is nonzero. That is not a contradiction with the later storage-sensitivity results. A state can return to the same net inventory over one trajectory while the inventory remains sensitive to a perturbation of the terminal/boundary head.

MAP10 provides the stronger limitation: in the drainage-free B1/B2/B4 family, `u` changes strongly with coupling-window duration. The corresponding `u/dt` also changes. Production `u` therefore cannot be treated as a universal time-independent specific yield.

### 7.2 In the drainage-free local corrector, `u` tracks storage sensitivity

MAP02 measured the real prescribed-head corrector response around one immutable origin. The real corrector flux derivative had approximately the same magnitude as the production affine slope but the opposite sign. The accepted whole-window ledger matched the integrated corrector flux.

MAP03 then decomposed the same local response:

```text
J_S = d(whole-column storage change)/dH
J_R = d(bottom-outward exchange)/dH

J_S  ~= +u
J_R  ~= -u
J_S + J_R ~= 0
```

for the drainage-free fixture.

This is a physical mass-balance result. It says that, locally in that fixture, the finite-window SWAP storage sensitivity and bottom-exchange sensitivity are equal and opposite.

It does **not** say that MODFLOW owns the same storage volume.

### 7.3 The production affine slope is a partial derivative, not the total historical `q_u` derivative

MAP07 audited the full historical transform across neighbouring flux-driven predictor trajectories.

Production F-GC40/F-GC33 uses

```text
(dq_u/dH)_affine = +u/dt
```

with predictor `u` and `q_bot` held fixed while the affine term is evaluated or reanchored.

Across neighbouring predictor trajectories, however, `q_bot` itself changes with `H`. MAP07 found that this variation cancels the `+u/dt` contribution to first order in the inspected E4 plateau. The observed **total** derivative of historical `q_u` across those predictor trajectories is therefore near zero, not `+u/dt`.

Hence three different derivatives must remain distinct:

```text
physical storage response:        d(Delta S)/dH
real corrector exchange response: dq_corrector/dH
production affine partial slope:  (partial q_u/partial H)_(u,qbot fixed)
```

They can be related by the water balance without being the same mathematical object.

### 7.4 The affine slope can act as iteration policy

MAP04 compared the current `+u/dt` slope, a zero-slope intercept-only policy and the independently measured local corrector slope in the weak F-GC45 fixture. Accepted physics and ledger were effectively invariant, while the coupling paths differed.

MAP05/MAP05A/MAP06 show why this does not make slope choice irrelevant. In the stronger B3 regime, the path taken by the outer coupling iteration can cross a fragmented prescribed-head corrector admissibility set. Two nonzero slope policies reached the same accepted physics, while intercept-only encountered a deterministic corrector-domain failure.

The current affine slope therefore has evidence as a **numerical iteration-response policy**. Its physical acceptability is still checked by the real corrector and accepted mass ledger.

### 7.5 Active drainage does not restore a universal `u=storage` identity

MAP09A repeated the storage/bottom-exchange decomposition in a frozen active-drainage fixture.

At the preregistered local pair:

```text
J_S / u       = 0.994178...
(-J_R) / u   = 0.994178...
J_nonbottom  = J_S + J_R = 0
```

The local storage and bottom-exchange derivatives still cancel, but production `u` is about 0.58% larger than the accepted-corrector storage derivative. The result explicitly forbids identifying production `u` with exact physical storage under active drainage.

This one local result also does not prove that drainage is generally head-insensitive.

### 7.6 Current production mode 5 is not a proven shared-phreatic h-link

MAP11 is the controlling domain-ownership correction.

The F-GC45 qualification fixture does not declare the MODFLOW STO volume and SWAP/FMR column to be one geometrically coextensive physical storage volume. The explicit exchanged state in the current F-GC route is a lower coupling-plane hydraulic head.

MAP12 additionally shows that legacy prescribed groundwater-level semantics and current mode-5 prescribed lower-boundary-head semantics are different contracts. They can coincide in special hydrostatic/zero-resistance limits, but equality must be demonstrated rather than assumed.

Therefore the existing real-SWAP evidence supports this bounded description:

> Current F-GC is a head-matched, iterated boundary coupling with a finite-window SWAP response linearization and real-corrector/mass-ledger acceptance. It is not currently proven to be either a one-state phreatic h-link or a two-reservoir finite-resistance q-link.

That statement is descriptive, not a recommendation for the final architecture.

## 8. What remains genuinely open

The broad question "what is `u`?" is now too coarse. Several parts are already answered.

The remaining scientific questions are narrower.

### Gap A: intended physical domain ownership for a future coupled product

Before changing storage representation, define the intended physical partition:

```text
What saturated and unsaturated water volumes belong to SWAP?
What volume belongs to MODFLOW?
Is any volume geometrically coextensive?
Which physical state controls each volume?
```

Without this declaration, comparing `u` with MODFLOW `Sy` cannot establish either valid partitioning or double counting.

### Gap B: true phreatic shared-state response, only if that family is to be investigated

A true h-link requires a typed common phreatic coordinate and a complete-profile storage law. Existing HLINK/LOW01 work may support that research, but it is not architecture authority.

The already existing DSW23/DSW24/DSW25 and HLINK01 evidence is useful only as supporting limit evidence:

- coextensive storage duplication has the predicted wrong-volume signature;
- head collapse alone does not establish h-link equivalence;
- lower-interface head equals phreatic head only in the hydrostatic/zero-gradient or zero-resistance limit.

The real-SWAP shared-phreatic response remains a separate question and should be pursued only if the physical-domain definition says this is the coupling family we actually need to evaluate.

### Gap C: real SWAP internal state required across coupling windows

DSW11/15/20 prove generically that head can be an incomplete state. The current real-SWAP transaction architecture preserves the full committed SWAP state, so production execution is not head-only.

What remains scientifically useful is to identify which parts of that internal state materially control the next groundwater response. That is a model-reduction/interpretation question, not a prerequisite for preserving the current full-state transaction semantics.

## 9. Decision on the next experiment

**No new dummy experiment is scientifically required now, and no new generic real-SWAP `u/q_u` response experiment is required either.**

DSW01-DSW20 already close the basic coupling taxonomy. MAP02-MAP12 already perform the first real-SWAP separation requested by this workstream:

- production affine response;
- true prescribed-head corrector response;
- whole-window physical storage response;
- accepted mass ledger;
- partial versus total `q_u` derivative;
- lower-interface versus phreatic state semantics;
- domain ownership limits.

The next step is therefore not "collect more response slopes". It is to make the **physical domain and state definition** explicit for the coupling we intend to study.

Only after that definition exists can one choose a genuinely discriminating next experiment.

Two possible future branches must remain conditional:

1. If the intended physical system has one coextensive phreatic state, use a true shared-phreatic experiment and derive combined storage ownership from the complete water balance.
2. If the intended physical system has distinct states separated by a real resistance, identify those states and derive the physical exchange law before fitting or publishing any conductance.

If neither physical statement applies and the desired implementation remains a head/flux boundary exchange, then the research question is instead how accurately and robustly the partitioned algorithm reproduces the desired coupled water balance over its timestep envelope.

This decision explicitly prevents HLINK/LOW01 readiness from becoming an accidental architecture-selection mechanism.

## 10. Physical-domain contracts that must be distinguished

The next architecture discussion needs a declared physical control volume before any coefficient is assigned. At least three physically different contracts are plausible.

### 10.1 Contract S: one shared phreatic state with combined storage

The original 10 m / 10 mm / `S=0.20` thought experiment belongs to this family by construction.

Physical statement:

```text
H_phreatic is one physical state.
SWAP and MODFLOW do not own overlapping copies of the same water volume.
```

A complete-system balance can be written as

```text
Delta[V_uz(H,m) + V_gw(H)] =
    atmospheric input
  + lateral groundwater input
  - ET
  - drainage
  - other external outputs
```

where `V_uz` contains the SWAP-owned complete-profile/unsaturated response and `V_gw` contains only the MODFLOW-owned groundwater storage that is not already in `V_uz`.

The time-discrete storage tangent is then

```text
dV_total/dH = dV_uz/dH + dV_gw/dH
```

with no overlap and no missing volume.

There is no physical q-link between two phreatic heads because there are not two physical phreatic heads. An internal bookkeeping flux may be useful numerically, but it cannot create or remove complete-system water.

This is the conceptual family described by Van Walsum and Veldhuizen for SIMGRO/MetaSWAP: the phreatic elevation is the shared state and both sides use one combined storage relationship.

### 10.2 Contract I: geometric interface split with head/flux continuity

Physical statement:

```text
SWAP owns the column above a coupling plane.
MODFLOW owns the groundwater domain below that plane.
The domains are disjoint in physical volume.
```

The interface carries two continuity conditions:

```text
h_swap,interface = h_mf,interface
q_swap,out        = q_mf,in
```

but the phreatic elevation inside the SWAP column does not have to equal the lower-interface hydraulic head when there is a vertical gradient.

The component balances are

```text
Delta V_swap = Q_top - Q_ET - Q_drain - Q_interface
Delta V_mf   = Q_lateral + Q_interface - Q_other
```

and `Q_interface` cancels from the complete-system balance.

This is not the same as the lumped finite-resistance q-link of DSW08. The physical interface has one continuous hydraulic head in the continuum limit; the flux is generated by the resolved dynamics on either side. Numerically, a partitioned implementation can still use a Dirichlet-Neumann iteration: one side receives a trial head and returns a flux.

The current F-GC mode-5 evidence is closest to this **boundary/interface family**. The production source maps the coupling hydraulic head directly to SWAP `bottom_head`, and the predictor bottom-face source explicitly calls that quantity the coupling-plane head rather than the phreatic groundwater level.

One important discretization question therefore remains explicit: a MODFLOW cell/node head is used as the SWAP lower-face head. Whether that representative MODFLOW head is an adequate approximation of the physical interface head depends on the groundwater discretization and vertical gradient. It is not an identity that follows from equal units.

This also explains why the original 8.00 -> 8.05 m shared-phreatic oracle cannot be used as a direct acceptance test for the current mode-5 route. To connect the two, one must additionally prove the hydrostatic/vanishing-resistance state equivalence and consistent storage ownership conditions already isolated by MAP12 and DSW24/DSW25.

### 10.3 Contract Q: two physical lumped states with a real resistance

Physical statement:

```text
h_swap and h_gw are distinct physical states.
A real unresolved resistance separates them.
```

Then

```text
q_ex = C (h_swap-h_gw)
```

is a physical constitutive exchange law, and both sides may own distinct physical storage.

This family is appropriate only if the two states and the resistance have an independent physical interpretation. It must not be manufactured by relabeling the current affine `u/dt` slope as a conductance.

### 10.4 Invalid shortcut: coextensive duplicate storage

If SWAP and MODFLOW are declared to represent the same physical phreatic volume while both independently retain the full storage response of that volume, the complete-system residual counts one inventory twice.

DSW01/02/19 already establish the algebraic signature. The later DSW23/HLINK01 coextensive controls provide supporting mechanism evidence, but are not needed to derive the principle.

A numerically closed bookkeeping balance does not rescue this case. If two ledgers each assign part of the same geometric volume change to separate storage owners, their sum can equal the forcing while the actual one-volume head change is still wrong.

### 10.5 Decision questions before architecture

For every intended production configuration, answer these questions explicitly:

```text
1. What is the SWAP physical control volume?
2. What is the MODFLOW physical control volume?
3. Do those volumes overlap geometrically?
4. Is the exchanged head a phreatic elevation, an interface hydraulic head,
   a MODFLOW cell representative head, or another state?
5. Is there one physical head state or two?
6. If there are two, what physical law determines exchange?
7. Which storage-volume change belongs to each control volume?
8. Which fluxes are external to the complete system and which are internal?
9. Which SWAP internal states must persist even when the coupling head is shared?
10. Which derivative is needed for the nonlinear algorithm, independently of
    which quantity that derivative linearizes?
```

Only after these ten items are declared should the code decide whether MODFLOW STO is retained, replaced, partitioned or supplemented by an API term.

### 10.6 Derive the residual from the water balance before choosing HCOF

This is the central sign and ownership check.

Use unit horizontal area and define `E_bottom` as the accepted whole-window water amount **outward from SWAP and into groundwater**.

For an interface-split SWAP control volume:

```text
Delta V_swap = W_swap,net - E_bottom
```

where `W_swap,net` contains only external SWAP-side input minus external sinks over the same window.

Therefore

```text
E_bottom(H) = W_swap,net(H) - Delta V_swap(H)
```

and the physical response is

```text
dE_bottom/dH =
    dW_swap,net/dH
  - d(Delta V_swap)/dH
```

For a storage-only perturbation with head-independent forcing:

```text
dE_bottom/dH = -d(Delta V_swap)/dH
```

This is exactly the sign structure observed in MAP03:

```text
J_S ~= +u
J_R = dE_bottom/dH ~= -u
```

over its bounded drainage-free fixture.

The groundwater component balance can then be written schematically as

```text
Delta V_mf = W_mf,external + E_bottom
```

or as the residual

```text
F(H) =
    Delta V_mf(H)
  - W_mf,external(H)
  - E_bottom(H)
  = 0
```

with

```text
dF/dH =
    d(Delta V_mf)/dH
  - dW_mf,external/dH
  - dE_bottom/dH
```

In the storage-only case this becomes

```text
dF/dH = S_mf + S_swap
```

when `S_mf` and `S_swap` are disjoint storage responses.

That derivation explains why **the same storage response can appear with an opposite sign in a physical exchange-flux tangent**.

#### Current production affine slope

Current F-GC40/F-GC33 instead publishes the local affine extension

```text
q_u,affine(H) = q_ref + (u/dt)(H-H_ref)
```

so its API flux slope is

```text
dq_u,affine/dH = +u/dt
```

MAP02/MAP03 show that the true corrector bottom-outward flux has the opposite local slope in the inspected storage-dominated fixture. MAP07 further shows that `+u/dt` is a partial derivative of the historical affine extension with predictor `u` and `q_bot` held fixed, not the total derivative across neighbouring predictor trajectories.

Therefore:

```text
production affine HCOF
!= automatically physical dQ_corrector/dH
!= automatically storage dV/dH divided by dt
!= physical q-link conductance
```

even though their dimensions can coincide.

The current algorithm can still be physically accepted because the affine term is reanchored to a real SWAP corrector flux and the accepted whole-window exchange ledger is authoritative. MAP04/MAP05A show bounded cases where different affine slope policies reach essentially the same accepted physics while following different iteration paths.

A useful way to read the affine predictor is therefore:

```text
given the predictor bottom flux q_bot*,
what recharge/balance term q_u(H) would make
u * (H-H_start) / dt = q_u(H) + q_bot*
hold at another trial H?
```

Holding `q_bot*` fixed gives the partial slope `+u/dt`. Re-running SWAP at the new head changes the physical bottom flux itself; that is the different corrector response measured by MAP02/MAP03. This distinction removes the apparent sign paradox without asserting that either derivative is a universal physical coefficient.

#### Shared-phreatic representation

For Contract S there is no need to invent a physical transfer between two coextensive copies of the same groundwater volume. The complete residual can be written directly:

```text
F_shared(H,m) =
    Delta V_swap(H,m)
  + Delta V_mf(H)
  - W_external,total(H,m)
  = 0
```

Its Jacobian follows immediately:

```text
dF_shared/dH =
    d(Delta V_swap)/dH
  + d(Delta V_mf)/dH
  - dW_external,total/dH
```

A numerical implementation may represent this balance in several algebraically equivalent ways:

1. put the combined storage response into MODFLOW STO and pass only true external source/sink fluxes;
2. retain a non-overlapping MODFLOW storage share and represent the complementary SWAP balance as an equivalent head-dependent API source;
3. use another monolithic/partitioned representation that reproduces exactly the same residual and derivative.

What is **not** equivalent is retaining the complete physical storage in MODFLOW and then adding the same SWAP storage response again as though it were an independent volume.

In a shared-state implementation, an API term derived from

```text
W_equiv,swap(H) =
    W_swap,external(H)
  - Delta V_swap(H)
```

is an **algebraic contribution to the combined residual**. It should not be mislabeled as a real finite-resistance exchange flux merely because it enters MODFLOW through a flux-shaped package.

This is the route by which the final HCOF/RHS semantics must be derived: first choose the physical balance, then derive the residual, then differentiate that residual, and only then map its affine pieces into MODFLOW coefficients.

## 11. Relation to literature

The literature is useful here because it contains examples of all three conceptual patterns. It should be used to classify coupling semantics, not to retrofit authority onto the current SWAP5 implementation.

| Reference | Exchanged/common state | Flux/storage treatment | Closest family here | What it contributes |
| --- | --- | --- | --- | --- |
| Van Walsum & Veldhuizen (2011), SIMGRO/MetaSWAP-MODFLOW | Phreatic level is explicitly a shared state in the h-link. The paper contrasts this with a q-link in which the MODFLOW head differs from the SVAT phreatic level. | The shared-state method derives the complete vertical-profile storage relation from MetaSWAP and lets both model contributions update the same phreatic state. The paper also shows the q-link limit as resistance and interface distance approach zero. | Contract S, with Contract Q shown as a different construction | Strong support for the distinction between one shared phreatic state and a finite-resistance flux link. It also shows why forcing an artificial resistance at a naturally continuous saturated-unsaturated transition is a modelling choice, not a necessity. |
| Xu et al. (2012), SWAP-MODFLOW-2000 | MODFLOW provides averaged water-table depth for the SWAP bottom-boundary condition. | SWAP provides net groundwater recharge back to MODFLOW. | Boundary/sequential or iterated head-flux exchange | Demonstrates a SWAP-specific coupling tradition in which water-table information and recharge are exchanged rather than declaring the two solvers to share one complete state vector. |
| Beegum et al. (2018), HYDRUS-MODFLOW | MODFLOW water-table depth becomes the lower boundary of the HYDRUS profile. | Bottom-profile flux is returned to MODFLOW as recharge. The paper specifically diagnoses spurious interface fluxes caused by discontinuous time-step updates of the boundary state. | Boundary/sequential exchange | Shows that temporal semantics of a head/flux boundary exchange are physically consequential; a mass-conserving interface can still be dynamically poor when boundary state is updated inconsistently in time. |
| Current iMOD Coupler MetaSWAP-MODFLOW6 technical reference | MODFLOW sends heads to MetaSWAP. | MetaSWAP provides recharge and explicitly sets storage in coupled MODFLOW cells; multiple SVAT storages are summed for an N:1 cell. | Operational shared-storage implementation related to Contract S | A modern implementation reference showing that storage ownership can be actively transferred/controlled by the vadose component rather than simply added to an independent MODFLOW storage term. It is an external architecture reference, not SWAP5 authority. |

### 11.1 Van Walsum and Veldhuizen: the strongest shared-state reference

Van Walsum and Veldhuizen (2011), *Integration of models using shared state variables: Implementation in the regional hydrologic modelling system SIMGRO*, Journal of Hydrology 409, 363-370, DOI 10.1016/j.jhydrol.2011.08.036.

Their Fig. 1 makes the taxonomy unusually explicit: several MetaSWAP columns can share the phreatic state of one MODFLOW cell through h-links, while a q-link keeps a different MODFLOW head and SVAT phreatic level connected by a finite-resistance relation.

The paper first describes a q-link

```text
q = Delta h / c_bot
```

and then explains the zero-distance/zero-resistance limiting problem: as the artificial boundary approaches the phreatic surface, the resistance tends to zero and iterative flux-link convergence becomes difficult. Their h-link removes that artificial split by using the phreatic level itself as a shared state variable.

The storage treatment is equally relevant. MetaSWAP constructs a storage relationship for the **complete vertical profile** as a function of phreatic level. The paper states explicitly that the balance control volume comprises both the saturated and unsaturated zone. MetaSWAP supplies MODFLOW with the storage coefficient derived from that complete-profile storage table; the MODFLOW storage calculation then serves the numerical role of making the MODFLOW head converge to the same shared phreatic level while the overall water-balance integrity is administered by MetaSWAP.

That is conceptually much closer to the original 10 m bucket than the current SWAP5 mode-5 lower-face-head contract.

Their q-link verification provides an especially useful limiting control. To make the q-link approach the h-link, they reduce the bottom resistance toward zero **and** require that there be no additional storage in the MODFLOW model. In their numerical approximation that extra MODFLOW storage is made very small. This directly supports the dummy-test conclusion that head collapse alone is insufficient: storage ownership must converge to the same one-volume contract as well.

The important limit on the analogy is that MetaSWAP is a reduced storage/flux model specifically designed around this shared-state formulation. Real SWAP has a full Richards profile and internal memory. A shared phreatic coordinate would therefore not make the rest of the SWAP state disappear.

### 11.2 Xu et al.: SWAP-specific head/recharge exchange

Xu et al. (2012), *Integration of SWAP and MODFLOW-2000 for modeling groundwater dynamics in shallow water table areas*, Journal of Hydrology 412-413, 170-181, DOI 10.1016/j.jhydrol.2011.07.002.

The reported coupling sends averaged MODFLOW water-table depth to SWAP to define its lower-boundary condition, while SWAP returns net groundwater recharge to MODFLOW.

That pattern is valuable precisely because it should **not** automatically be called a shared-state h-link. It is an exchange of a groundwater state descriptor and a resulting flux between two models. Its physical and numerical correctness depends on the timing, spatial aggregation and ownership of those exchanged quantities.

### 11.3 Beegum et al.: temporal boundary exchange is part of the physics

Beegum et al. (2018), *Updating the Coupling Algorithm between HYDRUS and MODFLOW in the HYDRUS Package for MODFLOW*, Vadose Zone Journal 17, DOI 10.2136/vzj2018.02.0034.

In the original HPM scheme, the bottom flux of the HYDRUS profile is passed to MODFLOW as recharge and the MODFLOW water-table depth at the end of the groundwater timestep becomes the lower boundary for the profile. Holding that groundwater table fixed throughout the MODFLOW timestep and then changing it abruptly produced unrealistic bottom inflow/outflow spikes.

This is directly relevant to SWAP5: even after state and flux ownership are conceptually correct, the coupling window and state-update chronology are part of the physical approximation. "Head goes one way and flux comes back" is not a complete coupling definition.

### 11.4 Current MetaSWAP-MODFLOW6 as an implementation reference

The current iMOD Coupler technical documentation states that MODFLOW sends head to MetaSWAP, while MetaSWAP sends recharge and **sets storage in the coupled MODFLOW cells**. For multiple SVATs mapped to one MODFLOW cell, those storages are summed.

That is a concrete operational continuation of the same ownership idea: the vadose component does not merely add another storage-shaped response on top of an untouched independent groundwater storage term; the coupled storage is explicitly set as part of the exchange contract. It strengthens the case that storage ownership must be an explicit part of the coupling contract.

It does not imply that SWAP5 should copy this mechanism. The physical state representation and internal memory of real SWAP differ materially from MetaSWAP, so any transfer of the shared-state idea must be re-derived from the SWAP water balance and tested prospectively.

### 11.5 Historical SWAP-MODFLOW proof-of-concept evidence

A Wageningen University & Research presentation from 18 January 2024, *Koppeling SWAP-MODFLOW*, is useful as historical design context.

It explicitly distinguishes the SWAP-computed groundwater level from the MODFLOW head because of resistance in the phreatic layer, labels the exchanged pair `u, q_u`, describes the SWAP-to-MODFLOW quantity as recharge plus a storage-response coefficient, and derives `u` from perturbed lower-boundary-flux SWAP simulations.

This historical material strongly supports reading `q_u/u` as a reduced groundwater-equation response representation rather than as a literal copy of the current accepted bottom exchange.

It remains secondary evidence. Current semantics are controlled by current source, typed contracts and qualified MAP results.

### 11.6 Literature conclusion

The literature supports the distinction that the dummy testbank already forced mathematically:

```text
shared phreatic state
!= finite-resistance two-state link
!= boundary head/flux exchange
```

It also reinforces two additional points:

```text
storage ownership is part of the coupling physics
temporal exchange semantics are part of the coupling approximation
```

None of these references determines the meaning of the current SWAP5 production `u`, HCOF or RHS. That meaning remains source- and evidence-bound to the current implementation and the MAP audits above.

## 12. Architectural implication, deliberately deferred

No production coupling architecture change follows from this synthesis alone.

In particular:

- do not promote HLINK01-05 from research aid to architecture authority;
- do not rename `u` to physical storage or physical conductance;
- do not remove or duplicate MODFLOW STO based on the dummy alone;
- do not infer that bottom-mode-5 prescribed head proves a shared-state physical topology;
- do not infer that an affine coupling flux proves a finite-resistance interface.

The architecture decision must be derived from an explicit declaration of physical domain/state/storage ownership and then tested against the already separated real-SWAP response objects. Existing HLINK/LOW01 work remains supporting research, not a prior architecture choice.

## 13. Evidence authority

Primary repository evidence:

- `integration/research/GC_DUMMY_SWAP_TESTBANK_STATUS.json`
- DSW01-DSW20 preregistration/result/diagnostic records
- `tests/research/run_gc_dummy_swap_dsw01.sh`
- `src/runtime/mod_modflow6_swap_predictor_response.f90`
- `src/runtime/mod_modflow6_multiswap_cell_response.f90`
- `src/runtime/mod_modflow6_linear_response_backend.f90`
- `docs/integration/F-GC33_MODFLOW6_LINEAR_RESPONSE_BACKEND.md`
- `docs/integration/F-GC40_MULTISWAP_MODFLOW6_CELL_RESPONSE.md`
- `docs/status-a/POST_STATUS_A_CURRENT_STATE.md`
- `integration/research/GC_DUMMY_SWAP_DSW21_SEMANTIC_AUDIT.json`
- `integration/research/GC_REAL_SWAP_MAP02_RESULT.json` through `GC_REAL_SWAP_MAP12_LEGACY_HEAD_SEMANTICS_AUDIT.json`
- DSW23/DSW24/DSW25 and HLINK01 only as supporting shared-phreatic/limit evidence, with their recorded qualification bounds

The current synthesis changes no production source and claims no production requalification.
