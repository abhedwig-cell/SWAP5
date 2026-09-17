# Proposed MODFLOW 6 tangent coupling contract

## Status

**Proposal only. Not part of the frozen Status-A Groundwater Coupling v1 denominator.**

This note defines a candidate scientific and execution contract for a future SWAP5–MODFLOW 6 coupling workunit. It deliberately preserves the admitted SWAP5 transaction, mass-accounting and gateway principles while replacing the restricted `pc1` scientific coupling sequence with a MODFLOW-oriented predictor/corrector formulation based on the proven SWAP4–MODFLOW6 coupling concept.

The historical scientific basis is the September 2026 report *Koppeling SWAP4 en MODFLOW6* by Marius Heinen, Ab Veldhuizen, Hendrik Kok and Robert Leander. That report establishes the use of a fixed SWAP coupling depth, a shared hydraulic head at the coupling plane, a coupling exchange flux `q_u`, a coupling/storage coefficient `u`, a flux-predictor followed by head-driven SWAP correctors, and bounded SWAP participation in MODFLOW outer iterations.

This proposal does **not** admit a MODFLOW backend, alter the current Status-A authority, or supersede [Groundwater Coupling v1](../capabilities/groundwater-coupling-v1.md). It defines the scientific decision surface that a later F-GC workunit would need to qualify.

## 1. Purpose

The target is a conservative coupling between one or more SWAP5 soil columns and MODFLOW 6 in which:

- SWAP5 resolves fast soil–plant–atmosphere and vertical soil-water dynamics;
- MODFLOW 6 resolves the slower regional saturated groundwater system;
- the shared state at the fixed SWAP lower boundary is hydraulic head;
- SWAP5 supplies MODFLOW with the exchange/recharge response required for the groundwater solve;
- repeated coupled trials begin from the same accepted origin;
- only a converged coupled state is committed and published.

The intended architecture is therefore:

```text
accepted coupled origin at t_n
        |
        v
SWAP5 flux-predictor trials
        |
        +--> coupling response u
        +--> exchange flux q_u
        |
        v
MODFLOW outer solve
        |
        v
candidate MODFLOW head
        |
        v
SWAP5 head-corrector trial from the same origin
        |
        +--> updated q_u
        |
        +----------> next MODFLOW outer iteration
        |
        v
coupled convergence
        |
        v
prepare / verify / commit
```

## 2. Scientific coupling plane

The coupling plane is the fixed lower boundary of the SWAP5 column.

The shared state is hydraulic head at that plane:

```text
H_swap,bot = H_mf6
```

This does **not** assert that MODFLOW hydraulic head is identical to the freatic groundwater level calculated inside SWAP5. SWAP5 resolves the vertical hydraulic profile between the fixed coupling plane and the internally calculated location where pressure head is zero.

The public coupling must therefore continue to use the explicit head-datum translation already required by Groundwater Coupling v1:

```text
H_interface_m = z_bottom_m + psi_bottom_cm * 0.01
psi_bottom_cm = (H_interface_m - z_bottom_m) * 100
```

Pressure head, hydraulic head and groundwater-table depth remain different quantities and must not be silently relabelled.

## 3. Coupling quantities

Three lower-domain quantities must remain distinct.

### 3.1 SWAP lower-boundary flux `q_bot`

`q_bot` is the hydraulic flux across the fixed lower boundary of the SWAP column. In the predictor phase it is used as the uncertain lower-boundary condition for SWAP5.

The initial predictor value for a new coupling window is derived from the previously accepted coupled state. The historical SWAP4 coupling used the lower-boundary flux from the preceding period as the first estimate.

### 3.2 Coupling exchange flux `q_u`

`q_u` is the effective exchange/recharge term supplied to MODFLOW for the coupled upper groundwater domain.

It is **not** generally identical to `q_bot`. In the historical SWAP4 formulation, `q_u` is reconstructed from the water balance of the saturated part represented inside the SWAP column. The storage change associated with the change in lower-boundary head and the imposed lower-boundary flux both contribute to this reconstruction.

For the future public SWAP5 coupling API, the preferred normalized sign is:

