# RIBASIM-DUMMY literature positioning notes

Checked: 2026-09-21

## Purpose

These notes position the analytical coupling programme against existing
surface-subsurface coupling and hydrology-management literature.

They are not a novelty claim and are not repository production authority.

The main conclusion is deliberately conservative:

> generic iterative surface-subsurface coupling, relaxation analysis,
> coupling-error analysis, and hydrology-allocation integration already have
> substantial prior art.

The value of the RIBASIM-DUMMY sequence should therefore be framed around a
controlled contract/falsification ladder for the specific
SWAP–Ribasim–MODFLOW problem, especially shared state, transfer ownership,
transaction semantics, management-versus-physics priority, and controlled
substitution of real models.

## 1. Partitioned coupling and relaxation are established topics

### Schüller, Birken and Dedner (2025)

**Convergence properties of iteratively coupled surface-subsurface models**

GEM - International Journal on Geomathematics, 16, article 9.

DOI:
https://doi.org/10.1007/s13137-025-00265-4

The paper studies partitioned surface-subsurface coupling using an idealized
linear 1D-0D problem and derives explicit coupling convergence factors and
optimal relaxation parameters. The analysis is then compared with nonlinear
surface-subsurface experiments.

The coupling pattern is highly relevant conceptually:

- separate subsolvers;
- a surface state supplied to the subsurface problem;
- a subsurface flux supplied back to the surface problem;
- sequential coupling iteration;
- under-relaxation;
- convergence depending on physical/discretization parameters.

### Implication for DUMMY-04 / DUMMY-06 / DUMMY-07

The statements

```text
coupled Picard iteration can oscillate/diverge
```

and

```text
relaxation can stabilize a partitioned coupling
```

are not novelty claims.

DUMMY-04 and DUMMY-07 remain useful because they provide exact oracles for the
specific analytical exchange/control contracts used later in the dummy
programme.

Their role is diagnostic and architectural:

- distinguish physical equations from coupling iteration;
- generate preregistered counterexamples;
- test whether a proposed coupler finds the already-known coupled solution;
- preserve the distinction between a correct local rule and global coupled
  convergence.

## 2. Surface-subsurface coupling errors and mass balance have prior art

### Dagès, Paniconi and Sulis (2012)

**Analysis of coupling errors in a physically-based integrated surface
water–groundwater model**

Advances in Water Resources, 49, 86-96.

DOI:
https://doi.org/10.1016/j.advwatres.2012.07.019

The study explicitly analyzes errors associated with different
surface-subsurface coupling schemes, including conventional sequential
coupling and an iterated boundary-switching formulation.

A central issue is coupling-induced water-balance error.

### Fiorentini et al. (2015)

**Control of coupling mass balance error in a process-based numerical model of
surface-subsurface flow interaction**

Water Resources Research.

DOI:
https://doi.org/10.1002/2014WR016816

The study tracks coupling mass-balance errors caused by interface mapping and
time-lagged exchange information in sequential iterative surface-subsurface
coupling.

### Implication for the dummy programme

The general claim

```text
coupling choices can create mass-balance errors
```

is established.

The RIBASIM-DUMMY programme is more useful if it asks sharper contract
questions:

- is one physical transfer represented by one accepted volume?
- do both participants commit that same transfer with opposite signs?
- is an apparent balance closure only component-local or also system-global?
- can a scheme be exactly conservative but temporally wrong?
- does changing the represented system boundary correctly reclassify a transfer
  from external to internal?

DUMMY-08, DUMMY-09 and DUMMY-13 are deliberately built around these narrower
questions.

## 3. Exact conservation is not enough

The existing coupling-error literature reinforces a distinction that became
central in DUMMY-08 and DUMMY-09.

A coupling can satisfy a water ledger and still be temporally or dynamically
wrong.

Examples from the dummy programme:

### DUMMY-08

Different coupling-window partitions can all close mass exactly while changing

- management shutoff time;
- cumulative delivered irrigation;
- cumulative physical exchange.

### DUMMY-09

A coarse trapezoidal step conserves total two-store water exactly but can
reverse surface and groundwater head ordering in a case where the exact
continuous system never crosses.

### Research framing

This motivates at least two independent qualification axes:

```text
conservation
dynamic / temporal fidelity.
```

A single mass-balance metric is not a sufficient coupling qualification.

## 4. Boundary-condition switching is established physical coupling practice

### Camporese et al. (2010)

**Surface-subsurface flow modeling with path-based runoff routing,
boundary condition-based coupling, and assimilation of multisource observation
data**

Water Resources Research.

DOI:
https://doi.org/10.1029/2008WR007536

This class of integrated model uses switching between flux-controlled and
head-controlled surface/subsurface boundary behavior as surface conditions
change.

