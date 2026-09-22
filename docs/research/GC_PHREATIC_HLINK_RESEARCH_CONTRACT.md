# Research contract for a true phreatic h-link

Date: 2026-09-21  
Status: RESEARCH DESIGN, NOT PRODUCTION ADMISSION  
Canonical reference: `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`

## Purpose

This contract defines the minimum scientific and transactional semantics that a
future SIMGRO-style phreatic shared-state coupling between SWAP5 and MODFLOW6
would need.

It does **not** redefine the current F-GC route.

The current admitted F-GC route exchanges a hydraulic head on the lower SWAP
coupling plane and applies that head through the mode-5 lower boundary. MAP11
and MAP12 establish that this is not the same contract as a shared phreatic
water-table state.

The purpose of this document is to make the alternative contract explicit
before any implementation is attempted.

## 1. Shared physical state

A true h-link has exactly one phreatic state coordinate for each coupled
groundwater control volume:

```
H_p
```

with the physical identity

```
H_p,SWAP = H_p,MODFLOW = H_p.
```

This equality is a model contract, not merely a convergence tolerance between
two independently owned heads.

The shared coordinate does not make the complete SWAP state shared. SWAP still
owns internal state such as

```
xi_swap = pressure-head profile,
          water-content profile,
          hysteresis/process memory,
          vegetation/root state,
          optional-process state,
          numerical continuation state where physically required.
```

DSW11 and DSW15 show why `H_p` alone is not a complete continuation state.

## 2. Declared physical domain

Every h-link binding must declare the physical volume represented by the shared
phreatic storage.

At minimum the contract must identify:

- horizontal area;
- vertical/geometric support of the shared storage;
- porosity or constitutive storage law;
- whether confined/compressible storage is present;
- which part of the SWAP column changes water inventory when `H_p` changes;
- which MODFLOW storage terms refer to the same volume;
- which MODFLOW storage terms refer to disjoint groundwater volume.

No storage coefficient may be classified as overlapping, complementary or
duplicated from numerical value or units alone.

MAP11 shows why this declaration is necessary: the current F-GC45 qualification
fixture does not establish geometric coextensivity between its FMR column and
MODFLOW STO cell.

## 3. One physical storage ledger

Let

```
V_phys(H_p, xi_swap, ...)
```

be the water volume of the declared shared physical storage domain.

For one accepted coupling window:

```
Delta V_phys = V_phys,new - V_phys,old.
```

If implementation convenience partitions the storage response between SWAP and
MODFLOW,

```
Delta V_phys
  = Delta V_swap_owned
  + Delta V_modflow_owned,
```

then the ownership sets must have no overlap and no gap.

In local differential form:

```
S_phys = dV_phys/dH_p
       = S_swap_owned + S_modflow_owned.
```

DSW02 and DSW23 are the corresponding algebraic and geometric oracles.

Counting the same coextensive physical storage in both owners is invalid even
when both subsystem ledgers close numerically.

## 4. Complete coupled water balance

For one coupling window define external contributions to the complete physical
system:

```
V_atm
V_lateral_gw
V_managed
V_external_other
```

and external losses:

```
V_ET
V_drain_external
V_runoff
V_external_other_out.
```

Then the complete-system balance is

```
Delta V_complete
  = V_atm
  + V_lateral_gw
  + V_managed
  + V_external_other
  - V_ET
  - V_drain_external
  - V_runoff
  - V_external_other_out.
```

Any transfer between SWAP-owned internal storage and MODFLOW-owned storage
inside the declared complete system is internal:

```
+V_transfer on one ledger
-V_transfer on the other ledger.
```

It must cancel from the complete-system balance.

DSW17 is the equal-and-opposite internal-transfer oracle.

## 5. SWAP process ownership

SWAP owns the vertical/process calculation needed to advance `xi_swap` and to
evaluate contributions such as:

- atmospheric input and surface boundary response;
- unsaturated storage redistribution;
- root water uptake / evapotranspiration;
- drainage processes assigned to the SWAP domain;
- capillary redistribution;
- any other explicitly SWAP-owned process.

A process derivative such as

```
dET/dH_p
```

or

```
dDrain/dH_p
```

is not storage merely because its units resemble storage divided by time.

DSW12 and DSW13 preserve this distinction.

## 6. MODFLOW process ownership

MODFLOW owns groundwater-system contributions outside the SWAP process domain,
for example:

- lateral groundwater flow;
- groundwater boundaries;
- wells and groundwater management terms;
- storage in explicitly disjoint groundwater volume;
- other MODFLOW-owned packages.

A real deployment must state which MODFLOW STO contribution remains after
shared-storage ownership is assigned.

The rule is not “MODFLOW storage is zero” and not “MODFLOW storage is always
retained.” The rule is:

```
each physical storage volume is represented exactly once.
```

## 7. No physical q-link inside the h-link

The h-link itself has one phreatic state. It therefore does not require a
physical conductance between duplicate phreatic heads.

A law such as

```
q_ex = C (H_1-H_2)
```

belongs to a two-state q-link with a physical resistance.

DSW08, DSW18 and DSW24 separate these model families.