```text
q_u > 0 : water transferred from SWAP to groundwater
q_u < 0 : water transferred from groundwater to SWAP
```

Any native SWAP or MODFLOW sign convention is translated explicitly by an adapter.

### 3.3 Coupling/storage coefficient `u`

`u` is a local coupling response quantity with dimension length/length:

```text
u ≈ delta_storage / delta_head
```

The historical SWAP4 method obtains `u` through two symmetric perturbations of the lower-boundary flux around the predictor value:

```text
q_1 = q_0 - delta_q
q_2 = q_0 + delta_q

u = ((q_2 - q_1) * delta_t) / (H_2 - H_1)
```

where `H_1` and `H_2` are the resulting lower-boundary hydraulic heads at the end of the same coupling window.

Equivalently, if the local response tangent is written as

```text
T_Hq = dH / dq
```

then locally

```text
u ≈ delta_t / T_Hq
```

and the corresponding flux sensitivity is

```text
dq / dH ≈ u / delta_t
```

`u` is therefore a coupling response quantity, not an intrinsic static soil parameter. It may depend on accepted SWAP state, soil hydraulic properties, coupling-window duration, coupling depth and the selected perturbation regime.

## 4. Coupling window and accepted origin

Coupling is defined over a generic interval:

```text
[t_n, t_n+1]
```

with duration `delta_t`. The contract is not intrinsically daily. SWAP5 may use any admitted adaptive internal timesteps inside the window.

Every attempt starts from one accepted coupled origin containing at least:

```text
accepted time t_n
SWAP committed lineage and revision
MODFLOW committed lineage and revision
accepted interface identity and datum
previous accepted coupling predictor information
```

All predictor, perturbation and corrector SWAP trials for the same coupling window start from the same accepted SWAP checkpoint. A corrector never continues from a predictor candidate.

## 5. Predictor phase

The predictor begins with an estimate `q_bot^(0)` derived from accepted history.

From the same SWAP5 checkpoint, run three independent trials over the complete coupling window:

```text
trial A: q_bot = q_bot^(0) - delta_q
trial B: q_bot = q_bot^(0) + delta_q
trial C: q_bot = q_bot^(0)
```

Trials A and B determine the centered finite-difference response coefficient `u`.

Trial C determines the predictor column response and the corresponding coupling exchange flux `q_u^(0)`.

All three results are tentative. None may mutate committed SWAP state or publish authoritative external exchange.

### 5.1 Perturbation policy

`delta_q` is an explicit governed numerical parameter. The final workunit must qualify that it is:

- large enough to dominate floating-point/noise effects;
- small enough to represent a local response;
- physically admissible for the active lower-boundary state;
- robust across representative soil profiles and coupling-window lengths.

A fixed historical perturbation value must not be imported without qualification.

## 6. MODFLOW exchange representation

For the first MODFLOW outer solve in a coupling window, the SWAP5 adapter exposes at least:

```text
q_u^(0)
u
```

plus all required identity, time-support, area/basis and unit metadata.

The exact MODFLOW API representation remains an adapter concern. The scientific contract requires that the MODFLOW solve receives an exchange flux and the local coupling/storage response that belongs to the same SWAP accepted origin and coupling window.

The design must not infer scientific equivalence merely from matching array shapes with MetaSWAP. The exchanged quantities must preserve the SWAP-specific fixed-depth coupling meaning defined here.

## 7. Corrector phase and MODFLOW outer iteration

After a MODFLOW outer solve, MODFLOW supplies a candidate hydraulic head `H_mf6^(k)` at the SWAP coupling plane.

SWAP5 then starts again from the original accepted checkpoint at `t_n` and reruns the complete coupling window with hydraulic head as its lower-boundary condition:

```text
H_swap,bot = H_mf6^(k)
```

The corrector returns a new exchange flux:

```text
q_u^(k)
```

for the next MODFLOW outer iteration.

For the initial version of this contract, `u` is held fixed within one coupling window:

```text
u^(k) = u^(0)
```

while `q_u` is updated after each SWAP corrector. This follows the historical SWAP4 experience that recomputing `u` during every outer iteration required two additional SWAP runs but provided limited benefit.

