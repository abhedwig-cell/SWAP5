# Controlled coupling model: what the dummy experiments establish

## Purpose

The RIBASIM-DUMMY sequence is not intended to mimic Ribasim, MODFLOW or SWAP
in miniature. Its purpose is to make the coupling semantics analytically
visible before real model complexity is introduced.

The core lesson is now that several different objects and stages must remain
separate:

1. **physical state**: water stored by each physical subsystem;
2. **uncontrolled physical exchange**: water transferred because of hydrology;
3. **management demand**: what a managed recipient requests;
4. **allocation solution**: the optimizer candidate management decision;
5. **applied allocation**: the management target actually published to the
   physical realization layer;
6. **supplied transfer**: the water physically realized for that recipient;
7. **numerical coupling state**: provisional values used to find a mutually
   consistent solution within one coupling window;
8. **accepted/committed state**: the authoritative endpoint from which the next
   window starts;
9. **recorded output**: diagnostics written for observation, which need not be
   the semantic commit mechanism.

Many apparent coupling problems are created by collapsing two or more of these
objects into one. DUMMY-19I through DUMMY-19L show that this is not merely an
analytical distinction: in pinned real Ribasim, allocation solve, UserDemand
application and output recording can be different operations.

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

## 5. Solve, apply, realize, accept and record are different stages

The early DUMMY-02 contract separated prediction/allocation, physical
realization and explicit commit. The real-Ribasim sequence sharpens that into a
five-stage contract:

```text
SOLVE
  compute a candidate allocation from the accepted current state

APPLY / ADMIT
  publish the selected allocation to the physical UserDemand state

REALIZE
  advance physical dynamics using that applied allocation

ACCEPT / COMMIT
  accept the resulting physical state and transfer ledger

RECORD
  emit diagnostics or output independently of semantic commit
```

DUMMY-19I falsified the assumption that an allocation solve is automatically an
applied UserDemand decision. At a sub-`saveat` BMI boundary, pinned Ribasim can
solve the allocation LP with `record=false` while leaving the previously
applied `UserDemand.allocated` and per-link allocation state unchanged.

DUMMY-19I2 observed both states directly:

```text
new LP optimum
!=
currently applied UserDemand allocation
```

DUMMY-19K then applied only the optimized UserDemand and per-link allocation
state, without creating an allocation output record and without resetting
cumulative supplied volume. That was sufficient to recover the native 6-hour
management/physical behavior.

DUMMY-19L strengthened the result from endpoint agreement to transactional
equivalence. Native 6-hour `saveat` application and daily `saveat` plus an
explicit 6-hour UserDemand apply seam produced identical logged Basin state and
cumulative recipient-transfer trajectories at 6, 12, 18 and 24 hours.

Therefore:

```text
record time != allocation solve time != allocation apply time
```

and a candidate management decision is not authoritative until its application
state and the resulting physical interval have been accepted.

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

The ledger depends on the declared system boundary.

### Surface + groundwater only

For DUMMY-10:

```text
Delta S_s = -U - V
Delta S_g = +V
```

so

```text
Delta(S_s+S_g) = -U.
```

Here the irrigation recipient lies outside the represented system.

### Root + surface + groundwater

DUMMY-13 places the root recipient inside the system:

```text
Delta W_r = +U
Delta S_s = -U - V
Delta S_g = +V.
```

Therefore

```text
Delta(W_r+S_s+S_g) = 0
```

when no external forcing is present.

The same physical irrigation transfer changed classification from an external
sink to an internal transfer solely because the represented system boundary
changed.

### External root forcing

DUMMY-14 adds:

```text
P = rainfall/root input
E = prescribed root-zone external loss
D = explicitly owned root capacity drainage.
```

Then

```text
Delta W_r = U + P - E - D
Delta S_s = -U - V
Delta S_g = +V
```

and

```text
Delta(W_r+S_s+S_g) = P-E-D.
```

The internal transfers `U` and `V` still cancel.

