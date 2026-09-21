# Controlled coupling model: what the dummy experiments establish

## Purpose

The RIBASIM-DUMMY sequence is not intended to mimic Ribasim, MODFLOW or SWAP
in miniature. Its purpose is to make the coupling semantics analytically
visible before real model complexity is introduced.

The core lesson is that five different objects must remain separate:

1. **state**: water stored by each physical subsystem;
2. **physical exchange**: water transferred between subsystems;
3. **managed withdrawal**: water removed because of a management decision;
4. **numerical coupling state**: provisional values used to find a mutually
   consistent solution within one coupling window;
5. **committed state**: the accepted endpoint from which the next window starts.

Many apparent "coupling problems" are created by collapsing two or more of
these objects into one.

## 1. Physical state

### Surface-water state

The minimal Ribasim-like state is a Basin storage or, for a constant-area
oracle,

```text
S_s = A_s h_s.
```

The important property is persistence: `h_s` at the accepted end of one
window is the start state of the next window.

### Groundwater state

Early work units treated groundwater head as externally prescribed. That is
useful for isolating one-sided feedback, but it is not a fully shared state.

DUMMY-09 introduces a second finite storage,

```text
S_g = A_g h_g.
```

Now both heads are dynamic and both carry memory across time.

The equivalent coefficient `A_g` is deliberately abstract. It is not yet a
MODFLOW package mapping.

## 2. Physical exchange

The minimal head-dependent exchange is

```text
q = C(h_s-h_g).
```

Positive exchange is defined from surface water to groundwater.

For a reciprocal coupling, one accepted exchange volume `V` must enter the
two component ledgers with opposite signs:

```text
Delta S_s contains -V
Delta S_g contains +V.
```

Therefore the exchange cancels from the combined ledger:

```text
Delta(S_s+S_g)
```

contains no net `V`.

This is more than bookkeeping. It is a coupling invariant. If the two models
commit different accepted exchange volumes, the coupled system creates or
destroys water even when both individual model balances appear internally
closed.

## 3. Management is not physical exchange

A UserDemand request is a control request, not a physical boundary flux.

Let

```text
R = requested management volume
U = realized management delivery.
```

The dummy contract requires

```text
0 <= U <= R.
```

Physical hydrology is not clipped merely to protect `U`.

This does **not** imply a simplistic sequential algorithm of the form

```text
first compute physical exchange;
then subtract whatever water is left for management.
```

Once physical exchange depends on a shared state, changing `U` changes
surface-water head, which changes exchange, which can change groundwater head,
which changes the same exchange again.

"Hydrology before management" is therefore a priority statement:

> management is the adjustable quantity when the requested withdrawal and the
> physical shared-state solution conflict.

It is not a statement that physical flux is independent of the management
decision.

## 4. A management threshold is not a physical floor

A UserDemand minimum surface-water level `hmin` answers a management question:

> may another managed withdrawal be made?

It does not answer the physical question:

> may infiltration or another uncontrolled hydrological process move the
> surface-water level below this value?

DUMMY-08 demonstrated the distinction explicitly.

A coarse coupling window can solve a curtailed management volume that lands
exactly on `hmin` at the endpoint.

With finer temporal resolution, management can instead run at full rate until
the threshold event, stop, and then physical exchange can continue so that

```text
h_s < hmin
```

at the end of the horizon.

Treating `hmin` as a physical lower boundary would therefore silently change
the hydrology.

## 5. Forecast, realization and commit are different stages

The early DUMMY-02 contract separated:

1. prediction/allocation from committed state;
2. physical realization using the actual exchange information;
3. explicit commit of the accepted endpoint.

That distinction remains useful after the analytical model becomes more
coupled.

A candidate state is not yet authoritative.

Before commit, every participant revision must still match the source revision
from which the candidate was constructed. Otherwise a stale candidate can
partially overwrite newer state.

The research harness therefore treats transaction semantics as a coupling
property, not as incidental software plumbing.

## 6. Correct local rules do not imply coupled convergence

DUMMY-06 constructed a case where every provisional iteration obeyed:

- management bounds;
- the local active-set rule;
- provisional Basin mass balance.

Yet the coupled iteration entered a cycle rather than reaching the exact
solution.

This distinction matters:

```text
local admissibility != coupled fixed-point convergence.
```

A coupling algorithm must therefore be assessed independently of the physical
and management rules it applies.

## 7. Numerical stiffness belongs to the shared-state response

For the one-sided fixed-groundwater trapezoidal surrogate, DUMMY-04 obtained

```text
lambda = C dt/(2A_s)
```

