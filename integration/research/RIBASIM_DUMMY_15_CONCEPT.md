# RIBASIM-DUMMY-15 blocked concept: competing managed claims

> Status: BLOCKED pending formal qualification of RIBASIM-DUMMY-14.
>
> This note fixes the first-stage priority semantics only. No DUMMY-15 model or
> tests may be created before DUMMY-14 qualifies and the implementation
> baseline is rebound.

## Why this work unit exists

The original coupling question was not merely whether surface water and
groundwater exchange water correctly.

It was:

> What happens when management decisions are made from apparently available
> surface water, while physically mandatory hydrological exchange competes for
> that same water?

The earlier dummy sequence isolated that problem with one managed claim.

DUMMY-15 introduces two different managed claims while keeping the hydrological
exchange non-negotiable.

The first-stage question is intentionally narrower than a full Ribasim
allocation problem:

> Given the exact amount of total managed withdrawal that the coupled physical
> state can realize, how should that amount be split between two claims with an
> explicit priority ordering?

Forecast error is deferred to a later extension so priority semantics can be
qualified independently.

## Public Ribasim context

Current Ribasim documentation distinguishes:

- demand;
- allocated flow;
- supplied flow;
- demand priorities;
- lexicographic/goal-programming allocation;
- later attempted realization by the physical layer.

Relevant public references:

- https://ribasim.org/reference/node/user-demand.html
- https://ribasim.org/concept/allocation.html
- https://ribasim.org/dev/allocation.html

DUMMY-15 does not reproduce the JuMP allocation model.

It uses a one-Basin analytical priority oracle solely to make the intended
priority semantics falsifiable before any network optimizer is introduced.

## Managed claims

### Root irrigation

The first claim is the irrigation request derived from committed root storage:

```text
R_root = max(0, W_target-W_root0).
```

Realized root irrigation is

```text
U_root.
```

Within the represented three-store system it is an internal transfer:

```text
surface -> root.
```

### External managed demand

The second claim is an externally prescribed demand

```text
R_ext >= 0
```

with realized delivery

```text
U_ext.
```

Its recipient is outside the represented root/surface/groundwater system.

Therefore `U_ext` is an external sink from the three-store ledger.

## Physical exchange

Surface-groundwater exchange remains

```text
V.
```

It is not assigned a management priority.

It is determined by the accepted shared physical state and must not be clipped
merely to protect either managed claim.

## Step 1: exact total realizable managed withdrawal

Define

```text
R_total = R_root + R_ext.
```

Use the already-qualified shared-state management oracle with `R_total`.

That exact physical solve returns

```text
M
V
h_s1
h_g1
```

where

```text
M = U_root + U_ext.
```

The physical problem sees only the total managed surface withdrawal.

It does not yet care how that total is split among management recipients.

## Step 2: lexicographic split

Given an explicit ordered list of the two managed claims, allocate the exact
realizable total `M` sequentially by priority.

If root irrigation has higher priority:

```text
U_root = min(R_root, M)
U_ext  = min(R_ext, M-U_root).
```

If external demand has higher priority:

```text
U_ext  = min(R_ext, M)
U_root = min(R_root, M-U_ext).
```

Every realized claim must satisfy

```text
0 <= U_i <= R_i.
```

and

```text
U_root + U_ext = M.
```

This is the entire first-stage priority algorithm.

There is no same-priority fairness optimization and no network routing.

## Component balances

With no DUMMY-14 external root forcing active in the first DUMMY-15 stage:

Root:

```text
Delta W_root = +U_root.
```

Surface:

```text
Delta S_surface = -U_root - U_ext - V.
```

Groundwater:

```text
Delta S_groundwater = +V.
```

Combined represented system:

```text
Delta(W_root+S_surface+S_groundwater)
  = -U_ext.
```

Therefore changing only management priority can change the combined
three-store storage change, even when the surface-water and groundwater
physical endpoint is identical.

That is not a contradiction.

It happens because root irrigation is internal to the represented boundary,
while external demand leaves it.

## Canonical competition case

Use

```text
W_root0 = 40
W_target = 80
W_capacity = 100

h_s0 = 1
h_g0 = 0

A_s = A_g = 100
C = 50
dt = 1
hmin = 0.4

R_root = 40
R_ext = 20
R_total = 60.
```

The exact shared-state physical management solution has

```text
M = 32
V = 28
h_s1 = 0.4
h_g1 = 0.28.
```

Those four values are independent of the priority ordering in this one-Basin
oracle.

### Root irrigation priority

Allocate 32 m3 total:

```text
U_root = 32
U_ext = 0.
```

Shortages:

```text
shortage_root = 8
shortage_ext = 20.
```

Root endpoint:

```text
W_root1 = 72
R_root,next = 8.
```

Combined represented-system change:

```text
Delta total = 0
```

because no external demand is actually delivered.

### External demand priority

Allocate 32 m3 total:

```text
U_ext = 20
U_root = 12.
```

Shortages:

```text
shortage_ext = 0
shortage_root = 28.
```

Root endpoint:

```text
W_root1 = 52
R_root,next = 28.
```

Combined represented-system change:

```text
Delta total = -20.
```

Yet the surface/groundwater endpoint remains

```text
h_s1 = 0.4
h_g1 = 0.28
V = 28.
```

This cleanly separates physical realization from management distribution.

## Interpretation

In this first-stage oracle, priority changes:

- who receives the physically realizable managed water;
- root physical memory;
- future root irrigation demand;
- how much water leaves the represented three-store system.

Priority does not change:

- the exact total managed withdrawal `M`;
- physical exchange `V`;
- surface endpoint;
- groundwater endpoint.

That invariance follows only because both managed withdrawals act on the same
surface store and the physical exchange depends on their total withdrawal, not
recipient identity.

A routed network may break that simplification.

## Why forecast error is deferred

The original real-world concern includes another layer:

1. allocation predicts that enough water exists;
2. physical realization later reveals a larger hydrological exchange;
3. the earlier allocation cannot be fully supplied.

That is important, but adding it now would combine two separate questions:

- how priority splits known realizable capacity;
- how an allocation should be revised when predicted capacity was wrong.

DUMMY-15 first qualifies the former.

A later DUMMY-15B-style extension may then use:

```text
predicted managed capacity
!=
actual shared-state managed capacity.
```

Only then should priority-preserving realization under forecast error be tested.

## Ribasim boundary

The current Ribasim allocation implementation is more sophisticated than this
oracle.

It includes:

- network constraints;
- multiple demand priorities;
- fairness/error objectives;
- route priorities;
- storage and linearized physical constraints;
- primary/secondary allocation networks.

DUMMY-15 does not claim equivalence.

Its role is to provide a transparent one-Basin control case whose expected
priority behavior is known exactly before real Ribasim allocation is
substituted.

## Production-authority boundary

DUMMY-15 still cannot determine:

- actual production SWAP irrigation-demand ownership;
- real SWAP/MODFLOW storage non-overlap;
- production drainage ownership;
- Ribasim supplied-flow behavior after an allocation becomes physically
  unrealizable;
- product-level iMOD Coupler retry/commit policy.

Those remain separate authority questions.

## Implementation gate

No DUMMY-15 implementation may be created until DUMMY-14 qualifies.

After DUMMY-14 closeout, the implementation baseline must be rebound before any
DUMMY-15 code or tests are added.
