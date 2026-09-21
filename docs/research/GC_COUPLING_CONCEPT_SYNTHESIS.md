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

Therefore `u/dt` is currently safest to call the **production corrector-response tangent carrier** until an independent real-SWAP mass/response audit shows a narrower physical identity.

The fact that the field name contains `storage_coefficient` is historical/structural evidence, not sufficient proof of physical storage ownership.

## 7. Remaining conceptual gaps

### Gap A: real-SWAP decomposition of the production response

For one fixed accepted origin and coupling window, independently observe:

```text
Delta V_swap(H)
external process volumes(H)
bottom/corrector exchange(H)
internal state change(H)
production q_u(H), u
```

and test the identity implied by the complete SWAP water balance.

The required comparison is between three different objects:

1. the production affine response `q_u + (u/dt) Delta H`;
2. the true SWAP corrector response around the same accepted origin;
3. the committed whole-window mass ledger.

Equality between any pair is a hypothesis, not an assumption.

### Gap B: physical domain overlap with MODFLOW storage

Even if `u` is shown to contain a storage-related component, the physical question remains whether that component belongs to:

- water volume already represented by MODFLOW STO;
- water volume represented only by SWAP;
- a declared partition across the phreatic interface;
- or a mixed finite-window response that should not be interpreted as either storage volume.

This requires an explicit spatial/domain ownership map, not dimensional reasoning.

### Gap C: regime classification

Real hydrological regimes may support different coupling abstractions. A shallow phreatic surface with continuous vertical profile may favour a shared-state description, while a deliberately separated lower reservoir with real resistance may justify a q-link. A boundary-exchange algorithm may also be a valid numerical approximation without implying either physical topology.

Regime classification must follow the real balance and state definition.

## 8. Do we need another dummy experiment now?

**Decision: no.**

DSW01-DSW20 already separate the concepts needed for the next scientific question:

- storage partition versus duplication;
- one state versus two states;
- storage response versus process response;
- internal versus external flux;
- memoryless versus memory-bearing state;
- affine tangent versus physical mass ledger;
- convergence versus correctness;
- 1:1 versus N:1 algebra.

A new dummy case would currently add mechanism variety without resolving the open semantic question, because the remaining ambiguity is about what **real SWAP** contributes to the production response.

The next scientifically necessary step is therefore a bounded real-SWAP semantic audit, not DSW21+ architecture growth and not HLINK expansion.

## 9. Real-SWAP audit design

Select the simplest existing FMR fixture for which the accepted-origin state and complete water balance can be audited without changing production code.

For one origin/window and a small prospective set of prescribed groundwater heads `H_k`, capture separately:

```text
production predictor:
  H_start
  H_end,predictor
  q_bot,predictor
  dH_end/dq_bot
  u
  q_u
  dq_u/dH = u/dt

real correctors from the same immutable origin:
  H_k
  q_corrector(H_k)
  accepted/candidate storage change Delta V_swap(H_k)
  ET volume
  drainage volume
  top-boundary volume
  other external sink/source volumes
  internal-memory inventory change where observable

ledger:
  complete window mass residual
```

Pre-register at least these competing interpretations:

- **H1 storage identity:** `u` is, within the fixture, equal to the physical derivative of the SWAP-owned storage volume relevant to the shared groundwater state.
- **H2 complete corrector tangent:** `u/dt` matches the derivative of the returned corrector/exchange flux but is not equal to storage response alone because process/memory responses contribute.
- **H3 narrower historical transform:** the affine production response is a useful predictor/corrector linearization but does not equal either a physical storage derivative or a standalone interface conductance.
- **H4 finite-resistance interpretation:** only admissible if two independently meaningful physical heads and a head-difference-controlled exchange law can be identified. It must not be inferred from the presence of a slope.

No tolerance may be selected after seeing which hypothesis is favoured.

## 10. Relation to literature

Three existing coupling traditions clarify the taxonomy without deciding SWAP5 semantics for us.

1. **Shared-state coupling.** Van Walsum and Veldhuizen (2011), *Integration of models using shared state variables: Implementation in the regional hydrologic modelling system SIMGRO*, Journal of Hydrology 409, 363-370, DOI 10.1016/j.jhydrol.2011.08.036. The paper uses phreatic level as a shared state and a combined storage relationship. It explicitly motivates avoiding an artificial resistance where the saturated/unsaturated domains meet naturally.
2. **SWAP-MODFLOW exchange coupling.** Xu et al. (2012), *Integration of SWAP and MODFLOW-2000 for modeling groundwater dynamics in shallow water table areas*, Journal of Hydrology, DOI 10.1016/j.jhydrol.2011.07.002. The coupled models exchange water-table depth and net recharge. This is useful evidence that state/flux exchange is a distinct coupling pattern.
3. **Sequential vadose-MODFLOW coupling.** Beegum et al. (2018), *Updating the Coupling Algorithm between HYDRUS and MODFLOW in the HYDRUS Package for MODFLOW*, Vadose Zone Journal 17, DOI 10.2136/vzj2018.02.0034. Groundwater table is supplied as a vadose boundary and bottom flux is returned to MODFLOW; the paper documents temporal-boundary artifacts and explicitly distinguishes the separate mass balances from fully integrated saturated-unsaturated flow.

The literature therefore supports the conceptual distinction between shared-state, real q-link and boundary/sequential exchange. It does not determine which family the current SWAP5 production transform actually represents.

## 11. Architectural implication, deliberately deferred

No production coupling architecture change follows from this synthesis alone.

In particular:

- do not promote HLINK01-05 from research aid to architecture authority;
- do not rename `u` to physical storage or physical conductance;
- do not remove or duplicate MODFLOW STO based on the dummy alone;
- do not infer that bottom-mode-5 prescribed head proves a shared-state physical topology;
- do not infer that an affine coupling flux proves a finite-resistance interface.

The architecture decision must be derived from the real-SWAP balance audit and an explicit declaration of physical domain/storage ownership.

## 12. Evidence authority

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

The current synthesis changes no production source and claims no production requalification.
