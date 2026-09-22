# RIBASIM-DUMMY-20E: passive groundwater transfer with frozen management

> Status: PREREGISTERED behind DUMMY-20D.

This is the first DUMMY-20 work unit in which MODFLOW contributes real water to
the Ribasim Basin.

The groundwater side is deliberately analytically simple:

```text
MF6 head       = 0.5 m fixed
drain elevation = 0.0 m
conductance     = 16 m2/day
drain flux      = -8 m3/day in MF6
Ribasim drainage input = +8 m3/day
```

The Ribasim side retains the root-first scarcity case:

```text
fixed source = 32 m3/day
root demand  = 40 m3/day, priority 2
external     = 20 m3/day, priority 3
allocation.dt = 24 h
```

At t=0 the management allocation therefore assigns the scarce 32 m3/day to the
root recipient. The groundwater transfer is realized physically after that
allocation through the real RibaMod product steps.

The key test is deliberately asymmetric: additional physical water must alter
Basin storage immediately, but it must not be silently converted into a new
lower-priority management allocation during the same 24-hour allocation window.

The frozen one-day reference is:

```text
groundwater transferred       8.000000 m3
root physically supplied     16.028777 m3
external physically supplied  0.000000 m3
Basin storage gain           23.971223 m3
ledger total                 40.000000 m3
```

This is a direct product-level test of the distinction between physical
realization and management allocation.
