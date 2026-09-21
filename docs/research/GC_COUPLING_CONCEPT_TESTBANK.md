# SWAP5 groundwater-coupling concept testbank

Date: 2026-09-21
Status: RESEARCH DESIGN
Branch: `work/f-gc-dummy-swap-shared-storage`
Canonical authority at start: `bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`

## Research objective

Build a deliberately transparent family of "dummy SWAP" models that can be
coupled to real MODFLOW6 while every storage change, external flux, exchange
term and final head remains independently calculable.

The testbank is intended to answer a more fundamental question than whether the
current software converges:

> What is the mathematical meaning and physical ownership of every state,
> storage term, flux and linearization coefficient in the SWAP5-MODFLOW6
> coupling, and under what domain interpretation is the coupled equation
> exactly mass conservative?

No production coupling change is authorized from this research line.

## Vocabulary that must stay distinct

### Shared state

A shared state is one physical degree of freedom represented in two subsystem
descriptions but constrained to one value in the coupled solution. The
canonical example is the phreatic head:

```
h_swap = h_modflow = h
```

If this is the intended coupling, the equality is a state constraint. It is not
a Darcy flux law and it does not imply a finite interfacial resistance.

### Shared control volume

A shared control volume is a physical water volume whose storage response is
assembled from the processes represented by both subsystems. Its storage must
appear exactly once in the coupled mass balance.

For a simple system,

```
dS_total/dt = R_atm + q_lateral - ET - q_drain
S_total = S_total(h, x_internal)
```

where `x_internal` can contain soil-moisture/root-zone memory not determined
by head alone.

### q-link

A q-link connects distinct subsystem states through a constitutive flux law,
for example

```
q_ex = C * (h_a - h_b)
```

or `q_ex=(h_a-h_b)/c`.

Here `C` is a physical conductance and `c` a physical resistance. The two
heads need not be equal.

### h-link

An h-link identifies a common state:

```
h_a = h_b
```

The interaction flux is then whatever flux is required by the joint balance.
Introducing a finite resistance between the two descriptions changes the
physical problem.

### Physical parameter versus solver tangent

A parameter such as porosity, specific yield or hydraulic conductance belongs
to the physical model. A derivative such as

```
dq/dh
```

can instead be a local Jacobian/tangent used to solve a nonlinear coupled
equation. A solver tangent may numerically resemble a conductance or storage
coefficient without being an independently existing physical element.

The current SWAP5 field `coupling_storage_coefficient_u` must be interpreted
under this distinction.

### Exchange flux versus accounting residual

When two models describe disjoint domains, exchange flux can be the physical
flow crossing their interface. In a shared-control-volume formulation, the
quantity communicated as an "exchange flux" can instead be the balance
remainder after one subsystem has already used part of an external forcing for
internal storage change. These meanings must not be mixed.

## Literature anchor

### Van Walsum and Veldhuizen (2011)

P.E.V. van Walsum and A.A. Veldhuizen,
"Integration of models using shared state variables: Implementation in the
regional hydrologic modelling system SIMGRO", Journal of Hydrology 409,
363-370. DOI: 10.1016/j.jhydrol.2011.08.036.

The paper is directly relevant to this workstream:

- it distinguishes q-links from h-links;
- the phreatic level is the shared state variable of MetaSWAP and MODFLOW;
- the water balance control volume spans both saturated and unsaturated parts
  of the vertical profile;
- the communicated MetaSWAP flux is explicitly not identical to atmospheric
  recharge, because part of the recharge can already have changed unsaturated
  storage;
- MetaSWAP communicates the associated storage response to MODFLOW;
- the storage coefficient supplied to MODFLOW represents how total profile
  storage changes with the shared head;
- in the paper's q-link equivalence experiment, additional MODFLOW storage is
  made almost zero so that it does not add a second independent storage to the
  same h-link reference problem;
- the limiting q-link resistance tends to zero as the q-link approaches the
  shared-head formulation, but that limit is numerically difficult.

