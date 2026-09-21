# RIBASIM-DUMMY experimental roadmap beyond the current authority

## Status

This is a planning document, not scientific authority.

The currently qualified chain ends at DUMMY-09. DUMMY-10 is implemented but
awaiting formal CI qualification. DUMMY-11 is preregistered but blocked on
DUMMY-10.

No future work unit below may consume an unqualified dependency merely because
its equations look plausible.

## Why continue beyond the current two-store dummy

The current sequence has isolated three classes of coupling behavior:

- physical shared-state feedback;
- management complementarity;
- numerical and temporal coupling effects.

The largest remaining simplification is now on the SWAP side.

The "SWAP" participant still supplies an externally frozen management request.
A real unsaturated-zone model contains its own persistent water state and its
irrigation need changes because delivered water, evapotranspiration, drainage,
capillary rise and groundwater conditions change that state.

The next research programme should therefore add complexity in an order that
keeps analytical control.

## Candidate DUMMY-11: shared-state temporal memory

Already preregistered and blocked.

Question:

> How does finite groundwater storage carried from one accepted window to the
> next change management-event timing and cumulative exchange?

New state:

```text
h_s
h_g
```

persist across every accepted window.

Key reference:

- analytical continuous two-store event solution;
- discrete DUMMY-10 window solver after qualification.

No dynamic SWAP/root-zone state yet.

## Candidate DUMMY-12: analytical root-zone demand state

### Goal

Replace the externally specified SWAP request by a deliberately simple,
auditable root-zone storage state.

A possible minimum state is

```text
W_r
```

with bounds

```text
W_wp <= W_r <= W_fc
```

and one management target such as

```text
R =
  max(0, W_target - W_r)
```

converted to a water volume over the represented area.

The exact formulation must be preregistered before implementation.

### Why this is interesting

Delivered irrigation then changes the state that determines the next request:

```text
U_n -> W_r,n+1 -> R_n+1.
```

This creates genuine management memory without inventing a "shortage backlog".

A shortage is not automatically carried as an accounting debt. It matters only
through its effect on the physical root-zone state.

### First controlled experiments

- no ET, no drainage: delivered irrigation should map exactly into root-zone
  storage;
- constant ET: derive exact storage/request recurrence;
- shortage in one window: verify that next demand follows the resulting
  root-zone deficit, not previous shortage as a separate state;
- groundwater-supported root zone: add a prescribed capillary contribution
  only after the storage-only version closes.

### Important distinction

```text
previous shortage
```

and

```text
current physical water deficit
```

are not generally the same variable.

The dummy should make that distinction explicit.

## Candidate DUMMY-13: three dynamic stores

### Goal

Join:

- root-zone storage;
- surface-water storage;
- groundwater storage.

Use the smallest exchange set that can still be solved or tightly checked
analytically.

A possible ledger structure is

```text
root zone:
  Delta S_r = +U + Q_gw_to_r - ET - Q_r_to_gw

surface water:
  Delta S_s = I_ext - U - V_sg

groundwater:
  Delta S_g = +V_sg + Q_r_to_gw - Q_gw_to_r - Q_ext
```

so the combined internal transfers cancel:

```text
U
V_sg
Q_r_to_gw
Q_gw_to_r
```

when the represented system boundary includes all three stores.

This would provide the first analytical analogue of a true
SWAP-Ribasim-MODFLOW water ledger.

### Central experiment

Create a case in which:

1. the root zone asks for irrigation;
2. the surface Basin appears initially able to provide it;
3. groundwater exchange simultaneously removes surface water;
4. groundwater head then changes;
5. delivered irrigation changes the next root-zone request.

The purpose is not complexity for its own sake. It is to test whether the
shared ledger and transaction contract remain unambiguous when all three
states carry memory.

## Candidate DUMMY-14: competing management and physical claims

### Goal

Generalize the original conflict idea beyond one UserDemand.

Possible controlled participants:

- irrigation demand A;
- irrigation demand B;
- mandatory physical infiltration;
- optional managed release.

Questions:

- which quantities are physical constraints?
- which are management allocations?
- which priorities are exogenous policy?
- does allocation order matter?
- can a single coupled complementarity formulation reproduce the intended
  priority without order-dependent bookkeeping?

This work unit should not invent a policy hierarchy. A priority rule must be an
explicit input to the experiment.

## Candidate DUMMY-15: asynchronous clocks

### Goal

Test coupling when internal participant timesteps differ.

