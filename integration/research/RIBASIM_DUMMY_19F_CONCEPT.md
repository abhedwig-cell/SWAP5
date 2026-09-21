# RIBASIM-DUMMY-19F preregistered concept: hydrology now, management next window

> Status: PREREGISTERED behind DUMMY-19E.
>
> The purpose is to distinguish two statements that must not be conflated:
> no reallocation inside the current physical realization window, and new
> allocation from the accepted physical state at the next management event.

## Question

If day 1 allocates 32 m3 but physical source-state constraints allow only about
16 m3 to leave the Basin, does the retained water become available when Ribasim
allocates again on day 2?

The expected answer is yes, but only at the next allocation event.

## Day 1

Initial Basin level is 1.0 m. Fixed inflow and total allocation are 32 m3/day.
Both UserDemand links have min_level 0.99 m, so the initial physical factor is
0.5.

Independent integration gives:

```text
physical supply day 1 = 16.0191846412 m3
stored residual        = 15.9808153588 m3
final level            = 1.00001598081536 m
```

That residual is physical Basin storage, not an unexecuted transfer.

## Day-2 management event

The LevelDemand target remains 1.0 m. The new allocation forecast starts from
the accepted level above that target.

For the next one-day window the expected available volume is:

```text
32.0000000000 m3 new fixed inflow
+15.9808153588 m3 stored residual
=47.9808153588 m3
```

Priority is applied again to this new amount.

ROOT_FIRST:

```text
root allocated     = 40
external allocated = 7.9808153588
```

EXTERNAL_FIRST:

```text
external allocated = 20
root allocated     = 27.9808153588
```

## Day-2 physical realization

The common min_level factor again reduces the frozen day-2 allocated targets.
The independent hybrid reference gives:

```text
day-2 total physical supply = 24.0622064054 m3
day-2 final Basin level     = 1.00002391860895 m
final Basin excess storage  = 23.9186089535 m3
```

Recipient day-2 physical supplies are expected to follow the day-2 allocation
fractions.

## Coupling interpretation

This experiment makes the intended ordering explicit:

```text
management allocation at t_n
-> physical realization over [t_n, t_{n+1}]
-> accepted physical state at t_{n+1}
-> next management allocation
```

A physically unrealized transfer is not repaired inside the old management
decision. It can influence the next decision because it changed the real stored
state.

That ordering is directly reusable when SWAP and MODFLOW are introduced:
hydrological state evolution is not a management choice, but the next
management action may react to the hydrological state that actually resulted.