This is not proof that the current SWAP5 formulation is wrong. It is authority
that storage ownership and domain definition are intrinsic parts of this
coupling concept and therefore must be tested explicitly.

### Current iMOD Coupler documentation

The current technical documentation for MetaSWAP-MODFLOW6 states that
MetaSWAP provides recharge and sets the storage in coupled MODFLOW cells.
This is consistent with the shared-state/shared-storage interpretation above.

Reference:
https://deltares.github.io/imod_coupler/technical.html

### Hughes et al. (2022)

J.D. Hughes, M.J. Russcher, C.D. Langevin, E.D. Morway and R.R. McDonald,
"The MODFLOW Application Programming Interface for simulation control and
software interoperability", Environmental Modelling & Software 148, 105257.
DOI: 10.1016/j.envsoft.2021.105257.

The MODFLOW API/XMI makes within-timestep tight coupling possible. The paper
also uses MODFLOW-MetaSWAP as a coupling example. API capability itself does
not decide the scientific ownership of storage; that must come from the
coupling formulation.

## Core mathematical object

For this research, write every coupled problem first as one physical balance

```
F(h_1, x_1; h_0, x_0, forcing, lateral) = 0
```

before mapping it to SWAP and MODFLOW components.

For the first zero-resistance constant-storage example,

```
S (h_1-h_0) = P + Q_lat * dt
```

per unit area, with evaporation and drainage zero.

Every implementation variant must reduce to that equation when its additional
mechanisms are disabled.

We then distinguish:

1. the physical residual `F`;
2. the partition of terms between dummy SWAP and MODFLOW;
3. the communicated flux;
4. the communicated storage response;
5. the Jacobian used by the nonlinear solve;
6. the final mass ledger.

A test passes scientifically only if the final state and complete water balance
match the physical residual, not merely if the nonlinear solver converges.

## Experiment families

### DSW-00 conservation identities

Dependency-free algebraic tests:

- dimensions and signs of every quantity;
- action/reaction convention;
- zero forcing gives zero change;
- equal initial shared heads give zero artificial exchange;
- total storage change equals external net flux;
- changing the arbitrary coupling reference point does not change the physical
  solution.

### DSW-01 constant storage, zero resistance

Existing first experiment.

Physical oracle:

```
S = 0.20
P = 0.010 m
h0 = 8.00 m
h1 = 8.05 m
```

Purpose: expose the relation between recharge, `u`, MODFLOW storage and the
shared state.

### DSW-02 storage ownership partition sweep

Keep one physical storage `S_total=0.20` but deliberately assign fractions

```
S_swap = alpha*S_total
S_mf   = (1-alpha)*S_total
```

for `alpha = 0, 0.25, 0.5, 0.75, 1`.

If the mathematical coupling represents one physical control volume correctly,
all partitions that are formulated consistently must produce the same physical
head. A formulation that changes the result merely because the same storage is
relabeled between models is exposing an ownership error.

Also run the deliberately wrong case

```
S_swap = S_total
S_mf   = S_total
```

to obtain an explicit double-storage signature.

### DSW-03 lateral-flux forcing

Remove rainfall and inject a known lateral groundwater volume through MODFLOW.

Purpose:

- prove that a forcing owned entirely by MODFLOW updates the same shared head;
- verify that dummy SWAP sees exactly the corresponding change in shared
  storage;
- distinguish "recharge from SWAP" from "all fluxes that can change the shared
  state".

This is necessary because atmospheric forcing alone does not test two-way
coupling.

### DSW-04 superposition test

For the linear bucket, apply rainfall and lateral MODFLOW flow separately and
together.

The combined response must equal the sum of the two separate responses.

This gives a strong oracle before nonlinear mechanisms are introduced.

### DSW-05 time-step invariance

For constant storage and zero resistance, distribute the same total input over:

- 1 x 1 day;
- 2 x 0.5 day;
- 10 x 0.1 day;
- irregular substeps with the same total volume.

The final head is analytically time-step invariant. Any dependence is therefore
numerical/coupling error rather than physical behavior.