This is a **proposed bounded modified/quasi-Newton strategy**, not yet a Status-A scientific claim. Qualification must determine where holding `u` fixed is acceptable and when recomputation or another response treatment is required.

## 8. Convergence

Convergence belongs to the coupled execution policy, not to an undocumented constant in SWAP5 process code.

The coupling should require at least:

1. successful MODFLOW nonlinear/external convergence for the current exchange representation; and
2. stabilization of the coupled SWAP–MODFLOW exchange response.

A candidate exchange criterion is:

```text
abs(q_u^(k) - q_u^(k-1)) <= epsilon_q_abs
```

optionally combined with a relative criterion:

```text
abs(q_u^(k) - q_u^(k-1)) /
max(q_scale, abs(q_u^(k))) <= epsilon_q_rel
```

A head-increment criterion may additionally be used:

```text
abs(H_mf6^(k) - H_mf6^(k-1)) <= epsilon_H
```

Because the corrector directly prescribes the MODFLOW head at the SWAP lower boundary, a same-trial equality `H_swap,bot = H_mf6` is a boundary condition, not by itself a sufficient coupled convergence test.

All tolerances require explicit configuration, provenance and qualification.

## 9. Bounded iteration and failure handling

The historical coupling commonly found three to five SWAP participations in the MODFLOW outer iteration sufficient, while some difficult profiles continued to improve with more iterations.

The future contract therefore uses:

```text
configurable maximum coupled iterations
+ explicit convergence criteria
+ fail-closed nonconvergence handling
```

A hard scientific constant of five iterations is not assumed.

If the coupling does not converge within the admitted iteration budget, the attempt must not publish tentative SWAP state or coupling exchange. The execution policy may then choose an admitted recovery action, such as reducing the coupling window, increasing a bounded iteration budget, or failing the interval. Such recovery policy remains separate from the scientific exchange equations.

## 10. Transaction and publication semantics

This proposal reuses the existing SWAP5 transaction model.

The hard rule remains:

**computed is not the same as published.**

During predictor and corrector iterations, SWAP5 produces candidates only. A rejected predictor, perturbation or corrector contributes no committed state and no committed external transfer.

After coupled convergence:

1. identify the final SWAP candidate and matching MODFLOW candidate;
2. derive the authoritative whole-window coupling exchange;
3. stage the interface mass transfer in the coupling ledger;
4. prepare all participants that support prepared publication;
5. verify lineage, time support, datum, sign/unit mapping and mass pairing;
6. publish the accepted participant states;
7. commit the interface ledger exactly once;
8. advance the accepted coupled origin to `t_n+1`.

The exact publication ordering and MODFLOW-side prepare/commit guarantees remain to be established by the backend workunit. The existing Groundwater Coupling v1 preflight/prepare pattern should be reused where its assumptions remain valid.

## 11. Authoritative mass quantity

The authoritative coupling transfer is the amount integrated over the accepted coupling window:

```text
V_u = integral(Q_u dt) over [t_n, t_n+1]
```

A mean rate is derived only when required by an external API:

```text
Q_u_mean = V_u / delta_t
```

A terminal or instantaneous lower-boundary flux must not be substituted silently for the whole-window transfer.

For the combined SWAP-plus-groundwater accounting domain, the accepted interface pair is internal and must cancel exactly after sign/unit normalization.

## 12. Groundwater irrigation is a separate transfer

Managed groundwater irrigation is **not part of `q_u`**.

SWAP5 may determine irrigation demand from accepted state and management rules. A groundwater allocation/pumping path may then withdraw water from MODFLOW and return a realized irrigation amount to SWAP5.

Conceptually:

```text
SWAP5 accepted state
      |
      v
irrigation demand
      |
      v
groundwater allocation / MODFLOW pumping
      |
      v
realized groundwater irrigation
      |
      v
SWAP5 upper-boundary irrigation forcing
```

The same physical water must be booked once on each component side and cancel in the combined-system ledger, apart from explicitly modelled conveyance/application losses.