### Competing managed recipients

DUMMY-15 adds an external managed recipient:

```text
U_root
U_ext.
```

With no external root forcing:

```text
Delta W_r = +U_root
Delta S_s = -U_root-U_ext-V
Delta S_g = +V
```

hence

```text
Delta(W_r+S_s+S_g) = -U_ext.
```

This gives a general audit rule:

> an accepted transfer appears in the combined ledger only when its other
> endpoint lies outside the declared system boundary.

## 10. Demand, allocation and supply are different objects

The later dummy work makes a second three-level distinction explicit:

```text
demand
allocated
supplied.
```

### Demand

Demand states what management would like to receive.

For the analytical root bucket:

```text
R_root = max(0,W_target-W_root).
```

DUMMY-12 established that historical shortage is not an additional demand
state.

### Allocated

Allocation is a management decision made from the information available at an
allocation time.

It can later turn out to be physically unrealizable.

Allocated water is therefore not yet a physical water transfer.

### Supplied

Supplied water is the realized physical managed transfer.

Only supplied water may:

- enter the component ledgers;
- change root storage;
- leave the represented system through an external demand;
- become part of the accepted endpoint.

This distinction is central to DUMMY-15B.

An allocation-realization difference is a diagnostic management discrepancy,
not a hidden water reservoir.

## 11. Root-zone memory versus shortage memory

DUMMY-12 through DUMMY-14 establish a particularly useful result.

For a simple no-forcing window, current root shortage and next physical root
request can happen to be numerically equal.

That equality disappears as soon as physical forcing acts.

The qualified canonical DUMMY-14 cases have the same current management
shortage:

```text
shortage = 8 m3.
```

Yet:

```text
rainfall +20
  -> next request 0

no external root forcing
  -> next request 8

prescribed root loss 10
  -> next request 18.
```

Therefore:

```text
shortage != physical demand memory.
```

The memory state is accepted root-zone water storage.

## 12. Management priority and physical capacity are separate layers

DUMMY-15 is designed around two managed claims:

- root irrigation;
- an external managed demand.

The exact shared-state physical problem sees their **total** requested surface
withdrawal.

For the one-Basin oracle, after exact total realizable managed withdrawal `M`
has been found, management priority determines the split of `M` among the
claims.

In the canonical case:

```text
R_root = 40
R_ext = 20
R_total = 60

M = 32
V = 28
h_s1 = 0.4
h_g1 = 0.28.
```

With ROOT_FIRST:

```text
U_root = 32
U_ext = 0.
```

With EXTERNAL_FIRST:

```text
U_ext = 20
U_root = 12.
```

The physical surface/groundwater endpoint is unchanged because total managed
withdrawal is unchanged.

The root state and represented-system loss differ because recipient identity
differs.

This is a deliberately small analytical priority oracle, not the full Ribasim
allocation optimizer.

## 13. Allocation-realization policy is itself part of the contract

Current Ribasim source/documentation distinguishes allocated flow from
physically supplied abstraction.

The pinned source study shows that physical UserDemand abstraction can be
reduced by source-state factors after allocation.

Therefore a coupled system must not leave the realization split implicit.

DUMMY-15B preregisters two contrasting analytical policies:

### Priority-preserving curtailment

When physical capacity is below allocated total:

```text
retain the declared management priority while reducing supply.
```

### Proportional aggregate reduction

With

```text
rho = M_actual / M_allocated
```

use

```text
supplied_i = rho * allocated_i.
```

This is a structural reference for aggregate physical reduction, not a claim
that it is the exact current Ribasim implementation for arbitrary networks.

The two policies can have:

- identical total physical withdrawal;
- identical V;
- identical surface and groundwater endpoint;

while producing different:

- recipient supply;
- root memory;
- future root demand;
- external system loss.

Hence realization policy is not bookkeeping trivia. It can change future
hydrology.

## 14. Clock authority is a separate coupling choice

State, physics, management priority and realization policy still do not define
a complete coupling contract.

