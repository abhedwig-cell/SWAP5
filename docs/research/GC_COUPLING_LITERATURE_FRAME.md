# Coupling families in the literature and their relation to the SWAP5-MODFLOW6 research taxonomy

Date: 2026-09-21
Status: RESEARCH LITERATURE FRAME, no production authority

## Purpose

The coupling experiments in GC-DUMMY-SWAP and GC-REAL-SWAP distinguish
physical state, storage, interface exchange and numerical response derivatives.
This note places those distinctions next to established coupling families in
the hydrological and partitioned-model literature.

The comparison is conceptual. A literature method is not production authority
for SWAP5 unless separately admitted in the repository.

## 1. Shared-state coupling

Van Walsum and Veldhuizen (2011) describe SIMGRO coupling around a shared state
variable. Their primary example is phreatic-surface elevation at the connection
between the saturated groundwater system and the unsaturated soil system.

A defining feature of their scheme is that the connecting models use the same
combined storage relationship while alternately updating the shared state.

This is the closest literature family to the physical interpretation explored
by DSW01-DSW18:

- one physical groundwater-head state;
- storage ownership must be combined consistently;
- storage must not be silently counted twice;
- the shared head does not imply that the unsaturated model has no additional
  internal memory.

This family should not be reduced to a generic recharge handoff.

Reference:

P.E.V. van Walsum and A.A. Veldhuizen (2011), "Integration of models using
shared state variables: Implementation in the regional hydrologic modelling
system SIMGRO", Journal of Hydrology 409, 363-370.
DOI: 10.1016/j.jhydrol.2011.08.036.

## 2. Current MetaSWAP-MODFLOW6 implementation documentation

The iMOD Coupler technical reference describes an operational MetaSWAP-MODFLOW6
coupling in which:

- MODFLOW heads are supplied to MetaSWAP;
- MetaSWAP supplies recharge;
- MetaSWAP sets storage in coupled MODFLOW cells;
- groundwater extraction for sprinkling can also be passed to MODFLOW;
- multiple SVAT units may contribute to one MODFLOW cell.

This is important for the storage-ownership question. It provides a concrete
example where the unsaturated-zone model is not merely a recharge calculator:
its storage response is represented in the groundwater solve.

Reference:

Deltares, iMOD Coupler Technical Reference, MetaSWAP-MODFLOW6 coupling,
https://deltares.github.io/imod_coupler/technical.html

## 3. Sequential head/recharge coupling

Twarakavi, Simunek and Seo (2008) describe a HYDRUS-based MODFLOW package with
a different temporal contract:

- HYDRUS computes vadose-zone flow during a MODFLOW time step;
- recharge is passed from HYDRUS to MODFLOW;
- MODFLOW computes a new water-table depth;
- that water-table depth is used as the HYDRUS bottom boundary for the next
  MODFLOW step.

The two models can use different internal time steps, but their principal
information exchange occurs at the MODFLOW step boundary.

This is a useful counterexample to the shared-state family. A head boundary and
a recharge return flux do not automatically imply one jointly solved shared
storage state.

Reference:

N.K.C. Twarakavi, J. Simunek and S. Seo (2008), "Evaluating Interactions
between Groundwater and Vadose Zone Using the HYDRUS-Based Flow Package for
MODFLOW", Vadose Zone Journal 7.
DOI: 10.2136/vzj2007.0082.

## 4. Tight execution coupling is not a physical coupling definition

Hughes et al. (2022) describe the MODFLOW API and its eXtended Model Interface
(XMI). XMI permits coupled software to change MODFLOW variables multiple times
within a time step and therefore enables tight iterative coupling.

That execution capability does not by itself define:

- what the shared physical state is;
- which component owns storage;
- whether an exchange coefficient is physical or numerical;
- which residual the coupled system must close;
- which derivative belongs to which map.

Those remain coupling-contract decisions.

Reference:

J.D. Hughes, M.J. Russcher, C.D. Langevin, E.D. Morway and R.R. McDonald
(2022), "The MODFLOW Application Programming Interface for simulation control
and software interoperability", Environmental Modelling & Software 148,
105257. DOI: 10.1016/j.envsoft.2021.105257.

## 5. Partitioned-iteration literature as a numerical analogy

Partitioned multiphysics literature distinguishes the physical interface
conditions from the numerical response model used to drive coupling
iterations. Quasi-Newton and Broyden-type methods can build or update an
interface Jacobian without claiming that every coefficient in that Jacobian is
a separate physical constitutive parameter.

This is a useful numerical analogy for the SWAP5 finding that an affine
iteration slope may be effective without being identical to the physical
corrector derivative.

The analogy is limited:

- fluid-structure coupling is not hydrological storage physics;
- it does not determine the correct SWAP5 residual or derivative;
- it only supports keeping "physical law" and "iteration response" as separate
  concepts.

Reference:

N. Delaissé et al. (2023), "Quasi-Newton Methods for Partitioned Simulation of
Fluid-Structure Interaction Reviewed in the Generalized Broyden Framework",
Archives of Computational Methods in Engineering 30, 3271-3300.

## 6. Taxonomy used in this research

The literature and repository evidence motivate four distinct coupling
objects.

### A. Shared physical state

Example:

```
H = phreatic / groundwater head
```

One physical value is represented by more than one subsystem.

### B. Physical state response / storage

Example:

```
J_S = d(Delta S)/dH
```

This determines how physical stored water changes with the shared state.

### C. Physical interface exchange

Example:

```
q_swap(H)
J_R = dV_R/dH
```

This is water physically crossing a declared interface, with its accepted
integral entering the interface mass ledger.

### D. Numerical iteration response

Example:

```
q_iter(H) = q_ref + s_policy (H-H_ref)
```

Its slope may be a predictor derivative, a corrector derivative, a
quasi-Newton approximation or another separately qualified response model.

The numerical response is not automatically an extra storage, conductance or
water source.

## 7. Consequences for terminology

Avoid the unqualified terms "exchange coefficient" and "exchange flux" when
they could denote different objects.

Prefer:

- shared head;
- physical storage derivative;
- physical bottom-interface exchange;
- physical q-link conductance;
- predictor response coefficient;
- corrector response derivative;
- iteration-response slope;
- accepted interface-mass integral.

This terminology directly prevents the ambiguity exposed by DSW07, DSW08,
MAP03 and MAP07.

## 8. Working interpretation for SWAP5 research

The current evidence is most consistent with the following bounded
interpretation:

1. groundwater head can be a physically shared state;
2. SWAP retains independent internal unsaturated-zone memory;
3. accepted prescribed-head corrector exchange is physical interface-mass
   authority;
4. production q_u/u is a historical predictor-response construction;
5. +u/dt is a partial affine predictor slope, not the total derivative of q_u
   along neighboring predictor states;
6. the iteration slope may still be useful numerically, but its numerical role
   must be separated from physical storage and physical interface response;
7. corrector admissibility itself can be a numerical constraint, as MAP06
   demonstrates.

The remaining research question is therefore not simply "which sign is
correct?". It is:

> Which coupled residual should be solved for the shared physical state, which
> derivative is authoritative for that residual, and which approximate
> response may safely be used to globalize or accelerate the iteration without
> changing storage ownership or accepted mass?
