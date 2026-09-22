# RIBASIM-DUMMY-20H6: accepted memory versus current forcing at the next boundary

> Status: PREREGISTERED while DUMMY-20H5 is active.

The original DUMMY-20I assumed that active River loss was subtracted directly
from the t=0 management allocation. DUMMY-20H falsified that premise.

DUMMY-20H6 builds the corrected next-boundary oracle from already accepted
evidence.

At t=24 h the active-River DUMMY-20H state is:

```text
Basin level            1.000007990372381 m
excess storage         7.9903723811 m3
```

The priority-1 level target remains 1.0 m. Therefore the next allocation solve
can release that accepted excess storage. With no current River forcing, the
root-first availability is predicted to be:

```text
32 + 7.9903723811 = 39.9903723811 m3/day
```

The active-River law from DUMMY-20G gives approximately
`8.0000425122 m3/day` current forcing at that accepted level.

The H3/H4 mechanism predicts an asymmetric result:

```text
accepted storage memory     admitted
current River forcing       attenuable by LP alpha
```

So with alpha free, the next-boundary allocation remains about
39.9903723811/0 while alpha collapses to zero. If alpha is diagnostically fixed
to one, root allocation falls to about 31.9903298689 m3/day.

A pass establishes the corrected management-memory oracle needed before any new
two-day active-River product trajectory is preregistered.