A real system has several clocks:

- root/SWAP state-update clock;
- management demand-refresh clock;
- Ribasim allocation-solve clock;
- Ribasim allocation-application clock;
- physical Ribasim solver clock;
- output/`saveat` clock;
- MODFLOW timestep;
- outer coupled transaction/commit window.

DUMMY-16 established analytically that physical trajectory authority and
management event-clock authority are distinct. The real-Ribasim DUMMY-19
sequence then exposed how these clocks interact in the pinned implementation.

### Saveat is not observationally neutral when allocation can change

DUMMY-19G held `allocation.dt = 24 h` fixed and varied only `solver.saveat`:

```text
saveat   allocation records   total physical UserDemand supply
24 h     1                    about 16.0192 m3
12 h     2                    about 20.0207 m3
 6 h     4                    about 24.5179 m3
 1 h    24                    about 29.0918 m3
```

The shorter output grid exposed retained Basin water to repeated management
re-optimization within the same nominal 24-hour allocation interval.

DUMMY-19H removed management scarcity. Allocation then stayed demand-capped at
40/20 m3/day for every solve. The cross-`saveat` physical spread collapsed to
about 0.0025 m3 over the day, well inside the frozen 0.05 m3 tolerance. Thus
the dominant DUMMY-19G sensitivity is caused by state-dependent management
re-optimization, not by output sampling alone.

### BMI boundaries can solve without applying UserDemand allocation

DUMMY-19I used daily `saveat` but advanced through 6-hour
`BMI.update_until` boundaries. The preregistered assumption that this would
produce the native 6-hour UserDemand behavior was falsified.

DUMMY-19I2 identified the exact separation:

```text
sub-saveat BMI boundary
  -> allocation LP is solved
  -> shadow optimum changes
  -> UserDemand applied allocation remains unchanged
```

For the root-first case, for example:

```text
represented solve time   shadow LP       applied UserDemand
0 h                      32 / 0          32 / 0
6 h                      40 / 7.995      32 / 0
12 h                     40 / 20         32 / 0
18 h                     40 / 20         32 / 0
```

Pinned source reconciliation explains this: `update_allocation!` invokes
`parse_allocations!` only when `record=true`, and that parse path is where
the optimized UserDemand allocation is written into the state used by physical
realization.

### A finer saveat clock dominates a coarser BMI cadence

DUMMY-19J combined 6-hour BMI calls with 1-hour `saveat`. The result had 24
hourly allocation records and followed the 1-hour DUMMY-19G physical
trajectory. The applied allocation had already reached full 40/20 by the first
observed 6-hour BMI endpoint.

Therefore a coupler cannot claim exclusive ownership of a coarser management
clock while a finer `saveat` grid independently causes allocation
solve-and-apply events.

### Explicit application separates management cadence from output cadence

DUMMY-19K kept daily `saveat`, solved allocation at accepted 6-hour
boundaries with `record=false`, and then explicitly copied only the optimized
UserDemand and per-link allocation values into the applied physical state.

This recovered the native 6-hour physical result without:

- writing an allocation output record;
- resetting cumulative supplied-volume accounting;
- modifying pinned Ribasim source.

DUMMY-19L then demonstrated accepted-state trajectory equivalence at every
6-hour boundary between:

```text
native 6-hour saveat application
and
daily saveat + explicit 6-hour UserDemand apply
```

For the tested topology the routes were identical at logged precision in Basin
level, storage change, cumulative root delivery and cumulative external-demand
delivery.

### Clock mechanics are version-specific

DUMMY-20A and DUMMY-20B add a necessary product-version boundary.

The actual pinned iMOD Coupler RibaMod product driver:

```text
Deltares/imod_coupler@8907fb13f8301ba1e0f32dd90a64ea475d4896d6
```

advances Ribasim to the accepted MODFLOW current time but does not itself
override `allocation.dt` or `solver.saveat`, and does not provide a separate
UserDemand apply seam.

