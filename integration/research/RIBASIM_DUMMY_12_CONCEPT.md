# RIBASIM-DUMMY-12 analytical root-zone demand state

## Purpose

The earlier coupling work treated the SWAP-like irrigation request as an
external input. DUMMY-12 removes that simplification without introducing a
Richards column.

It defines the smallest persistent root-zone water state needed to answer:

> Is the next irrigation request determined by physical root-zone deficit, or
> should previous management shortage be carried as a separate debt?

The DUMMY-12 answer is explicit:

> request is derived from committed root-zone water storage; shortage is a
> diagnostic and is not a persistent state.

This work unit is independent of the pending DUMMY-11 temporal qualification.
It does not consume DUMMY-11 equations. A later three-store experiment must
require both authorities.

## State

Let

```text
W
```

be root-zone water storage [m3], with

```text
0 <= W <= W_capacity.
```

Define an irrigation target

```text
0 <= W_target <= W_capacity.
```

At the start of a coupling window, request is computed from committed state:

```text
R = max(0, W_target - W_start).
```

The request is frozen for that window.

## Supply and shortage

Given externally available irrigation supply `S`,

```text
U = min(R,S)
```

and

```text
shortage = R-U.
```

Shortage is recorded, but it is not part of the root-zone state.

There is no equation such as

```text
backlog_next = backlog + shortage.
```

Any memory of inadequate irrigation must appear physically through the accepted
root-zone storage.

## Window forcing

DUMMY-12 adds two deliberately simple external terms:

```text
P = rainfall volume
E = prescribed root-zone / atmospheric loss
```

with

```text
P >= 0
E >= 0.
```

Before capacity drainage,

```text
W_raw = W_start + U + P - E.
```

If

```text
W_raw < 0,
```

the candidate fails closed.

DUMMY-12 does not invent stress-limited evapotranspiration to repair an
infeasible prescribed loss.

## Capacity drainage

If the raw storage exceeds capacity,

```text
D = max(0, W_raw - W_capacity)
```

and

```text
W_end = W_raw - D.
```

The window ledger is

```text
W_end - W_start = U + P - E - D.
```

The next request is then derived only from the accepted endpoint:

```text
R_next = max(0, W_target - W_end).
```

## Canonical full-fill case

Use

```text
W_start = 60
W_target = 80
W_capacity = 100
S = 20
P = 0
E = 0
```

Then

```text
R = 20
U = 20
shortage = 0
W_end = 80
R_next = 0.
```

## Same-window loss does not create same-window re-request

Use the same start state and supply, but

```text
E = 10.
```

The current request remains

```text
R = 20.
```

After delivery and loss,

```text
W_end = 70
R_next = 10.
```

DUMMY-12 does not issue a second 10 m3 request inside the same window.

This mirrors the transaction principle used earlier in the coupling work:
same-window state response does not silently create an additional decision
iteration unless such an iteration is explicitly part of the contract.

## Shortage is not backlog

Consider

```text
W_start = 60
W_target = 80
S = 5
P = 20
E = 0.
```

The management accounting is

```text
R = 20
U = 5
shortage = 15.
```

But physical root-zone storage becomes

```text
W_end = 60 + 5 + 20 = 85
```

and therefore

```text
R_next = 0.
```

Carrying the 15 m3 shortage forward as a management debt would produce a demand
that is inconsistent with the physical state.

The previous shortage can matter only insofar as it left the root zone drier.

## Same state, same request

Two different histories can end in the same `W`.

One may have experienced a large shortage plus rainfall. Another may have had
no shortage at all.

If both commit

```text
W = 80,
```

then both have

```text
R_next = 0.
```

The demand contract is therefore Markovian in the root-zone state for this
dummy.

Historical shortage is not hidden inside the state.

## Drainage case

For

```text
W_start = 90
W_target = 90
W_capacity = 100
P = 25
E = 5
```

there is no irrigation request.

The raw storage is

```text
110
```

so

```text
D = 10
W_end = 100.
```

The balance closes exactly:

```text
100 - 90 = 0 + 25 - 5 - 10.
```

## Multi-window ledger

Across accepted windows,

```text
W_N - W_0
  = sum(U)
  + sum(P)
  - sum(E)
  - sum(D).
```

Cumulative management shortage does not appear in this conservation equation.

It is an outcome diagnostic, not a flux.

## Relation to real SWAP

DUMMY-12 deliberately does not represent:

- Richards-equation storage profiles;
- pressure-head-dependent uptake;
- crop stress;
- capillary rise;
- groundwater boundary feedback;
- interception;
- preferential flow;
- distributed root uptake;
- real SWAP irrigation scheduling.

Its role is narrower.

It creates an analytically controlled persistent demand state so that a later
work unit can couple:

```text
root-zone storage
surface-water storage
groundwater storage
```

without first having to infer what "irrigation shortage memory" is supposed to
mean.

## Boundary

No DUMMY-12 result may be used to claim SWAP production behavior.

A later three-store experiment must separately bind the qualified DUMMY-11
surface/groundwater temporal authority and the qualified DUMMY-12 root-zone
demand authority.
