# RIBASIM-DUMMY-19E preregistered concept: priority allocation, then physical shortfall

> Status: PREREGISTERED while DUMMY-19D qualification is active.
>
> This work unit combines two mechanisms that are already independently qualified:
> DUMMY-19B priority allocation under management scarcity and DUMMY-19C
> common-factor physical realization.

## Question

When Ribasim has only 32 m3/day available for 60 m3/day of managed demand, and
the source Basin is simultaneously close enough to UserDemand min_level that
only about half of the allocated transfer can physically occur, what happens
to the water that was allocated but not realized?

The specific hypothesis is that Ribasim does not perform an implicit second
allocation inside the same one-day allocation window. Allocation fixes the
managed target first. Physical source-state constraints then reduce those
targets. The non-realized part stays in the source Basin.

## Controlled model

The model reuses the one-Basin, two-UserDemand topology from DUMMY-19B and
DUMMY-19C.

Fixed supply is 32 m3/day. Demands are 40 m3/day root proxy and 20 m3/day
external demand. A priority-1 LevelDemand prevents the allocation forecast from
drawing on initial Basin storage.

Both UserDemand nodes use min_level = 0.990 m. Initial Basin level is 1.000 m
and the pinned smooth threshold is 0.020 m, so the initial physical reduction
factor is exactly 0.5.

The only priority contrast is:

```text
ROOT_FIRST:
  allocated root     = 32
  allocated external = 0

EXTERNAL_FIRST:
  allocated external = 20
  allocated root     = 12
```

## Independent physical reference

Because both active links use the same source Basin and min_level, total
physical outflow depends only on total allocation, which is 32 m3/day in both
priority cases:

```text
A dh/dtau = 32 * (1 - phi(h - 0.990))
A = 1,000,000 m2
```

Independent integration gives:

```text
final level          = 1.000015980815359 m
final factor         = 0.5011985601316069
total supplied       = 16.019184640970934 m3
Basin storage gain   = 15.980815359029066 m3
```

Recipient realization follows the allocation fractions.

ROOT_FIRST:

```text
root supplied        = 16.019184640970934 m3
external supplied    = 0
```

EXTERNAL_FIRST:

```text
root supplied        = 6.0071942403641 m3
external supplied    = 10.011990400606834 m3
```

The predeclared integrated-volume tolerance is 0.05 m3.

## Scientific meaning

A pass would separate the two decision layers cleanly.

Management priority determines which transfer paths receive allocation.
Physical Basin state determines what fraction of those allocated paths can
actually transfer water. A physical shortfall does not itself imply a new
management decision.

This is directly relevant to the later SWAP-Ribasim-MODFLOW conflict: a
hydrologically impossible or hydrologically forced transfer must not be repaired
by silently rewriting the management allocation ledger.

## Boundary

This experiment uses one allocation window of one day. It does not test whether
a shorter next allocation window reacts to the stored residual water. That is a
separate temporal-feedback experiment.