Groundwater pumping must therefore never also be hidden inside the natural lower-boundary exchange `q_u`.

Surface-water irrigation through Ribasim is outside this contract but should use the same demand-versus-realized-supply principle.

## 13. Drainage and other sink/source ownership

A physical drainage or groundwater/surface-water pathway must have one flux owner.

The historical SWAP4–MODFLOW report already established the need to avoid simultaneous duplicate representation of the same drainage pathway. In a future SWAP5–MODFLOW–Ribasim system the ownership assignment may differ from the historical recommendation, but duplicate booking remains prohibited.

Examples that require explicit future ownership decisions include:

- field/tile drainage represented inside the SWAP column;
- regional groundwater discharge to a represented surface-water system;
- MODFLOW river/drain boundaries;
- Ribasim basin/channel exchange;
- subirrigation through drainage infrastructure.

## 14. Deep-groundwater regime

The historical SWAP4 prototype used a free-drainage fallback for sufficiently deep groundwater and a prescribed coupling coefficient.

This proposal does **not** automatically admit that fallback.

A deep-groundwater route requires a separate scientific decision defining:

- the physical criterion for decoupling SWAP from MODFLOW head;
- transition/hysteresis behaviour near the criterion;
- the resulting exchange quantity and mass semantics;
- whether a constant or state-dependent response coefficient remains necessary;
- qualification against fully coupled cases.

No fixed depth threshold is part of this proposal.

## 15. MultiSWAP and spatial mapping

The scientific contract is column-local, but regional use requires mapping many SWAP columns to MODFLOW cells.

The future runtime must define:

- one-to-one or many-to-one spatial support;
- area weights and normalization basis;
- aggregation of `q_u` amounts/rates;
- aggregation or effective treatment of `u` when multiple SWAP columns contribute to one MODFLOW cell;
- deterministic ordering and reduction;
- per-column transaction isolation;
- preservation of lineage from each contributing SWAP column to the MODFLOW exchange record.

No aggregation formula for multiple heterogeneous `u` values is admitted by this note. That is an explicit future decision surface.

## 16. Relationship to Groundwater Coupling v1

Groundwater Coupling v1 remains valid within its admitted bounded contract.

Its current restricted `pc1` route:

```text
accepted groundwater head
    -> SWAP predictor trial
    -> whole-window exchange
    -> groundwater predictor trial
    -> SWAP corrector from original checkpoint
    -> groundwater corrector
    -> head convergence
    -> prepare / commit
```

This proposal changes the scientific coupling algorithm to:

```text
accepted previous exchange predictor
    -> SWAP flux perturbation trials
    -> coupling response u
    -> SWAP predictor exchange q_u
    -> MODFLOW outer solve
    -> head-driven SWAP corrector from original checkpoint
    -> updated q_u
    -> bounded outer iteration
    -> coupled convergence
    -> prepare / commit
```

The reusable v1 assets are expected to include:

- explicit head datum translation;
- explicit sign/unit adapters;
- accepted/candidate state separation;
- checkpoint/trial/discard semantics;
- interface lineage;
- whole-window mass exchange;
- interface mass ledger;
- accepted-state publication;
- restart-at-committed-boundary discipline;
- structural external gateway separation.

The scientific delta that requires new qualification includes:

- flux-predictor ownership;
- centered perturbation calculation of `u`;
- reconstruction and publication of `q_u` distinct from native `q_bot`;
- repeated head-driven SWAP correctors inside MODFLOW outer iteration;
- convergence criteria for `q_u` and MODFLOW head increments;
- policy for frozen versus recomputed `u`;
- MODFLOW-specific exchange representation;
- multi-column aggregation of `q_u` and `u`.

## 17. Hard invariants

A future implementation must preserve at least the following invariants:

