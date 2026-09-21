# RIBASIM-DUMMY external authority map

Checked: 2026-09-21

## Purpose

This note binds the analytical dummy vocabulary to current public primary
documentation for Ribasim, MODFLOW 6 and iMOD Coupler.

It is not an equivalence claim.

The dummy deliberately simplifies real-model behavior. This document records
where the simplification is aligned with a real concept, where it is only an
analogy, and where the real coupling behaves differently.

## Primary sources

Ribasim:

- Basin reference:
  https://ribasim.org/reference/node/basin.html
- UserDemand reference:
  https://ribasim.org/reference/node/user-demand.html
- Allocation concept:
  https://ribasim.org/concept/allocation.html
- Model concept:
  https://ribasim.org/concept/concept.html
- Results / usage:
  https://ribasim.org/reference/usage.html
- Coupling-oriented test models:
  https://ribasim.org/reference/test-models.html

iMOD / Ribasim-MODFLOW coupling:

- RibaMod preprocessing:
  https://deltares.github.io/iMOD-Documentation/coupler_ribamod_preprocessing.html
- RibaMetaMod preprocessing:
  https://deltares.github.io/iMOD-Documentation/coupler_ribametamod_preprocessing.html
- RibaMetaMod technical sequence:
  https://deltares.github.io/iMOD-Documentation/coupler_ribametamod_technical.html
- RibaMod configuration:
  https://deltares.github.io/iMOD-Documentation/coupler_ribamod_config.html

MODFLOW 6:

- GWF-STO:
  https://modflow6.readthedocs.io/en/6.6.0/_mf6io/gwf-sto.html
- MODFLOW 6 groundwater-flow technical reference:
  https://pubs.usgs.gov/tm/06/a55/tm6a55.pdf

The external pages can evolve. Claims in this file should be rechecked before
using them as release authority.

## 1. Ribasim Basin state

### Documented behavior

The Ribasim Basin node is a generalized control volume representing water
bodies such as reservoirs, lakes, river reaches or canals.

Its level/profile relation determines storage behavior.

The Basin static/time forcing surface includes, among other terms:

- drainage [m3/s];
- infiltration [m3/s];
- precipitation [m/s];
- potential evaporation [m/s];
- surface runoff [m3/s].

Ribasim result output exposes level, storage, storage rate, infiltration,
drainage and water-balance diagnostics.

### Dummy relationship

The dummy constant-area relation

```text
S_s = A_s h_s
```

is an analytical specialization of a storage-level control volume.

It is **not** a representation of Ribasim's general profile/subgrid relation.

### Consequence

Any result depending on constant `A_s` must be requalified when moving to a
real nonlinear Basin profile.

## 2. Ribasim infiltration and drainage in a MODFLOW-coupled Basin

### Documented behavior

The current Ribasim Basin reference states that, when coupled with MODFLOW 6:

- Basin infiltration is the sum of positive MODFLOW 6 boundary-condition flows
  associated with the Basin;
- Basin drainage is the absolute sum of negative such flows.

The iMOD preprocessing documentation states that coupled Basin infiltration
and drainage input columns are set to nodata so Ribasim does not overwrite the
coupled exchange values.

### Dummy relationship

The dummy sign split

```text
signed V > 0 -> surface to groundwater
signed V < 0 -> groundwater to surface
```

has the same conceptual need to distinguish direction.

The exact sign convention is local to the dummy and must be mapped explicitly
when using real package/API variables.

### Consequence

The shared-ledger requirement survives translation:

one accepted physical transfer must appear with opposite signs in the two
participating model budgets.

## 3. UserDemand request, allocation and supplied abstraction

### Documented behavior

A Ribasim UserDemand takes water from a supplying Basin.

Without allocation, it attempts to extract its demand. With allocation, the
allowed abstraction is determined by the allocation algorithm.

The allocation formulation introduces allocated flow variables bounded by the
corresponding demand.

Ribasim distinguishes demand/allocation from the actual supplied abstraction.

### Dummy relationship

The dummy variables