That product pin bundles Ribasim `v2026.1.1` at:

```text
e7fc8ade52a4bedeec10e508d2065577f33eb76a
```

which is 103 commits behind the later DUMMY-19 research pin. Its fixed
`allocation.dt` implementation differs materially from the later saveat/tstop
architecture:

```text
Ribasim v2026.1.1, fixed allocation.dt
  allocation cadence is owned by allocation.dt
  BMI update_until advances the requested physical interval
  solver.saveat does not create extra fixed-dt allocation decisions

Ribasim f965 research pin
  saveat-derived allocation tstops can participate in allocation cadence
  solve/application/record separation must be audited explicitly
```

Therefore clock semantics must always be cited together with the exact Ribasim
authority. DUMMY-19 saveat results are not direct runtime authority for the
older Ribasim release bundled by the pinned RibaMod product.

The qualified research contract is therefore:

```text
SOLVE -> APPLY / ADMIT -> REALIZE -> ACCEPT / COMMIT -> RECORD
```

These stages may share a clock in a particular implementation, but the coupling
architecture must not assume that they are semantically the same operation.

## 15. What must eventually be shared between real models

The real coupling contract should make the following explicit.

### State authority

Which model owns, proposes and commits:

- surface-water level/storage;
- groundwater head/storage;
- SWAP/root-zone state;
- management-demand state.

### Transfer authority

For every physical transfer:

- which component evaluates it?
- which source states are authoritative?
- what is the accepted integrated volume?
- where does the opposite side of the transfer enter the ledger?

A physical transfer needs one accepted coupled volume even when both models
emit diagnostics around it.

### Management authority

For every managed claim:

- how is demand generated?
- which allocation priority applies?
- when is allocation frozen?
- what distinguishes allocated from supplied?
- how is physical curtailment distributed among allocated claims?
- can unmet allocation create future management state, or does only physical
  model state carry memory?

### Temporal authority

For every flux and decision:

- what interval does it represent?
- start-state, end-state, averaged or integrated?
- at which clock can it change?
- which exogenous and threshold events require subdivision?

### Numerical authority

Distinguish:

- physical equations;
- management/allocation equations;
- coupling iteration;
- relaxation/acceleration;
- convergence criteria;
- physical acceptance criteria.

A numerical repair must not silently redefine management or hydrology.

### Commit authority

The coupled transaction must define:

- which states and transfers are provisional;
- which revisions they depend on;
- when all participants become authoritative;
- how partial failure is rejected;
- how retry restores the accepted authority.

## 16. Current evidence ladder

The qualified research sequence now runs through DUMMY-19L.

### Analytical coupling ladder

```text
DUMMY-02  transaction / forecast / realization skeleton
DUMMY-03  head-dependent exchange
DUMMY-04  exact fixed-point mechanism
DUMMY-05  exact management complementarity
DUMMY-06  active-set iteration failure mechanism
DUMMY-07  bounded stabilization
DUMMY-08  temporal partition and management-event timing
DUMMY-09  reciprocal finite surface + groundwater storage
DUMMY-10  management with both heads dynamic
DUMMY-11  multi-window shared-state groundwater memory
DUMMY-12  persistent analytical root demand state
DUMMY-13  root + surface + groundwater internal-transfer ledger
DUMMY-14  external root forcing and physical demand memory
DUMMY-15  competing managed claims and exact priority oracle
DUMMY-15B allocation-versus-realization policy contrast
DUMMY-16  management event-clock semantics
DUMMY-17  two-Basin shared-groundwater interaction
DUMMY-15C irrigation-event realization policies
DUMMY-15D canopy irrigation ledger
DUMMY-18  real-model authority map
```

### Pinned real-Ribasim qualification ladder