### Zerihun et al. (2005)

**Coupled Surface-Subsurface Flow Model for Improved Basin Irrigation
Management**

Journal of Irrigation and Drainage Engineering, 131(2), 111-128.

DOI:
https://doi.org/10.1061/(ASCE)0733-9437(2005)131:2(111)

The model uses an internal iterative driver: surface-flow depth supplies a
boundary condition to the subsurface model, and calculated infiltration feeds
back into the surface-flow mass balance.

### Implication

The dummy programme must not claim novelty merely from:

- exchanging head and flux;
- switching a boundary regime;
- iterating a surface/subsurface pair;
- updating infiltration from a coupled response.

Its controlled contribution is instead the ability to isolate which state,
flux, control and commit assumptions are responsible for a given behavior.

## 5. Hydrology plus water allocation is also established

### Condon and Maxwell (2013)

**Implementation of a linear optimization water allocation algorithm into a
fully integrated physical hydrology model**

Advances in Water Resources, 60, 135-147.

DOI:
https://doi.org/10.1016/j.advwatres.2013.07.012

The work couples a water-allocation module to ParFlow. The management module
allocates water subject to demands, priorities, preferences and constraints
while the integrated hydrological model represents surface-water and
groundwater feedbacks.

The application includes moisture-dependent irrigation.

### Implication

The statement

```text
management allocation should respond to coupled hydrology
```

is not new.

Likewise, multiple demands, priorities and scarcity are established water
allocation concepts.

A future DUMMY-15 competing-demand experiment should therefore be framed as a
controlled test of the specific Ribasim/SWAP/MODFLOW contract:

- which quantities are managed decisions?
- which transfers are physically mandatory?
- when are priorities evaluated?
- when does hydrologic state invalidate an earlier allocation?
- how is realization reconciled with the allocation without double counting?
- what is committed after a conflict?

## 6. Why the current dummy sequence is still scientifically useful

The distinguishing feature is the **evidence ladder**, not any one individual
equation.

The workstream progressively exposes:

1. request, realization and commit;
2. state-dependent physical exchange;
3. coupling-iteration convergence;
4. exact management complementarity;
5. failure of locally admissible active-set iteration;
6. algorithmic stabilization versus physical-rule change;
7. coupling-window event timing;
8. two dynamic storage states;
9. management feedback through both dynamic heads;
10. cross-window groundwater memory;
11. physical root-zone demand memory versus shortage diagnostics;
12. system-boundary reclassification of irrigation as an internal transfer.

Each stage retains an exact or independently derived oracle.

This makes the sequence useful as a controlled substitution framework when the
real SWAP, Ribasim and MODFLOW components are introduced.

## 7. Candidate research questions that remain stronger than generic coupling

The literature scan suggests avoiding broad questions such as:

> Does iterative coupling converge?

or

> Does groundwater feedback affect water allocation?

More useful questions for this programme are:

### Shared-state sufficiency

Which state must be exchanged and committed so that independently integrated
SWAP, Ribasim and MODFLOW components reproduce the same physically admissible
coupled trajectory?

### Transfer ownership

Can every physical water transfer be assigned exactly one owner and one
accepted integrated volume across the three model ledgers?

### Allocation versus realization

Under what conditions does a management allocation made from predicted state
remain realizable after the coupled hydrological response is known?

### Event timing

Which management and physical threshold events require subdivision or
iteration within a coupling window to avoid materially different water
allocation despite exact mass conservation?

### State memory versus bookkeeping memory

Which future demands are determined by physical state, and which quantities
are only diagnostics of earlier unmet allocation?

### Storage partition

When SWAP and MODFLOW are coupled, which observed transient response belongs to
physically distinct storage domains and which response is only an interface
condensation or numerical representation?

The last question is especially important because the current F-GC authority
still holds the real storage-partition issue open.

## 8. Recommended use of the literature in later documentation

The eventual coupling documentation should distinguish three kinds of
reference.

### Established coupling theory

Use the partitioned-coupling and mass-balance literature to motivate:

- iterative coupling;
- relaxation;
- interface exchange consistency;
- coupling error;
- temporal discretization.

### Established integrated management

Use hydrology-allocation literature to motivate:

- hydrologic feedback on availability;
- demand constraints;
- priority/allocation concepts;
- conjunctive surface/groundwater management.

### SWAP5-specific evidence

Reserve repository-qualified dummy and real-model experiments for claims about:

- actual SWAP5 state and transaction semantics;
- Ribasim contract mapping;
- MODFLOW coupling state;
- iMOD Coupler orchestration;
- the exact shared ledger and authority boundaries used by this programme.

That separation avoids claiming general novelty where strong prior art exists
while preserving the value of the controlled SWAP5 coupling evidence.