### DSW-06 reference-point and predictor invariance

Construct the same linear physical response from different predictor
`q_bot`, reference head and re-anchoring paths.

All representations of the same affine law must yield the same coupled
solution. This directly tests whether `H_ref` is only numerical provenance or
has accidentally become physics.

### DSW-07 Jacobian audit

For every dummy model, derive the exact derivative of the final coupled
residual with respect to shared head. Compare:

- analytic Jacobian;
- centered finite difference of the complete coupled residual;
- the HCOF/Jacobian actually supplied to MODFLOW.

This test is specifically intended to distinguish a physical exchange
coefficient from a Newton/Picard tangent.

### DSW-08 finite vertical resistance: true q-link

Introduce two distinct heads and a physical resistance:

```
q_ex = (h_swap-h_mf)/c
```

with separate, explicitly owned storages.

Sweep `c` from large to small. Verify:

- finite-resistance q-link physics;
- the limit as `c -> 0` approaches the shared-head solution;
- increasing numerical stiffness in that limit;
- no confusion between `1/c` and the storage-derived `u/dt`.

This experiment is deliberately different from DSW-01.

### DSW-09 nonlinear storage curve

Replace constant storage by an exactly integrable `S(h)`, initially
piecewise-linear and then smooth nonlinear.

Use storage volume, not a point storage coefficient, as the independent oracle:

```
V(h1)-V(h0) = integral S(h) dh = net input
```

Test secant, tangent and balance-based linearizations separately.

### DSW-10 depth-varying material

Implement the proposed transparent depth profile, for example changing
effective drainable storage with elevation. Start with a profile whose integral
has a closed form.

This tests whether the shared storage relation belongs to the complete vertical
column rather than only the MODFLOW cell at the instantaneous water table.

### DSW-11 capillary-memory surrogate

Add one internal unsaturated storage state with a known first-order relaxation
law. Two cases can then have the same groundwater head but different
unsaturated storage.

Purpose: demonstrate exactly when groundwater head alone is not a complete
state and what additional dummy-SWAP memory must be retained across coupling
windows.

### DSW-12 head-dependent ET

Add a simple bounded ET law `ET(h)`, first piecewise-linear.

Test:

- ET off when groundwater is deep;
- increasing ET as groundwater approaches roots;
- mass closure;
- exact derivative contribution to the coupled Jacobian;
- distinction between a sink response and shared storage response.

### DSW-13 drain

Add one linear drain:

```
q_d = C_d max(0, h-h_d)
```

Then a smoothed/nonlinear version.

This gives a one-sided state-dependent saturated sink with an exact oracle.

### DSW-14 mechanism composition

Combine storage, rainfall, lateral flow, ET and drain only after all individual
mechanisms pass.

The composed dummy remains independently solvable with a high-accuracy scalar
root solver, so real MODFLOW can be checked against an oracle without using a
second Richards model.

### DSW-15 forcing-order and path tests

Apply the same net water amount using different forcing histories.

For memoryless linear storage, only the total matters.
For DSW-11 memory, path dependence is expected and analytically prescribed.

This separates legitimate hydrological memory from numerical path dependence.

### DSW-16 N:1 shared-state aggregation

Couple multiple heterogeneous dummy columns to one MODFLOW cell.

Each column has a known area fraction and storage/recharge law. The exact
combined control-volume equation is

```
sum_i a_i [V_i(h1)-V_i(h0)] = sum_i a_i Q_i + Q_mf
```

This tests F-GC40-style aggregation against a physical oracle, including
permutation invariance and heterogeneous storage.

### DSW-17 equal-and-opposite internal transfer

Create two coupled dummy compartments that exchange water internally but have
zero external forcing.

Total system storage must be invariant to machine precision. This is a strong
test for accidental creation/destruction of water by coupling ledgers.

### DSW-18 near-zero-storage and high-storage limits

Use mathematically controlled limits of the storage relationship.

Do not confuse this with a conductance limit:

- `S -> 0` means vanishing storage and extreme head sensitivity;
- `S -> infinity` means very weak head response.