```text
DUMMY-19A
  allocation / supplied observability

DUMMY-19B
  real priority conflict under management scarcity

DUMMY-19C
  common-factor allocation-realization conflict

DUMMY-19D
  heterogeneous per-recipient physical realization

DUMMY-19E
  FALSIFIED: hourly saveat caused within-day reallocation
  rather than one frozen daily allocation

DUMMY-19E2
  daily clock-aligned priority then physical realization

DUMMY-19F
  SUPERSEDED UNEXECUTED after 19E falsification

DUMMY-19G
  quantified saveat-driven allocation-clock sensitivity

DUMMY-19H
  no-scarcity negative control isolating management re-optimization

DUMMY-19I
  FALSIFIED: sub-saveat BMI solve did not apply new UserDemand state

DUMMY-19I2
  qualified shadow-LP versus applied-UserDemand separation

DUMMY-19J
  qualified fine-saveat precedence over coarser BMI cadence

DUMMY-19K
  qualified explicit UserDemand solve-to-apply seam

DUMMY-19L
  qualified accepted-state trajectory equivalence:
  native 6-hour saveat == daily saveat + explicit 6-hour apply
```

The falsified and superseded work units remain part of the evidence record. They
must not be silently rewritten into passes because their failures exposed the
clock and application semantics that the later work units then isolated.

### Product-version clock authority

```text
DUMMY-20A
  actual pinned iMOD Coupler RibaMod source contract:
  MF6 leads product time and Ribasim is advanced with update_until(MF6 time);
  no driver-owned UserDemand apply or saveat/allocation override

DUMMY-20B
  exact bundled Ribasim v2026.1.1 source contract:
  fixed allocation.dt owns UserDemand allocation cadence;
  saveat does not schedule fixed-dt allocation decisions;
  later DUMMY-19 allocation-tstop architecture is absent
```

DUMMY-20C is the first dynamic real-product differential: actual RibaMod plus
real MODFLOW/Ribasim kernels versus a fresh direct Ribasim v2026.1.1 route.

## 17. Current real-model authority boundaries

The analytical sequence must remain distinguishable from production-model
authority.

### Ribasim

DUMMY-19A through DUMMY-19L use a pinned real Ribasim authority:

```text
Deltares/Ribasim@f965a3266a4685bf10f3458aaa1855d09fa45a7a
```

Within the tested UserDemand topology they establish real implementation
semantics for:

- Basin storage and level;
- demand priorities and scarce allocation;
- allocated versus physically supplied abstraction;
- per-path `min_level` realization reduction;
- allocation history on `saveat` boundaries;
- sub-`saveat` BMI allocation solves;
- separation between LP shadow allocation and applied UserDemand state;
- the record-gated `parse_allocations!` application seam;
- explicit test-only application of optimized UserDemand/per-link targets;
- segment-by-segment equivalence between native 6-hour application and an
  explicit 6-hour apply seam with daily output.

Source inspection also found the same saveat/allocation-loop structure and the
same record-gated UserDemand application seam on the observed upstream `main`
head during this research block.

These results do **not** establish that the research helper is a supported
production Ribasim API, nor that every Ribasim managed component has identical
application semantics. In particular, Pump/Outlet allocation controls are
applied through different code paths and are outside the DUMMY-19K/19L claim.

The actual pinned iMOD Coupler product currently carries a separate Ribasim
authority:

```text
Ribasim v2026.1.1
commit e7fc8ade52a4bedeec10e508d2065577f33eb76a
```

DUMMY-20B qualifies that release as fixed-`allocation.dt` driven for
UserDemand allocation when `allocation.dt` is configured. It must be treated
as a separate clock authority from `f965...`; cross-version transfer of
saveat/BMI conclusions is forbidden without direct evidence.

### MODFLOW

The abstract groundwater coefficient

```text
A_g = dS_g/dh_g
```

is not yet a MODFLOW STO mapping.

Current RibaMod coupling uses RIV/DRN surfaces rather than the early
GHB-like analytical relation.

### SWAP

The analytical root bucket is not the production SWAP irrigation algorithm.

Before substitution, production authority must identify:

