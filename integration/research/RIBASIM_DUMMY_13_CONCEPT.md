# RIBASIM-DUMMY-13 blocked concept: three-store internal ledger

> Status: BLOCKED pending formal qualification of both RIBASIM-DUMMY-11 and
> RIBASIM-DUMMY-12.
>
> This note derives the intended first-stage three-store accounting contract.
> No DUMMY-13 implementation or qualification tests are authorized until both
> dependencies close and the implementation baseline is rebound.

## Purpose

DUMMY-10 treats managed irrigation delivery as water leaving the represented
surface-water plus groundwater system.

DUMMY-12 introduces a persistent root-zone storage receiving that irrigation.

Once all three stores are inside the same modeled system boundary, irrigation
delivery is no longer an external loss. It is an **internal transfer** from
surface water to the root zone.

DUMMY-13 is intended to qualify that change of system boundary before adding
rainfall, ET, root drainage, recharge or capillary rise.

## Three explicitly disjoint stores

The first-stage dummy declares three non-overlapping storages by construction:

```text
root:
  W_r

surface:
  S_s = A_s h_s

groundwater:
  S_g = A_g h_g
```

This declaration is part of the dummy physics.

It is not evidence that real SWAP column storage and real MODFLOW STO are
non-overlapping.

That real application question remains owned by the F-GC storage-partition
authority.

## Root request

At the committed start of one window,

```text
R = max(0, W_target - W_r0)
```

as in DUMMY-12.

The request is frozen for that coupling window.

There is no same-window second request after irrigation changes `W_r`.

## Surface / groundwater solve

Use the DUMMY-10 two-store management complementarity with the root request
`R` as the surface-water management request.

That solve determines:

```text
U = realized irrigation delivery
V = surface-to-groundwater exchange
h_s1
h_g1
```

subject to the surface-water management threshold and the reciprocal exchange
equations.

DUMMY-13 does not change those equations.

It changes the accounting boundary by adding the root recipient.

## Root update

With no first-stage external root forcing,

```text
W_r1 = W_r0 + U.
```

The next request is

```text
R_next = max(0, W_target - W_r1).
```

If the request was partially supplied, the remaining physical root deficit is
therefore

```text
R_next = R-U
```

for this no-forcing first-stage problem.

This numerical equality does not turn shortage into a state variable.

It occurs because the only process changing root storage is the irrigation
transfer.

Once rainfall, ET, drainage or capillary terms exist, current shortage and next
physical request need not be equal, as DUMMY-12 already demonstrates.

## Component ledgers

### Root zone

```text
Delta W_r = +U
```

### Surface water

```text
Delta S_s = -U - V
```

### Groundwater

```text
Delta S_g = +V
```

## Combined three-store ledger

Adding all three equations:

```text
Delta(W_r + S_s + S_g)
  = +U - U - V + V
  = 0.
```

Hence, in the first-stage no-external-forcing experiment,

```text
W_r + S_s + S_g = constant.
```

Both internal transfers cancel:

- irrigation `U` cancels between surface and root;
- surface-groundwater exchange `V` cancels between surface and groundwater.

This is a pure system-boundary identity.

## Why DUMMY-10 had a different combined ledger

DUMMY-10's represented system boundary included only:

```text
surface + groundwater.
```

The root-zone recipient was outside that boundary.

Therefore

```text
Delta(S_s + S_g) = -U.
```

DUMMY-13 includes the recipient and gets

```text
Delta(W_r + S_s + S_g) = 0.
```

Neither ledger is more correct in isolation.

They answer different system-boundary questions.

The transfer identity must remain the same:

```text
surface loses U
root gains U.
```

## Canonical case

Use the qualified DUMMY-10 physical system:

```text
A_s = 100
A_g = 100
C   = 50
dt  = 1
h_s0 = 1
h_g0 = 0
hmin = 0.4
```

and root state

```text
W_r0 = 40
W_target = 80
W_capacity = 100.
```

The frozen root request is

```text
R = 40.
```

DUMMY-10 predicts

```text
regime = CURTAILED
U = 32
V = 28
h_s1 = 0.40
h_g1 = 0.28.
```

The root endpoint becomes

```text
W_r1 = 40 + 32 = 72.
```

Therefore

```text
R_next = 80 - 72 = 8.
```

The current shortage is also

```text
40 - 32 = 8,
```

but only because the first-stage root ledger contains no other terms.

### Storage check

Initial:

```text
root         40
surface     100
groundwater   0
total       140
```

Final:

```text
root         72
surface      40
groundwater  28
total       140.
```

Thus

```text
Delta total = 0.
```

## Full-delivery case

If the surface/groundwater system can deliver the full frozen root request,

```text
U = R
```

then

```text
W_r1 = W_target
```

and

```text
R_next = 0.
```

This should be qualified as an independent regime.

## Same committed state, same future problem

Suppose two different histories arrive at exactly the same committed triplet

```text
(W_r, h_s, h_g).
```

Under the first-stage contract they must generate:

- the same root request;
- the same DUMMY-10 surface/groundwater problem;
- the same accepted next state.

Prior shortage diagnostics do not add hidden state.

This will be an important multi-window test after DUMMY-13 single-window
accounting is qualified.

## Relation to current F-GC storage-partition blocker

Current F-GC project control identifies a real production blocker:
CSR-B1-STORAGE-PARTITION.

The production question is whether SWAP-represented storage and MODFLOW STO
represent physically independent state/storage domains, or whether an overlap
correction is required.

DUMMY-13 cannot answer that question because its stores are **defined** to be
disjoint.

A successful DUMMY-13 test proves only:

> if the modeled storage domains are disjoint and transfers are booked once,
> the combined ledger has the stated cancellation structure.

It does not prove the antecedent for real SWAP and MODFLOW.

The live F-GC workstream remains the owner of that application authority.

## Relation to current drainage-ownership blocker

First-stage DUMMY-13 contains no physical drainage path.

Therefore it also cannot answer CSR-B2-DRAINAGE-OWNERSHIP.

When drainage is later introduced, every physical drainage path must have one
explicit owner before it enters the combined ledger.

A later experiment must not add both:

```text
SWAP drainage
```

and

```text
MODFLOW/surface-water representation of the same drain
```

as separate external sinks.

## Why qualify the simple ledger first

Adding ET, rainfall, root drainage and capillary rise immediately would make it
harder to diagnose double booking.

The intended sequence is:

```text
DUMMY-13A:
  U and V only
  -> prove internal-transfer cancellation

later:
  add external root forcing
  -> prove system-boundary source/sink terms

later:
  add root-groundwater physical transfer
  -> prove another internal cancellation pair

later:
  map to real SWAP and MODFLOW state ownership
```

The simplest ledger is therefore not meant as a realistic hydrological model.
It is the conservation oracle for the more realistic compositions.

## Intended qualification after dependencies close

DUMMY-13 may test at least:

1. exact canonical three-store ledger;
2. FULL, CURTAILED and ZERO surface-management regimes;
3. root next-request consistency;
4. no same-window demand regeneration;
5. total-storage invariance under U and V only;
6. component transfer signs;
7. identical future behavior from identical committed state triplets;
8. fail-closed propagation of physical infeasibility from the underlying
   DUMMY-10 solve.

The implementation baseline must be rebound only after both DUMMY-11 and
DUMMY-12 are formally qualified.

## Boundaries

DUMMY-13 first stage will not establish:

- real SWAP/MODFLOW storage non-overlap;
- drainage ownership;
- Richards-equation root-zone behavior;
- capillary rise/recharge exchange;
- Ribasim multi-demand allocation;
- production coupling admission.