Example:

```text
SWAP-like state update: 15 min
surface-water management decision: 1 h
groundwater update: 30 min
coupling commit horizon: 1 h
```

Questions:

- which fluxes are integrated quantities versus instantaneous rates?
- which states may be interpolated?
- what does "same window" mean?
- can a model commit internally before the coupled transaction is accepted?
- which events force synchronization?

The main risk is temporal aliasing rather than mass loss.

A conservative but temporally inconsistent asynchronous scheme can still
produce the wrong management outcome.

## Candidate DUMMY-16: two connected surface-water Basins

### Goal

Introduce the first minimal network element.

Use:

- upstream Basin;
- downstream Basin;
- one routing flux;
- one or two groundwater exchanges;
- one UserDemand.

This tests whether an exchange or management action changes availability
elsewhere through routing within the same decision horizon.

The experiment should remain analytically controlled, for example with linear
reservoir/routing relations.

Only after this closes is it useful to discuss broader Ribasim network
allocation semantics.

## Candidate DUMMY-17: mapping to real model variables

This is not another dummy physics experiment.

It is the authority-binding stage between the analytical research harness and
real packages.

For each dummy concept, identify the actual model surface:

### Ribasim

- Basin storage/level;
- Basin area-level relation;
- infiltration/drainage or exchange representation;
- UserDemand request, allocation and realized demand variables;
- internal allocation timestep versus simulation timestep.

### MODFLOW 6

- groundwater head state;
- relevant storage response;
- exchange package or coupling flux definition;
- stress-period/time-step semantics;
- sign conventions and accepted volume accounting.

### SWAP5

- root-zone/column state used to determine irrigation need;
- irrigation request versus realized irrigation;
- coupling point for surface-water supply;
- recharge/drainage terms shared with groundwater.

The mapping should explicitly identify where the dummy has no real-model
counterpart.

## Candidate DUMMY-18: real-model substitution ladder

Instead of replacing all dummies at once:

1. analytical SWAP + analytical surface + analytical groundwater;
2. real SWAP + analytical surface + analytical groundwater;
3. real SWAP + real Ribasim + analytical groundwater;
4. real SWAP + analytical surface + real MODFLOW;
5. real SWAP + real Ribasim + real MODFLOW.

At every substitution, preserve the same controlled forcing where possible.

This allows a discrepancy to be attributed to the newly introduced model
rather than to the entire coupled system.

## Cross-cutting experiments worth keeping

For every future work unit, consider the following independent axes.

### Conservation

- component balance;
- combined balance;
- internal-transfer cancellation.

### State consistency

- accepted start/end state;
- stale-candidate rejection;
- no tentative state leakage.

### Temporal consistency

- timestep partition;
- event timing;
- asynchronous clocks;
- rate versus volume semantics.

### Numerical consistency

- fixed-point residual;
- active-set regime;
- convergence/cycling;
- timestep or relaxation sensitivity.

### Management semantics

- request;
- allocation;
- realized delivery;
- shortage;
- whether shortage is state or diagnostic;
- policy priority versus physical constraint.

### Physical plausibility

- flux sign;
- state bounds;
- dry/disconnected regimes;
- head-order behavior;
- no management rule masquerading as physical boundary physics.

## Suggested order

Subject to the qualification gates, the current preferred sequence is:

```text
DUMMY-10  dynamic groundwater + management
    |
DUMMY-11  multi-window shared groundwater memory
    |
DUMMY-12  dynamic analytical root-zone demand
    |
DUMMY-13  three dynamic stores and full internal ledger
    |
DUMMY-14  competing managed claims
    |
DUMMY-15  asynchronous clocks
    |
DUMMY-16  minimal routed surface-water network
    |
DUMMY-17  real-model variable/contract mapping
    |
DUMMY-18  controlled substitution ladder
```

This order is intentionally conservative.

It first closes state and conservation questions, then adds management
complexity, then timing/network complexity, and only afterward substitutes real
models.

## Stop conditions

A future work unit should stop rather than silently repair itself when:

- its prerequisite authority is not closed;
- the analytical oracle becomes ambiguous;
- a physical regime requires new physics not already defined;
- an apparent numerical fix changes the physical equations;
- an acceptance tolerance would need to be chosen after seeing the result;
- a real-model behavior cannot be mapped unambiguously to the dummy contract.

Those are new research decisions, not implementation details.


## Roadmap revision 2026-09-21: insert external root forcing before competing claims