A finite-resistance lower-interface model can approach a shared-state h-link
when its two state locations collapse in the zero-resistance limit, but head
collapse alone is insufficient. Storage ownership must also converge to the
one-volume h-link contract.

## 8. Internal SWAP memory remains authoritative

At accepted time `t_n`, the origin for all coupling trials is

```
(H_p,n, xi_swap,n, state_modflow,n).
```

Every corrector trial for the same window must start from the same immutable
accepted SWAP origin `xi_swap,n`.

Changing trial `H_p` must not accumulate rejected SWAP state.

After rejection:

```
xi_swap -> xi_swap,n.
```

After final conjunctive acceptance, exactly one candidate becomes the new
committed SWAP state.

This preserves the transaction semantics already established in the current
F-GC application path even though the physical state coordinate differs.

## 9. Physical response map

For a fixed accepted origin and coupling window, define the physical
head-controlled SWAP map

```
H_p -> {
  Delta V_swap(H_p),
  V_internal_transfer(H_p),
  V_external_swap(H_p),
  xi_swap,end(H_p)
}.
```

The map must expose enough information to reconstruct the complete water
balance independently.

A local derivative such as

```
J_S = d Delta V_swap / dH_p
```

is a finite-window response around that origin.

MAP03 and MAP10 show that such a response may depend strongly on the coupling
window and therefore must not automatically be renamed as a time-independent
specific yield.

## 10. Coupled residual

A scalar conceptual form is

```
F_gw(H_p, q) = 0
q - q_swap(H_p) = 0.
```

The accepted fixed point must satisfy both equations and the complete physical
mass ledger.

If the equations are eliminated to one head equation, the exact local Schur
derivative is determined by the physical residual derivative, not by the name
or units of an individual coefficient.

For

```
F_gw = A(H_p-H_0) - L - q
```

and

```
J_R = dq_swap/dH_p,
```

the head derivative is

```
J_eff = A - J_R.
```

The storage represented in `A` and the storage implicit in `J_R` must follow
the ownership contract above.

## 11. Iteration response is separate from physical ownership

An implementation may solve the coupled residual using an affine approximation

```
q_iter(H)
  = q_swap(H_k) + s_policy (H-H_k).
```

The slope `s_policy` is an iteration policy unless independently established
as the exact derivative of the physical map being linearized.

Changing `s_policy` may change convergence path without changing the accepted
physical fixed point.

DSW21 and MAP04/MAP05/MAP05A establish this distinction.

The production F-GC quantity `+u_A/dt` therefore cannot be imported into a
future h-link merely because it has storage/time dimensions.

## 12. Acceptance gates

A future h-link window is accepted only when all relevant gates pass
independently:

1. MODFLOW numerical convergence;
2. SWAP trial validity from the authoritative origin;
3. shared-state head consistency by construction or exact coupling constraint;
4. coupled residual closure;
5. complete-system mass closure;
6. storage-ownership closure;
7. no overlap or gap in the declared physical storage ledger;
8. correct SWAP candidate provenance;
9. exactly-once publication of accepted external/interface mass;
10. no publication from rejected trials.

DSW19 demonstrates why numerical convergence alone is insufficient.

## 13. Required equivalence tests against lower-interface coupling

A lower-interface-head formulation may only be called equivalent to this h-link
when a prospective test demonstrates all of the following:

```
H_interface -> H_p
```

as the relevant vertical resistance/lag tends to zero,

and simultaneously

```
V_storage,lower-interface model
  -> V_phys,h-link
```

without overlap or missing storage.

The accepted external fluxes and complete water balance must converge to the
same limit as well.

DSW24 is the transparent two-storage oracle for the first two conditions.

A real-SWAP equivalence claim would require a separate physical fixture in
which the interface and phreatic domains are explicitly related.

## 14. Relation to legacy SWBOTB=1

MAP12 identifies legacy SWBOTB=1 as a prescribed groundwater-level /
phreatic-state boundary with state-machine behavior that differs from the
current mode-5 lower-face pressure-head contract.

That lineage is scientifically relevant to a future h-link, but it is not
production-ready authority.

A future implementation must type the desired phreatic-state semantics
explicitly rather than exposing legacy mode 1 wholesale.

## 15. Research admission sequence

No production implementation should start before these research gates close:

1. DSW23 live coextensive storage ownership;
2. DSW24 live lower-interface-to-phreatic equivalence limit;
3. MAP08 raw corrector-domain diagnosis;
4. MAP09 active-drainage corrector feasibility and MAP09A if activated;
5. one real-SWAP fixture with an explicitly declared relation between
   interface head and phreatic state;
6. one real geometric/storage ownership fixture where SWAP and MODFLOW domain
   overlap is known rather than assumed.

Only then should an implementation work unit define APIs or alter MODFLOW STO.

## 16. Non-goals

This research contract does not:

- deprecate the current F-GC mode-5 route;
- assert that current MODFLOW STO is duplicated;
- set MODFLOW Sy or Ss to zero;
- rename `u_A` as static storage;
- choose a production nonlinear solver or slope policy;
- admit legacy SWBOTB=1;
- claim that all groundwater couplings should be h-links.

It defines what must be true if SWAP5 later chooses to implement a genuine
shared-phreatic h-link.