```text
R = request
allocated
U = realized delivery
shortage = R-U
```

are deliberately separated for the same conceptual reason.

They do **not** reproduce the full Ribasim allocation problem.

## 4. UserDemand min_level is not a hard clipping equation

### Documented behavior

The UserDemand reference states that extraction is smoothly reduced as the
source Basin level approaches the configured `min_level` from above.

The smooth reduction is controlled by a solver threshold
(`level_difference_threshold`), rather than by a discontinuous exact
condition

```text
h >= min_level.
```

A low-storage reduction factor also reduces extraction as the source Basin
becomes nearly empty.

### Dummy relationship

DUMMY-05 and later analytical work use a hard active-set threshold

```text
h_s1 >= hmin
```

for mathematical transparency.

That is an analytical management-complementarity surrogate.

It is **not** the exact current Ribasim UserDemand abstraction equation.

### Consequence

Before moving from dummy to real Ribasim, the hard active-set experiments must
be repeated with the documented smooth reduction behavior or directly against
the Ribasim kernel.

## 5. Allocation priorities are a management layer

### Documented behavior

Ribasim allocation uses ordered demand priorities and a lexicographic
multi-objective / goal-programming formulation.

The model concept describes the allocation layer as reducing lower-priority
abstractions under scarcity so water can remain available for higher-priority
demands.

### Dummy relationship

The current single-demand dummy does not reproduce this optimization.

Its statement

> physical hydrology is not clipped merely to protect one managed withdrawal

is a boundary between physical and management variables, not a replacement
for Ribasim allocation priorities.

### Consequence

Multi-demand priority experiments belong in a later work unit and require
direct binding to the allocation formulation.

## 6. Demand timing

### Documented behavior

For transient UserDemand input, Ribasim uses time-varying demand values. The
UserDemand documentation states that the allocation algorithm evaluates the
interpolated demand at the start of the allocation timestep.

### Dummy relationship

The DUMMY-02/DUMMY-12 rule

```text
request is frozen from committed start state within one decision window
```

is directionally consistent with a start-of-decision evaluation concept.

It is still not an assertion that a dummy coupling window equals a Ribasim
allocation timestep.

### Consequence

Real integration must explicitly map:

- SWAP/root-zone demand update time;
- Ribasim allocation timestep;
- Ribasim solver timestep;
- coupler exchange/commit horizon.

## 7. Current RibaMod package surface

### Documented behavior

Current iMOD coupling documentation describes Ribasim-MODFLOW 6 exchange using
MODFLOW River and Drainage packages.

The RibaMetaMod technical reference explicitly states that, for surface-water
coupling to Ribasim, RIV and DRN are supported; packages such as GHB are not
supported in the coupled domain.

RibaMod distinguishes active and passive coupling:

- active coupling uses Ribasim water level in the exchange relationship;
- passive coupling evaluates MODFLOW-side flux without requiring Ribasim level
  and contributes it as a lateral Basin source.

### Dummy relationship

The dummy linear relation

```text
q = C(h_s-h_g)
```

was called "GHB-like" only because it is analytically linear in a head
difference.

It must **not** be described as the package used by current RibaMod.

### Consequence

The next real-package substitution experiment should use the documented
RIV/DRN coupling surface rather than attempting to validate production
relevance against GHB.

## 8. Why GHB was still a useful analytical analogy

### Documented MODFLOW behavior

The MODFLOW groundwater-flow technical reference gives the General-Head
Boundary relation as a conductance multiplied by the difference between
boundary head and cell head.

The GHB external boundary head is prescribed.

### Dummy relationship

DUMMY-03 used exactly the useful mathematical feature:

- linear conductance;
- head-difference-dependent flux.

But DUMMY-09 later made **both** heads dynamic.

At that point the dummy ceased even to have the one-fixed-head structure of a
GHB boundary.

### Consequence

DUMMY-09/DUMMY-10 are best described as reciprocal linear two-store systems,
not GHB models.

## 9. MODFLOW storage is not the dummy A_g coefficient

