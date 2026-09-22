# RIBASIM-DUMMY-20E3: realize the groundwater intervention before testing memory

> Status: PREREGISTERED after DUMMY-20E2 was blocked because its one-cell
> CHD+DRN fixture produced zero drainage throughout the day.

DUMMY-20E3 changes the **MF6 representation**, not the coupling hypothesis.

The groundwater fixture becomes:

```text
CHD source cell, h = 0.5 m
        |
        | very high intercell conductance
        v
active groundwater cell, h ≈ 0.5 m
        |
        | DRN cond = 16 m2/day
        v
drain
```

During 0-6 h the drain elevation is 0.5 m, so the transfer is zero. From 6 h
onward the drain elevation is 0 m.

With connection conductance approximately 1e6 m2/day, the independent
steady reference is:

```text
active-cell head ≈ 0.49999200012799794
MF6 DRN flux     ≈ -7.999872002047967 m3/day
Ribasim drainage ≈ +7.999872002047967 m3/day
```

That is effectively the same physical 8 m3/day target used in the original
post-allocation hypothesis, but unlike DUMMY-20E2 the DRN boundary is now on an
active groundwater cell rather than on the CHD cell itself.

The semantic question remains unchanged:

```text
t=0 allocation: root 32, external 0
6-24 h: groundwater arrives physically
no within-day reallocation
```

A pass requires both the intervention and the response. Nonzero MF6 flux is
therefore a prerequisite observable, not something inferred from Basin state.