These are different from `c -> 0` or `C -> infinity` in a q-link.

### DSW-19 convergence versus correctness adversarial cases

Construct cases where a numerically converged solution is intentionally
physically wrong because storage is double counted or a sign is reversed.

The testbank must show that solver convergence is not a scientific acceptance
criterion.

### DSW-20 manufactured coupled solution

Choose an arbitrary smooth target head trajectory `h(t)` and internal-state
trajectory, then derive the external forcing required to make it an exact
solution of the dummy equations.

Feed that forcing through the coupled system and test whether the trajectory is
reproduced. This provides a general verification route beyond individual
rainfall examples.

## Required diagnostics for every live test

Persist at least:

- initial and final shared head;
- all externally imposed volumes;
- dummy-SWAP storage before/after;
- MODFLOW storage before/after;
- explicitly declared physical storage ownership;
- communicated `q_u`;
- communicated `u`;
- any true interface conductance/resistance;
- MODFLOW HCOF and RHS;
- complete nonlinear residual at each coupling iteration;
- solver convergence status;
- final physical mass residual;
- final ledger residual;
- number of re-anchors/correctors;
- time-step size.

The test result must be reproducible from these quantities without inspecting
hidden SWAP state.

## Acceptance hierarchy

A coupling case is classified in this order:

1. dimensional/sign consistency;
2. exact physical control-volume balance;
3. correct state ownership;
4. correct final state against analytic/manufactured oracle;
5. correct exchanged fluxes;
6. correct tangent/Jacobian;
7. numerical convergence and robustness;
8. timestep sensitivity.

A green nonlinear solve cannot compensate for failure at levels 1-5.

## Current executed frontier

The live MODFLOW6 testbank has now executed through DSW-16, with DSW-09
numerical diagnostics extended through DSW-09X.

The main established distinctions are:

- shared-state storage versus finite-resistance q-link physics;
- physical storage volume versus local response tangent;
- storage response versus ET/drain sink response;
- shared groundwater head versus additional internal column memory;
- physical/coupled residual closure versus subsystem solver certification;
- physical path dependence versus numerical/restart path dependence;
- linear N:1 area aggregation versus the separate scientific question of
  heterogeneous Richards transferability.

Two deliberately falsified strict controls remain preserved as evidence:

- DSW-05 at IMS strict `rclose=1e-15` reaches the analytic linear head but
  does not receive a MODFLOW convergence certificate for one irregular
  substep. DSW-05W shows that the same head certifies at `1e-14` and
  `1e-13`.
- DSW-09 under the original MODERATE/strict research solver settings does not
  meet the combined preregistered gate. DSW-09V/X separate nonlinear
  under-relaxation history from near-root strict residual certification.

These red controls are not to be rewritten into green historical tests.
Their explanatory diagnostics are the current authority for interpretation.

DSW-15 also established a harness rule: accepted transient state used by a
strict conservation oracle must be transferred without unintended formatted
restart rounding. The live fixture therefore writes the requested previous
head directly to X and XOLD through XMI before the new substep is prepared.

## Immediate next actions

1. Run DSW-17, an equal-and-opposite internal-transfer experiment with zero
   external forcing. The complete coupled storage must remain invariant.
2. Run DSW-18 storage limits separately from q-link limits. In particular,
   distinguish `S -> 0` and large `S` from `C -> infinity` in a physical
   exchange law.
3. Run DSW-19 adversarial converged-but-wrong cases for duplicate storage and
   sign errors. This makes solver convergence versus scientific correctness
   explicit.
4. Run DSW-20 manufactured coupled trajectories with independently derived
   forcing and state evolution.
5. After those dummy oracles close, map real SWAP F-GC33 responses onto the
   established taxonomy. Decompose the real response into storage-volume
   change, physical external/sink contributions and numerical tangent using an
   independent mass ledger.
6. Keep production F-GC code unchanged until the real-SWAP mapping and
   production-envelope qualification identify a specific equation-level or
   solver-policy change that is independently justified.