### Documented behavior

The MODFLOW 6 STO package distinguishes:

- confined specific storage or storage coefficient;
- specific yield for convertible cells;
- confined versus mixed unconfined/confined storage depending on cell type and
  head position.

### Dummy relationship

The dummy defines

```text
S_g = A_g h_g.
```

Here `A_g` is simply the derivative

```text
dS_g/dh_g
```

of an abstract linear lumped groundwater storage.

It is not, by itself:

- MODFLOW cell area;
- specific yield;
- specific storage;
- storage coefficient;
- a complete aggregation of multiple cells.

### Consequence

Mapping a real MODFLOW domain to an effective dummy `A_g` is a separate
reduction/linearization problem.

No production conclusion may use `A_g` as though that mapping had already
been established.

## 10. Coupling bed consistency is a real physical boundary issue

### Documented behavior

The iMOD RibaMod preprocessing documentation warns that Ribasim subgrid bed
elevation and MODFLOW RIV/DRN bed/elevation must be consistent.

If the MODFLOW bed is lower than the Ribasim subgrid minimum, infiltration can
continue after the Ribasim Basin is empty, producing a water-balance
discrepancy. The preprocessing route detects the problematic configuration and
raises a fatal error.

### Dummy relationship

Several dummy work units intentionally fail closed rather than inventing
dry/disconnected exchange physics when a prescribed exchange would drive the
surface store below its physical datum.

### Consequence

That fail-closed behavior is conceptually justified as a research boundary.

It should not be mistaken for the detailed production dry-bed behavior.

## 11. Existing real three-model coupling sequence

### Documented behavior

The current RibaMetaMod technical documentation already describes a coupled
sequence involving Ribasim, MetaSWAP and MODFLOW 6.

The documented sequence distinguishes, among other exchanges:

- estimated surface-water sprinkling demand;
- realized sprinkling supplied by Ribasim;
- estimated RIV flux;
- realized RIV exchange / correction;
- MODFLOW head;
- MetaSWAP recharge and groundwater sprinkling.

### Dummy relationship

This supports keeping the following concepts separate in the research harness:

```text
requested irrigation
realized irrigation
estimated exchange
realized exchange
persistent model state
```

The dummy sequence was not invented as a claim about the exact current
RibaMetaMod algorithm, but the separation is directly relevant to the real
coupling surface.

### Consequence

When SWAP replaces the analytical root-zone bucket, the first real contract
comparison should be against the documented RibaMetaMod exchange sequence,
while still re-deriving the details needed for SWAP rather than assuming
MetaSWAP equivalence.

## 12. Existing Ribasim coupling test surface

### Documented behavior

The Ribasim test-model reference includes a `two_basin` model specifically
described as being designed for groundwater coupling:

- water enters the left Basin;
- in a coupled run water infiltrates there;
- groundwater exfiltrates into the right Basin;
- the right Basin fills and discharges.

### Research opportunity

This is a promising later bridge case after the one-Basin analytical work:

```text
analytical two-store / two-basin oracle
        ->
Ribasim two_basin coupling test topology
        ->
real MODFLOW exchange
```

It provides a better controlled substitution target than jumping immediately
to a large realistic network.

## 13. Authority table

| Dummy concept | Real documented analogue | Current status |
|---|---|---|
| Basin storage/head | Ribasim Basin level/storage/profile | conceptual match, simplified profile |
| User request | Ribasim UserDemand demand | conceptual match |
| allocated vs supplied | Ribasim allocation and actual abstraction | conceptual match, optimizer omitted |
| hard hmin active set | UserDemand min_level reduction | **not equivalent; real reduction is smooth** |
| signed exchange | Ribasim infiltration/drainage from coupled MF6 flows | directional mapping required |
| q=C(head difference) | generic linear head-dependent boundary math | analytical surrogate only |
| GHB-like label | MODFLOW GHB linear relation | **not current RibaMod package surface** |
| reciprocal dynamic h_s/h_g | coupled surface/GW shared state | research abstraction |
| A_g | MODFLOW transient storage response | **no direct mapping yet** |
| fail closed below datum | coupled bed-consistency concern | boundary principle only |
| request / realization split | RibaMetaMod estimated/realized exchanges | structurally relevant |
| root-zone bucket | SWAP/MetaSWAP persistent unsaturated state | analytical surrogate only |

