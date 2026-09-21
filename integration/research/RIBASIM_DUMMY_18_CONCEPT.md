# RIBASIM-DUMMY-18 blocked concept: real-model authority binding

> Status: IMPLEMENTED after DUMMY-17 qualification and post-DUMMY-15C/D
> irrigation/canopy reconciliation.
>
> This work unit is mapping/governance only. It performs no production-model
> substitution. A green gate validates the authority map; it does not resolve
> rows intentionally marked UNRESOLVED.

## Why a binding stage is necessary

The analytical dummy uses intentionally simple variables such as:

```text
h_s
h_g
W_root
U
V
R
allocated
supplied.
```

Real models expose many quantities that look similar but may differ in:

- ownership;
- units;
- represented area;
- time support;
- integration convention;
- lag;
- diagnostic versus authoritative status;
- transaction state.

A substitution experiment is invalid if it compares quantities merely because
their names appear similar.

DUMMY-18 therefore requires every analytical object to have one of three
statuses before substitution:

```text
EQUIVALENT / BOUND
NON_EQUIVALENT
UNRESOLVED.
```

Only BOUND quantities may enter an executable comparison.

## Binding classes

Every quantity belongs to one class:

1. STATE
2. TRANSFER
3. MANAGEMENT_DECISION
4. CLOCK
5. TRANSACTION
6. DIAGNOSTIC

This classification is important because, for example, a diagnostic budget
term must not silently become a state owner.

## Ribasim

Pinned source already inspected:

```text
Deltares/Ribasim@f965a3266a4685bf10f3458aaa1855d09fa45a7a
```

### Candidate state bindings

```text
dummy S_s
  -> Ribasim Basin storage

dummy h_s
  -> Ribasim Basin level.
```

These remain subject to exact area-level-storage mapping.

### Management bindings

```text
dummy R
  -> UserDemand demand

dummy allocated
  -> allocation result / internal allocated state

dummy supplied
  -> physical UserDemand inflow or time-aligned supplied result.
```

The distinction among these three is mandatory.

Current source review already shows that allocated flow can later be physically
reduced.

### Known non-equivalence

The dummy hard active set at `hmin` is not the same as current Ribasim smooth
physical UserDemand reduction.

Therefore matching a dummy hmin case is not a direct Ribasim-equivalence test.

## MODFLOW

The analytical groundwater state is:

```text
S_g = A_g h_g.
```

This must not be mapped directly onto MODFLOW STO by name.

A real binding needs:

- exact selected/aggregated cell set;
- head observable;
- storage coefficient/storage package definition;
- integrated storage change;
- RIV/DRN budget terms;
- package conductance interpretation;
- timestep/time-integration semantics.

The mapping must explicitly distinguish:

```text
head response
storage response
interface flux.
```

One cannot be inferred from another without the package/state definition.

## SWAP

The analytical root state is a bucket:

```text
W_root.
```

Before real SWAP substitution, authority must identify:

- which accepted SWAP state carries the physical memory relevant to irrigation;
- whether the relevant quantity is total root-zone water, pressure-state
  information, plant-stress state, irrigation scheduling state, or a
  combination;
- how irrigation demand is computed;
- when it is computed;
- how supplied irrigation enters SWAP;
- what quantity is committed;
- whether unmet demand persists anywhere other than physical state.

Until that binding exists:

```text
W_root != production SWAP irrigation state
```

as an authority claim.

## Coupler transaction mapping

The analytical sequence separates:

```text
predict
allocate
realize
candidate
accept
commit.
```

The product mapping must identify exactly where these concepts live in the
actual iMOD Coupler / SWAP5 / MODFLOW lifecycle.

In particular:

- a MODFLOW prepared solve is not automatically a coupled commit;
- a SWAP candidate is not automatically external authority;
- an allocation result is not automatically supplied water;
- a successful local solve is not automatically a globally accepted
  transaction.

## Time support

Every mapped quantity must declare one of:

```text
instantaneous at t_n
instantaneous at t_{n+1}
window average
window integrated
allocation-period integrated
solver-substep quantity
lagged output.
```

Comparisons with mismatched time support are forbidden.

This is especially important for Ribasim supplied output, whose pinned source
semantics include allocation-period lag.

## System-boundary declaration

Before each substitution experiment, declare which stores are inside the
represented ledger.

For example:

```text
Ribasim Basin
MODFLOW groundwater
analytical root proxy
```

means irrigation to the root proxy is internal.

If the root proxy is excluded, the same irrigation becomes an external sink.

The classification must be declared before seeing numerical results.

## Storage partition

DUMMY-18 does not close real storage overlap.

The existing F-GC CSR-B1 authority remains separate.

A real SWAP-MODFLOW experiment cannot claim conservation merely by summing two
storage diagnostics unless it has first established that the represented
storage domains are non-overlapping or has defined the overlap correction.

## Drainage ownership

Likewise, analytical DUMMY-14 capacity drainage has no automatic mapping onto:

- SWAP drainage;
- MODFLOW DRN;
- Ribasim inflow;
- external system loss.

CSR-B2 remains the production authority question.

## Substitution order

The planned sequence is:

### Stage 0

All analytical.

Purpose:
exact control.

### Stage 1

Real Ribasim, analytical groundwater and root.

Purpose:
validate Basin / UserDemand / allocation / supplied / clock semantics.

### Stage 2

Controlled real MODFLOW, analytical root.

Purpose:
validate head, storage and accepted RIV/DRN transfer semantics.

### Stage 3

Real Ribasim + real MODFLOW + analytical root.

Purpose:
qualify the coupled surface-groundwater subsystem before SWAP enters.

### Stage 4

Replace analytical root with production SWAP.

Purpose:
test actual irrigation-demand and root-state authority.

### Stage 5

Full product orchestration.

Purpose:
compare predictor/corrector/commit lifecycle against the analytical transaction
contract.

At every stage only one major authority class should be replaced unless the
preceding stage has already closed.

## Admission principle

Agreement in final total water alone is insufficient.

A substitution stage must compare at least:

- accepted states;
- each owned transfer;
- management decision quantities where relevant;
- timing;
- ledger closure;
- transaction outcome.

If a real component differs from the analytical oracle because its physics is
intentionally different, that difference should be recorded as a mapped
non-equivalence, not calibrated away.

## Boundary

DUMMY-18 is not a production admission work unit.

It is the authority map required to make later production-facing experiments
scientifically interpretable.


## Executable authority-map semantics

The machine-readable map classifies every binding row as exactly one of:

~~~text
BOUND
NON_EQUIVALENT
UNRESOLVED.
~~~

A row marked BOUND may enter a restricted substitution experiment only with its
declared scope, time support and comparison rule.

A row marked NON_EQUIVALENT cannot be compared directly and requires an
explicit adapter or a different experiment.

A row marked UNRESOLVED must remain blocked until its owning production
workstream supplies authority.

The qualification validator deliberately fails if:

- a required UNRESOLVED row is silently promoted;
- a READY stage depends on a non-BOUND row;
- a NON_EQUIVALENT row lacks an adaptation requirement;
- an UNRESOLVED row lacks a concrete blocker;
- a BOUND row lacks pinned authority or time support.

Thus DUMMY-18 qualification is a proof of disciplined uncertainty, not a claim
that the full product coupling is already admitted.
