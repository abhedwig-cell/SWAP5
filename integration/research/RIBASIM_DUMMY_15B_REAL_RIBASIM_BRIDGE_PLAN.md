# DUMMY-15B real Ribasim bridge plan

Status: planning only. No executable bridge is authorized before the analytical
DUMMY-15 and DUMMY-15B authorities close.

Pinned Ribasim source basis inspected:

```text
Deltares/Ribasim@f965a3266a4685bf10f3458aaa1855d09fa45a7a
```

Relevant source:

- `core/src/solve.jl`
- `core/src/allocation_optim.jl`
- `python/ribasim_testmodels/ribasim_testmodels/allocation.py`
- `core/test/allocation_test.jl`

## Why use a staged bridge

A single transient Ribasim experiment would combine at least four mechanisms:

1. allocation optimization;
2. per-priority allocation output;
3. physical UserDemand reduction from source state;
4. recording of supplied flow, including its one-allocation-period lag.

If such an experiment disagreed with the analytical oracle, the cause would be
ambiguous.

The bridge should therefore substitute real Ribasim behavior in three stages.

## Bridge A: allocation-only priority behavior

### Question

Given a controlled source-water capacity and two managed claims, does the
pinned Ribasim allocation layer distribute water according to the intended
demand-priority ordering?

### Topology

Use one source Basin and two distinct UserDemand nodes:

```text
                 -> UserDemand ROOT_PROXY
source Basin
                 -> UserDemand EXTERNAL
```

Two distinct nodes are preferred over two priority rows on one UserDemand
because later physical supplied flow can then be observed per destination
node/link without assuming a per-priority supplied decomposition.

### Controls

Set both UserDemand nodes to:

- return_factor = 0;
- identical source topology;
- demand values matching analytical DUMMY-15 cases;
- explicit distinct demand priorities.

Keep physical reduction inactive during this stage:

- source level safely above both min_level thresholds;
- sufficient source storage;
- no adverse transient forcing within the allocation interval.

### Preregistered qualitative controls

Test at least:

1. total available allocation below the higher-priority request;
2. total capacity between the higher-priority request and total demand;
3. enough capacity to satisfy both demands;
4. reversed priority labels.

### Evidence

Record:

- demand;
- allocated;
- source Basin state used by the allocation solve;
- allocation timestep;
- per-UserDemand allocation.

This stage does not test physical supplied-flow reduction.

## Bridge B: physical allocation-to-supply handoff

### Question

For known, already allocated UserDemand link targets, how does the pinned
physical layer reduce actual abstraction as source Basin state approaches its
physical reduction regime?

### Why isolate this stage

Pinned `formulate_flow!(UserDemand,...)` computes an effective allocated
demand and then applies source-specific physical reduction factors on each
inflow link.

That behavior can be tested without simultaneously asking the allocation
optimizer to predict the same state transition.

### Controlled cases

Use two distinct UserDemand nodes connected to the same Basin.

Set or obtain fixed allocated link targets and evaluate physical behavior for
source states spanning:

1. level/storage far above reduction thresholds;
2. low-storage reduction only;
3. min-level reduction only;
4. both reductions active.

Where possible, include an exact control in which both UserDemand nodes share
the same source and min_level so they experience the same physical reduction
factor.

### Expected structural invariant

For a common source-state reduction factor and two allocated link targets:

```text
q_supplied,i = rho * q_allocated,i
```

for the instantaneous controlled case.

This is the structural analogue used by the analytical DUMMY-15B proportional
policy.

Do not preregister a numeric rho until the exact Ribasim reduction-function
inputs are pinned.

### Evidence

Prefer:

- direct physical inflow-link flows;
- Basin storage/level;
- exact allocated link targets.

Do not infer the split solely from a single UserDemand per-priority supplied
result.

## Bridge C: full allocation-versus-realization transient

### Question

Can an allocation made from one source state become only partly physically
supplied as the source Basin approaches a reduction threshold during the
following physical interval?

### Design principle

Only begin this stage after Bridge A and Bridge B reproduce their isolated
expected behavior.

Use the same two-UserDemand topology.

Construct a transient in which:

1. the allocation solve sees a state supporting a known allocation;
2. during the subsequent physical interval the source Basin moves toward
   low-storage/min-level reduction;
3. actual UserDemand link flows are integrated;
4. demand, allocated and supplied are compared at correctly aligned allocation
   periods.

### Critical timing requirement

Pinned `parse_allocations!` documents that supplied flow recorded in the
allocation result lags one allocation period.

The bridge must therefore align:

```text
allocation at t_n
physical supply over [t_n,t_{n+1}]
reported supplied value at the next allocation record
```

before comparing allocation and supply.

A same-row comparison without this shift would be invalid.

## Bridge D: couple the analytical root proxy

Only after A-C close should one UserDemand be interpreted as the analytical
root-irrigation recipient.

At that stage compare:

- supplied ROOT_PROXY flow;
- analytical root-state update;
- next analytical irrigation request.

The root recipient is still analytical at this stage. It is not production
SWAP.

## Bridge E: real SWAP substitution

This is a later authority-binding step.

Before replacing ROOT_PROXY with SWAP5, identify:

- actual SWAP irrigation-demand state and timing;
- units and represented area;
- how realized irrigation enters SWAP;
- whether demand can be revised inside a coupling window;
- whether any scheduling/backlog state exists beyond physical column state.

No DUMMY-12 or DUMMY-15 equation should be called the production SWAP demand
law before that authority is established.

## Required observables

For every real Ribasim bridge run retain:

- pinned Ribasim commit/version;
- exact model input;
- allocation timestep and solver timestep;
- Basin level/storage;
- demand for each UserDemand;
- allocated flow for each UserDemand;
- physical inflow-link flow for each UserDemand;
- supplied output with timing alignment;
- source low-storage/min-level reduction factors where inspectable;
- complete source-Basin water balance.

## Failure interpretation

A discrepancy should be classified before any repair:

- **allocation discrepancy**: Bridge A fails;
- **physical reduction discrepancy**: Bridge B fails;
- **timing/output discrepancy**: isolated A/B pass but C appears different;
- **analytical-root mismatch**: A-C pass but D state/request mapping fails;
- **SWAP authority mismatch**: only introduced in E.

Do not tune the analytical oracle after seeing a real-Ribasim result.

The purpose of the bridge is falsification and mapping, not post-hoc agreement.
