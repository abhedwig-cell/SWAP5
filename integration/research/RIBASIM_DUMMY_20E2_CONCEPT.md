# RIBASIM-DUMMY-20E2: post-allocation groundwater transfer

> Status: PREREGISTERED while DUMMY-20D is active.

DUMMY-20E was intentionally not executed. Source reconciliation showed that a
drainage flux already present in the first MF6 step is written into Ribasim
before the t=0 fixed-allocation solve, so the original assumption that it would
arrive after allocation was false.

DUMMY-20E2 creates the intended ordering explicitly:

```text
t = 0
  daily UserDemand allocation sees only 32 m3/day source
  -> root 32, external 0

0-6 h
  MF6 passive drainage = 0

after 6 h accepted boundary
  MF6 passive drainage activates at 8 m3/day
  -> physical groundwater transfer enters Basin
  -> no new allocation until 24 h
```

The frozen endpoint reference is:

```text
time   GW cumulative   root cumulative   external   Basin level
 6 h     0 m3            4.001200 m3       0       1.00000399880024
12 h     2 m3            8.005398 m3       0       1.00000999460204
18 h     4 m3           12.013193 m3       0       1.00001598680744
24 h     6 m3           16.024581 m3       0       1.00002197541861
```

At day end:

```text
32 m3 fixed source
+6 m3 groundwater transfer
=16.024581 m3 root physical supply
+21.975419 m3 Basin storage gain.
```

This is the controlled product-level experiment for the distinction between
physical realization and an already accepted management allocation.
