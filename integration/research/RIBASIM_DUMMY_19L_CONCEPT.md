# RIBASIM-DUMMY-19L: accepted-state trajectory equivalence

> Status: PREREGISTERED while DUMMY-19K is active.

DUMMY-19K asks whether an explicit UserDemand apply seam can recover the native
6-hour physical endpoint while `solver.saveat` remains daily.

DUMMY-19L strengthens that claim. It compares two routes at every accepted
6-hour state boundary:

```text
Route A: native saveat = 6 h
Route B: saveat = 24 h + explicit UserDemand apply at 6 h
```

The comparison is not just final mass. At 6, 12, 18 and 24 hours it checks:

- Basin level and storage gain;
- cumulative root delivery;
- cumulative external-demand delivery;
- cumulative total physical delivery.

The frozen common Basin levels are approximately:

```text
6 h   1.00000399880024 m
12 h  1.00000599490327 m
18 h  1.00000699063662 m
24 h  1.00000748717957 m
```

A pass demonstrates segment-by-segment transactional equivalence. It would mean
the required coupling primitive is not “write allocation output every management
step”, but “solve and explicitly commit the UserDemand allocation at an accepted
management boundary”.