with undamped Picard error

```text
e_(n+1) = -lambda e_n.
```

For the reciprocal two-store mode, DUMMY-09 obtained

```text
mu =
  0.5 C dt (1/A_s + 1/A_g)
```

with trapezoidal head-difference amplification

```text
g = (1-mu)/(1+mu).
```

These are different dimensionless quantities because the underlying state
response is different.

The important general lesson is not either threshold by itself. It is:

> coupling stiffness depends on the response of all states connected by the
> shared flux, not only on the conductance or coupling timestep in isolation.

## 8. Conservation does not guarantee temporal fidelity

Several dummy systems are exactly mass-conservative for every accepted window.

That does not guarantee that a coarse window represents the timing of events
well.

Two examples are now qualified:

1. DUMMY-08: management-event timing changes cumulative management delivery
   even though every partition closes mass;
2. DUMMY-09: a coarse stiff trapezoidal step can reverse the surface and
   groundwater head ordering while conserving combined water exactly.

Hence at least two separate qualification axes are needed:

```text
conservation
temporal/shared-state fidelity.
```

A coupling test that checks only total water balance is insufficient.

## 9. The shared ledger

For the two-store plus management system prepared in DUMMY-10, the component
balances are

```text
Delta S_s = -U - V
Delta S_g = +V.
```

The combined balance is therefore

```text
Delta(S_s+S_g) = -U.
```

If additional external terms are later introduced, they belong explicitly in
the combined ledger.

For example, with external surface inflow `I_s`, groundwater recharge from an
external source `I_g`, and an external groundwater sink `Q_g`:

```text
Delta(S_s+S_g)
  = I_s + I_g - U - Q_g.
```

The internal surface-groundwater exchange should still cancel.

This provides a simple audit rule for later real-model experiments.

## 10. What must eventually be shared between real models

The dummy sequence suggests that a real coupling contract should make at least
the following explicit.

### State authority

Which model owns, proposes and commits:

- surface-water level/storage;
- groundwater head/storage;
- SWAP/root-zone state;
- management-demand state.

### Flux authority

Which model evaluates each physical transfer, and with which source states:

- surface-water to groundwater exchange;
- groundwater to surface-water exchange;
- irrigation withdrawal;
- recharge from unsaturated zone;
- drainage and other external sinks/sources.

A single physical transfer needs one accepted volume in the coupled ledger,
even if both participants calculate diagnostics around it.

### Temporal authority

For every flux and control:

- what time interval does it represent?
- start-state, end-state, average-state or integrated value?
- when can a management decision change within the interval?
- which events require window subdivision?

### Numerical authority

The contract must distinguish:

- the physical equations;
- the management complementarity or allocation rule;
- the iterative method used to solve them;
- the acceptance/convergence criterion.

Changing an iteration method should not silently change the physical or
management contract.

### Commit authority

The coupled transaction must define:

- which candidate states are provisional;
- which revisions they depend on;
- when a candidate is accepted;
- whether all participants can be committed consistently;
- what happens on rejection or retry.

## 11. Current evidence ladder

The research sequence has progressively removed simplifications:

```text
DUMMY-02
  prescribed forecast/actual exchange
  + SWAP-like demand
  + transactional realization

DUMMY-03
  exchange depends on surface level and prescribed groundwater head

DUMMY-04
  frozen temporal closure and exact iteration mechanism

DUMMY-05
  exact management complementarity with state-dependent exchange

DUMMY-06
  nonconvergent active-set Picard counterexample

DUMMY-07
  bounded relaxation and independent direct active-set solve

DUMMY-08
  multi-window surface state and management-event timing

DUMMY-09
  reciprocal finite surface and groundwater storage

DUMMY-10
  prepared: management complementarity with both heads dynamic

DUMMY-11
  preregistered and blocked:
  multi-window memory with both heads dynamic
```

DUMMY-10 and DUMMY-11 must not be described as qualified until their explicit
gates close.

## 12. Boundary of the entire dummy programme

The analytical harness is deliberately smaller than the real coupling.

It does not yet represent:

- Ribasim network routing and allocation optimization;
- nonlinear Basin area-level-storage relations;
- actual MODFLOW package storage or conductance definitions;
- spatial groundwater gradients;
- a Richards unsaturated-zone column;
- SWAP irrigation-demand feedback;
- multiple competing UserDemand nodes;
- delayed or accumulated demand;
- asynchronous internal model timesteps;
- dry/disconnected boundary physics.

Those are later experiments.

The value of the dummy is that each of those complexities can now be added
against a set of already explicit invariants rather than being introduced all
at once.