1. Every predictor, perturbation and corrector SWAP trial starts from the same accepted origin for the coupling window.
2. A rejected trial cannot mutate committed SWAP state.
3. `q_bot`, `q_u`, `u`, groundwater pumping and irrigation are distinct quantities and cannot be silently aliased.
4. Hydraulic head and pressure head are translated through an explicit vertical datum.
5. Native solver flux signs and public coupling signs are translated explicitly.
6. The same physical exchange is booked exactly once per component and cancels in the combined-system ledger.
7. Only the accepted final coupled candidate contributes committed interface mass.
8. Coupling iteration limits and tolerances are explicit policy, not hidden physics constants.
9. Scientific coupling semantics cannot be changed solely to make CI pass or improve runtime.
10. A MODFLOW adapter does not become scientifically admitted merely by conforming to the structural gateway API.

## 18. Qualification programme

A future F-GC workunit should qualify the contract in increasing complexity.

### Q1. Response-coefficient mechanics

For representative soil states:

- verify centered perturbation repeatability;
- study sensitivity to `delta_q`;
- compare finite-difference `u` with independently estimated local response;
- establish failure behaviour for near-zero `H_2 - H_1`;
- test dependence on coupling-window duration and coupling depth.

### Q2. One SWAP column / one groundwater cell

Recreate the essential historical balance test:

- no horizontal groundwater flow;
- controlled groundwater sink/drain;
- verify cumulative SWAP-groundwater exchange closure;
- compare zero, bounded and extended coupled iteration counts;
- prove rollback leaves the accepted origin unchanged.

### Q3. Soil-profile matrix

Exercise a broad Dutch soil-profile set, with specific attention to:

- clay;
- peat;
- loess;
- wet near-surface conditions;
- strong vertical hydraulic resistance.

Measure convergence rate, residual exchange error and the validity of holding `u` fixed within a window.

### Q4. Horizontal groundwater dynamics

Use a synthetic strip/grid with:

- lateral MODFLOW flow;
- time-varying ditch or boundary stage;
- optional groundwater abstraction;
- heterogeneous SWAP profiles.

Verify that the coupled hydraulic heads, exchange amounts and mass ledger remain stable and conservative.

### Q5. Transaction and restart

For predictor, perturbation and corrector phases:

- reject at each legal boundary;
- replay from the same accepted origin;
- verify bitwise/deterministic state authority where the implementation contract permits;
- split/restart only at committed boundaries;
- prove no duplicate exchange publication after retry.

### Q6. MultiSWAP aggregation

Before regional admission:

- define and qualify area-weighted exchange aggregation;
- define the effective MODFLOW treatment of multiple `u` contributions;
- verify deterministic reduction independent of worker ordering;
- preserve per-column mass and lineage diagnostics.

### Q7. Performance characterization

Measure separately:

- three predictor SWAP runs;
- each head-driven corrector;
- number of MODFLOW outer iterations;
- benefit/cost of frozen `u`;
- benefit of conditional `u` refresh;
- column parallelism and execution-class grouping.

Performance evidence must not relax conservation or transaction invariants.

## 19. Proposed F-GC workunit boundary

Suggested identifier:

```text
F-GC30 — MODFLOW6 tangent coupling contract and harness
```

Suggested first-slice scope:

```text
IN SCOPE
- formal typed coupling quantities q_bot, q_u and u
- predictor perturbation service from one SWAP checkpoint
- finite-difference response diagnostics
- head-driven corrector trials from the same checkpoint
- bounded outer-iteration harness with a deterministic dummy groundwater backend
- whole-window exchange ledger binding
- focused Q1/Q2 qualification

OUT OF SCOPE
- production MODFLOW 6 backend
- Ribasim
- irrigation allocation
- regional drainage ownership redesign
- deep-groundwater fallback
- concurrent real-physics MultiSWAP
- GPU/performance redesign
- changes to Richards physics
```

The first workunit should therefore prove the scientific and transaction semantics with a controlled groundwater harness before binding the contract to MODFLOW 6.

## 20. Admission question

The workunit is ready for later MODFLOW-backend integration only when the following can be answered with evidence:

> Given one accepted SWAP5 state and one coupling window, can SWAP5 reproducibly construct `u` and `q_u`, participate in bounded head-corrected outer iterations from the same origin, and publish exactly one conservative final exchange without leaking any rejected trial state?

Until that question is qualified, this document remains a proposed scientific contract rather than an admitted coupling capability.