The original planning sequence jumped directly from the first three-store
composition to competing management claims.

The qualified DUMMY-12 semantics make an intermediate stage scientifically
useful: once the root store is inside the coupled system, external root forcing
should be added before multiple allocation priorities. Otherwise a later
difference between current shortage and next physical demand could be confused
with multi-demand allocation behavior.

Therefore the forward numbering is revised prospectively, before any of the
affected future work units is implemented:

```text
DUMMY-13
  three disjoint dynamic stores
  U and V internal transfers
  no external root forcing
  [currently in qualification]

DUMMY-14
  external root forcing on three-store system
  rainfall / prescribed root loss / explicitly owned capacity drainage
  demand memory != shortage backlog
  [preregistered, blocked on DUMMY-13]

DUMMY-15
  competing managed claims plus mandatory physical exchange

DUMMY-16
  asynchronous / multirate clocks and event synchronization

DUMMY-17
  minimal two-Basin routed surface-water network

DUMMY-18
  binding analytical variables to real SWAP, Ribasim and MODFLOW surfaces

DUMMY-19
  controlled real-model substitution ladder
```

### DUMMY-15 focus after the revision

The future competing-claims experiment should explicitly separate three types
of scarcity claim:

1. **physical transfer**
   - e.g. surface-groundwater exchange resulting from the accepted shared
     physical state;

2. **managed irrigation demand**
   - generated from the accepted root-zone state;

3. **another managed demand or release**
   - with an explicit Ribasim-style priority supplied as experiment input.

The important question is not merely which request wins.

It is:

> Can an allocation made from predicted availability be reconciled with the
> later physically realized shared state without clipping a mandatory
> hydrological transfer, double-booking water, or implicitly changing the
> declared management priority?

This should be bound directly to documented Ribasim allocation semantics
before implementation.

### DUMMY-16 focus after the revision

Only after demand/state/ledger semantics are closed should the research vary
internal clocks.

Candidate clocks include:

- SWAP/root-zone state update;
- Ribasim allocation timestep;
- Ribasim physical solver timestep;
- MODFLOW timestep;
- outer coupled transaction/commit window.

The main falsification question is whether two schedules can conserve the same
integrated water while producing different management decisions because state
or threshold events are observed at different times.

### DUMMY-17 bridge topology

The current public Ribasim test-model documentation includes a two-Basin model
intended for groundwater-coupling tests.

That makes a two-Basin analytical / real-Ribasim bridge preferable to jumping
directly from one Basin to a large network.

A useful controlled topology is:

```text
upstream Basin
  -> routing
downstream Basin

with:
  one or two groundwater exchange locations
  one root-zone irrigation demand
```

The test can then distinguish routing delay, groundwater redistribution and
management allocation without introducing a realistic network all at once.

### DUMMY-18 and DUMMY-19 remain authority-binding stages

DUMMY-18 must map each analytical state and transfer to pinned real-model
variables and explicitly record missing/non-equivalent concepts.

DUMMY-19 may then replace one analytical component at a time.

Neither stage should be treated as a physics development work unit.


## Roadmap refinement after DUMMY-15B source binding

The downstream sequence is now frozen prospectively as:

```text
DUMMY-15
  exact same-state competing managed claims

DUMMY-15B
  forecast allocation versus physical supply
  realization-policy contrast
  pinned real-Ribasim bridge plan

DUMMY-16
  management-clock synchronization
  same physical trajectory, different priority-event observation

DUMMY-17
  pure physical two-Basin routed system
  + shared groundwater redistribution
  + exact path decomposition

DUMMY-18
  controlled real-model variable/interface binding

DUMMY-19
  one-component-at-a-time real-model substitution
```

The important ordering decision is that DUMMY-17 first remains management-free.
This prevents a future downstream-demand result from conflating:

- routing;
- groundwater redistribution;
- allocation;
- realization policy;
- management clock.

Only after the physical two-path network closes should managed demand be added
to that network.


## DUMMY-18 authority-binding rule

DUMMY-18 is now prospectively preregistered as a mapping stage, not a physics
or production-admission stage.

Before a real component can replace an analytical component, every compared
quantity must be classified as STATE, TRANSFER, MANAGEMENT_DECISION, CLOCK,
TRANSACTION or DIAGNOSTIC and must be marked BOUND, NON_EQUIVALENT or
UNRESOLVED.

No executable real-model substitution is authorized while any quantity that
controls the comparison remains UNRESOLVED.
