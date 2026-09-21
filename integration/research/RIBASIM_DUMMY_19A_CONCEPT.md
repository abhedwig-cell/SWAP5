# RIBASIM-DUMMY-19A: pinned real Ribasim allocation/supply bridge

> Status: implementation authorized by qualified DUMMY-18
> `stage1.real_ribasim_allocation_supply = READY_RESTRICTED`.

## Purpose

DUMMY-19A is the first work unit in this programme that executes a real external
model rather than another analytical surrogate.

The target is pinned:

```text
Deltares/Ribasim@f965a3266a4685bf10f3458aaa1855d09fa45a7a
```

No Ribasim source is modified.

The bridge asks a deliberately narrow question:

> Are the real Ribasim concepts that DUMMY-18 marked BOUND actually observable
> and mutually consistent when the pinned executable model is run?

The first bridge therefore concentrates on:

- demand;
- allocated flow;
- supplied flow;
- physical UserDemand link flow;
- allocation scarcity/fairness;
- multi-source route priority.

It does not yet attempt to reproduce the DUMMY-15 numerical one-Basin oracle.

## Why existing upstream fixtures are reused

The pinned Ribasim repository already contains small fixtures with exact
upstream assertions for the concepts we need.

Reusing them has two advantages:

1. the SWAP5 research programme does not invent a private interpretation of
   Ribasim behavior;
2. our bridge can independently repeat the upstream assertions while retaining
   the exact source pin and outputs as coupling evidence.

## Fixture A: fair_distribution

Pinned constructor:

```text
python/ribasim_testmodels/ribasim_testmodels/allocation.py
  fair_distribution_model()
```

It creates 25 same-priority UserDemand nodes around one Basin.

Their total demand over the one-day horizon is twice the initial available
Basin storage.

Pinned upstream test:

```text
@test all(≈(0.5), user_demand.allocated ./ user_demand.demand)
```

DUMMY-19A repeats this against the executed model.

This establishes a real allocation-under-scarcity observation:

```text
allocated < demand
```

without confusing allocated water with physical supply.

## Fixture B: level_demand

Pinned upstream test `Allocation level control` contains a UserDemand whose
physical inflow is available as link 2.

The upstream test reconstructs interval-average physical supply by integrating
the real link-flow time series and compares it with the allocation-result
`supplied` field.

Critically, the comparison is lagged:

```text
physical supply over allocation interval n
  -> supplied value in the following allocation record
```

The upstream assertion is equivalent to:

```text
supplied_numeric[3:end]
  ~= allocation_table.supplied[4:end]
```

with absolute tolerance `1e-3`.

DUMMY-19A repeats that exact observable relationship.

This is the executable evidence behind the DUMMY-18 warning that `allocated`
and `supplied` are different authorities and that supplied output cannot be
compared same-row without timing alignment.

## Fixture C: two_basin_user_demand

Pinned topology:

```text
FlowBoundary 1 -> Basin 3 (preferred route)
                              \
                               -> UserDemand 5
                              /
FlowBoundary 2 -> Basin 4 (fallback route)
```

The preferred Basin-3 source decays over time.

The allocation layer shifts the resulting deficit onto Basin 4.

The pinned upstream physical-flow assertion for the Basin-4 -> UserDemand-5
link is a linear ramp:

```text
1e-3 -> 2e-3 m3/s
```

within absolute tolerance `5e-6`.

DUMMY-19A repeats this against `Ribasim.flow_data(model)`.

This qualifies a real multi-inflow route-priority observation without yet
introducing SWAP or groundwater coupling.

## What DUMMY-19A does not test

DUMMY-19A deliberately does not yet create a new two-UserDemand scarcity model
with different demand priorities.

DUMMY-18 already binds demand-priority semantics from pinned source and
documentation. DUMMY-19A first closes the more fundamental executable
observability chain:

```text
demand
  -> allocated
  -> physical link flow
  -> lag-aligned supplied output.
```

A subsequent real-Ribasim bridge may then construct the exact competing
recipient case.

## Execution environment

The SWAP5 qualification workflow:

1. checks out the SWAP5 research snapshot;
2. separately checks out the exact Ribasim commit into an untracked workspace
   directory;
3. installs Pixi using the same pinned setup-pixi action revision used by the
   pinned Ribasim CI workflow;
4. uses the Ribasim repository's own Pixi environment;
5. generates only:
   - `level_demand`;
   - `fair_distribution`;
   - `two_basin_user_demand`;
6. instantiates the pinned Julia project;
7. executes a SWAP5-owned read-only Julia bridge script.

The bridge prints the actual Pixi and Julia versions used. The model-source
authority remains the exact Ribasim git commit.

## Admission boundary

A green DUMMY-19A gate means only:

- the pinned real Ribasim executable was run;
- allocation scarcity is observable;
- physical supplied flow is independently reconstructible from link flow with
  the expected lag;
- route-priority redistribution is observable in physical flow.

It does not mean:

- the dummy hard `hmin` equals Ribasim smooth UserDemand reduction;
- DUMMY-15 priority splitting equals the Ribasim network optimizer;
- SWAP irrigation can yet be connected;
- MODFLOW storage is admitted;
- the complete product coupling is admitted.