## 14. Immediate implications for the research plan

The external documentation sharpens the next steps.

### Keep

- separate request, allocation and realization;
- separate physical exchange from management control;
- reciprocal ledger checks;
- explicit timing/commit semantics;
- fail closed where missing dry-boundary physics would otherwise be invented.

### Change before production relevance is claimed

- replace hard UserDemand `hmin` active set with actual smooth Ribasim
  reduction behavior;
- replace GHB-like analytical exchange by documented RIV/DRN coupling
  behavior;
- derive effective MODFLOW storage response rather than equating it to
  `A_g`;
- bind coupling clocks to actual Ribasim allocation/solver and MODFLOW/iMOD
  Coupler sequencing.

### Useful controlled bridge

After the analytical three-store ledger closes, use the Ribasim
`two_basin` groundwater-coupling test topology as an intermediate
substitution target before a realistic network.

## Boundary

This note records public documentation, not repository production authority.

Actual software behavior must still be qualified against pinned versions,
source code and executable evidence before any SWAP5 coupling admission.


## 15. Current SWAP5 repository coupling authority beyond the public product docs

Repository authority was additionally reconciled on 2026-09-21 against the
live `integration/f-ci-canonical` line and the bounded noncanonical
coupling-semantics repair branch.

### F-GC50 product-integration boundary

Current canonical contains F-GC50 authority for iMOD Coupler product
integration.

Its current disposition is not "product integrated".

The admitted internal SWAP5 side is ready for the restricted production
profile, including the PPA-WU01 Fortran/FMR owner and the F-GC49 production
services, but actual registration in the upstream `Deltares/imod_coupler`
product remains externally blocked because the inspected upstream driver
registry has no external/plugin route and the available repository authority
cannot mutate that upstream product.

Therefore the analytical dummy programme must not:

- create a SWAP5-local imitation of the iMOD Coupler product registry;
- duplicate the product-level timestep loop and call that product integration;
- move SWAP/FMR state or mass-ledger ownership to Python;
- describe F-GC50 as already fully product-integrated.

### Live storage-partition and drainage-ownership authority

Project control currently holds the broader F-GC production line on two
shared scientific/architectural authority blockers:

```text
CSR-B1-STORAGE-PARTITION
CSR-B2-DRAINAGE-OWNERSHIP
```

The bounded coupling-semantics reconciliation distinguishes:

- SWAP column storage and finite-window interface response;
- native MODFLOW STO and regional groundwater head memory;
- accepted interface transfer;
- drainage processes owned by one declared component.

The current noncanonical CSR-04 derivation states that SWAP's condensed
finite-window interface Jacobian and native MODFLOW STO are algebraically
distinct response terms.

It also states that this algebra does not by itself prove that the associated
physical storage domains are non-overlapping.

That production/application authority is still unresolved.

### Consequence for DUMMY-09 through DUMMY-13

The dummy coefficient

```text
A_g = dS_g/dh_g
```

is an explicitly independent second store by construction.

This is useful for testing:

- reciprocal exchange;
- groundwater memory;
- conservation under declared non-overlapping control volumes;
- management feedback through both heads.

It is **not** evidence that a real MODFLOW STO term represents a physically
independent storage volume relative to SWAP's column storage.

Likewise, DUMMY-13's proposed root/surface/groundwater stores are disjoint by
definition. A successful three-store ledger can establish the accounting
identity under that declared partition, but cannot close CSR-B1 for the real
production application.

Drainage is deliberately absent from first-stage DUMMY-13. Therefore DUMMY-13
also cannot close CSR-B2.

### Useful research link without authority leakage

The dummy programme can still help the production research indirectly.

It can provide controlled falsification examples for questions such as:

