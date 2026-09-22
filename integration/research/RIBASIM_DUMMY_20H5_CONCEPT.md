# RIBASIM-DUMMY-20H5: zero-storage constraint causality

> Status: PREREGISTERED while DUMMY-20H4 is active.

DUMMY-20H3 showed that injected Basin infiltration reaches the v2026.1.1
allocation LP, yet the LP can choose a low-storage factor of zero and keep the
32/0 UserDemand allocation.

DUMMY-20H5 removes the LevelDemand machinery entirely.

Two LP cases are compared on the same accepted state and forcing:

```text
A. Basin storage change free
B. Basin storage change fixed diagnostically to zero
```

With free storage change, the forecast may draw the large initial Basin store.
The frozen prediction is therefore full 40/20 allocation, alpha=1, and
approximately -35.9999147 m3 storage change.

With storage change fixed to zero, the root-demand objective can keep 32 m3/day
only by setting the infiltration factor to zero. The frozen prediction is
therefore 32/0 allocation and alpha=0.

A pass would isolate the causal mechanism from LevelDemand implementation
details: the decisive ingredients are storage preservation, lexicographic
managed-demand priority, and an optimizable forcing-reduction factor.