- the actual SWAP state from which irrigation need is derived;
- when that need is evaluated;
- how realized irrigation is applied;
- units and represented area;
- any scheduling state beyond physical soil-water state.

### Storage and drainage ownership

The dummy stores are non-overlapping by construction.

That cannot close the live F-GC storage-partition question for real SWAP and
MODFLOW.

Likewise, analytical capacity drainage does not establish production drainage
ownership.

## 18. Boundary of the dummy programme

The harness intentionally remains smaller than the real coupled system.

It now establishes substantially more than the early analytical programme: a
controlled real-Ribasim UserDemand evidence chain exists through allocation,
physical realization, clock interaction, solve/application separation and
accepted-state trajectory equivalence.

It still does not establish:

- production SWAP irrigation behavior;
- arbitrary/full Ribasim network-allocation equivalence beyond the tested
  UserDemand topology;
- a supported production Ribasim API for explicit UserDemand apply;
- exact RIV/DRN package response;
- actual MODFLOW storage aggregation;
- real SWAP/MODFLOW storage non-overlap;
- production drainage ownership;
- the final product-level asynchronous clock policy;
- product-level iMOD Coupler admission.

The next substitution step should therefore preserve the qualified semantic
contract rather than re-open it implicitly:

```text
accepted physical state
  -> allocation SOLVE
  -> explicit APPLY / ADMIT
  -> physical REALIZE
  -> coupled ACCEPT / COMMIT
  -> independent RECORD
```

A real coupler integration should be judged against that contract with the same
state, transfer, priority, clock and conservation observables. The objective is
not to force production software to copy the research helper, but to require an
equivalent explicit ownership boundary.

## 19. Production irrigation adds management state and canopy state

The current canonical restricted Hupsel irrigation route adds two state classes
that do not exist in the analytical root-bucket dummy.

### Irrigation management state

The qualified TCS1/DCS2 process carries:

~~~text
dayfix
active_event
active_event_start
active_event_end.
~~~

Its event selection depends on hydrologic/crop diagnostics, but the state is not
itself reducible to soil-water storage.

Therefore the earlier DUMMY-12 statement

~~~text
shortage is not persistent physical state
~~~

must not be overgeneralized into

~~~text
production irrigation has no management memory.
~~~

Production irrigation does have explicit management/event memory.

### Canopy interception state

For intercepted sprinkling, gross irrigation first enters the stateful Rutter
canopy reservoir.

The relevant path is:

~~~text
surface-water source withdrawal
  -> gross irrigation
  -> canopy reservoir / interception evaporation
  -> net irrigation
  -> dynamic soil top.
~~~

The Rutter process owns accepted canopy storage and returns an explicit
candidate canopy storage.

Hence:

~~~text
gross source withdrawal != net soil irrigation.
~~~

A complete coupled water ledger must either include canopy storage explicitly
or place canopy storage change and interception evaporation on the declared
system boundary.

### Exact canopy balance identity

Over one interval:

~~~text
gross intercepted input
=
net throughfall / net irrigation
+ canopy storage change
+ interception evaporation.
~~~

For irrigation coupling this means a Ribasim supplied withdrawal should be
compared first with gross irrigation entering the SWAP interception path, not
directly with the net dynamic-top irrigation rate.

### Transaction gap

F-APP05, F-APP07 and F-APP08 qualify process and application composition but
explicitly exclude transaction changes.

Kernel publication separately commits kernel physical state.

The inspected authorities therefore do not yet establish one atomic commit for:

~~~text
irrigation management state
+ canopy candidate state
+ soil-water/kernel candidate state
+ externally supplied irrigation transfer.
~~~

That atomic ownership remains a real coupling authority question.

### Partial supply consequence

A selected fixed-depth/rate irrigation event can be only partly supplied by an
external allocator.

The current restricted irrigation process does not define whether that should:

- reject the event;
- complete the event with reduced water;
- retain an explicit residual event;
- change rate;
- change duration;
- defer the event.

DUMMY-15C isolates those semantics before real-model substitution.