- what combined ledger must hold when storage domains are truly disjoint?
- what observable memory appears when an independent regional storage is
  added?
- how does the zero-regional-storage limit differ from finite independent
  groundwater memory?
- which internal transfers must cancel regardless of numerical coupling
  algorithm?

Those are analytical oracles.

The production F-GC workstream remains responsible for deciding whether real
SWAP and MODFLOW state spaces satisfy the assumptions needed to use those
oracles physically.


## 16. Production SWAP irrigation-demand authority is not yet bound by this research

A focused readback on 2026-09-21 of the current central project-control and
post-Status-A authority documents did not identify an explicit production
contract that says which SWAP5 state variable owns an irrigation request or
how such a request is frozen, revised and committed for Ribasim supply.

This is an absence in the inspected authority surface, not proof that no
irrigation logic exists elsewhere in the repository or legacy model.

Therefore DUMMY-12 must remain an analytical demand-state oracle only.

Before replacing DUMMY-12 with real SWAP5, a dedicated authority-binding step
must identify at least:

- the actual SWAP/legacy state from which irrigation need is derived;
- whether request is calculated from start-of-window committed state or can be
  revised within the same coupling window;
- how realized irrigation is applied back to the SWAP state;
- whether unmet request is represented physically through state deficit,
  diagnostically as shortage, or additionally through an explicit scheduling
  state;
- the units and represented area used to translate SWAP water depth/state into
  Ribasim UserDemand volume/rate;
- the transaction boundary at which the request and realized supply become
  authoritative.

Until that authority is bound, no DUMMY-12 equation may be described as the
production SWAP irrigation algorithm.


## 17. Pinned Ribasim allocation-to-physical source authority

Pinned source inspected:

```text
Deltares/Ribasim@f965a3266a4685bf10f3458aaa1855d09fa45a7a
```

Relevant files:

- `core/src/solve.jl`
- `core/src/allocation_optim.jl`

### UserDemand physical abstraction

The pinned `formulate_flow!` implementation for `UserDemand` first forms an
effective total demand by summing

```text
min(allocated_priority, current_demand_priority)
```

over the active demand priorities.

For each UserDemand inflow link, the physical target is then multiplied by:

- the source Basin low-storage factor;
- the smooth reduction factor associated with source level relative to
  `min_level`.

Thus an allocation does not itself guarantee the corresponding physical
abstraction.

The physical supplied flow can be lower than allocated flow.

### Multiple source links

When allocation is active, the optimized per-inflow-link flow is stored in the
UserDemand's `inflow_link_allocated` state.

The physical layer applies the source-specific reduction factors to each
inflow-link target separately.

This matters for future coupling tests: a single UserDemand with multiple
sources can realize a different total than its allocation when one source
becomes physically constrained.

### Supplied result semantics

In the pinned `parse_allocations!` implementation:

- per-priority allocated values come from the allocation decision variables;
- UserDemand supplied volume is reconstructed from cumulative physical inflow
  over all UserDemand inflow links;
- the supplied value is recorded with a one-allocation-period lag.

The current source path uses that node-level supplied volume while iterating
the demand-priority output records.

Therefore a future SWAP5 research test must not assume, without additional
validation, that one UserDemand's `supplied` result provides a unique physical
split by demand priority.

### Consequence for DUMMY-15B

The planned real-Ribasim bridge should preferably use:

- two distinct UserDemand nodes for the two competing managed claims; or
- direct per-link physical flow diagnostics.

That avoids inferring priority-specific supplied quantities from an output
surface whose current source implementation is node-total based.

### Realization-policy consequence

The pinned source also reinforces an important distinction.

A management allocation can encode lexicographic demand priority, while the
later physical UserDemand abstraction is controlled by smooth physical
reduction factors.

Priority-preserving curtailment after allocation is therefore not something
the analytical dummy may attribute to current Ribasim without executable
evidence.

DUMMY-15B will consequently compare realization-policy oracles rather than
silently choosing one as "the Ribasim rule".
